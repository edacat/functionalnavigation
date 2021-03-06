classdef BodyReference < tom.Trajectory
  
  properties (SetAccess = private, GetAccess = private)
    T_imu
    x_imu
  end  
  
  methods (Access = public)
    function this = BodyReference(initialTime, localCache, dataSetName)
      if(strcmp(dataSetName(1:6), 'Gantry'))
        S = load(fullfile(localCache, 'workspace.mat'), 'INITIAL_BODY_STATE');
        [this.T_imu, this.x_imu] = ReadGantry(fullfile(localCache, 'gantry_raw.dat'));
        N = size(this.x_imu, 2);
        this.x_imu = [repmat(S.INITIAL_BODY_STATE(1:4), [1, N]); this.x_imu];
      else
        S = load(fullfile(localCache, 'workspace.mat'), 'T_imu', 'x_imu');
        this.x_imu = S.x_imu;
        this.T_imu = S.T_imu;
        N = size(S.x_imu, 2);
      end
      
      % MIT laboratory location
      DTOR = pi/180;
      refLatitude = DTOR*42.3582722;
      refLongitude = DTOR*-71.0927417;
      
      % add initial time to recorded time (same policy for all sensors)
      this.T_imu = this.T_imu+initialTime;
      
      % convert from tangent plane to ECEF
      Raxes = [[0, 0, -1]
               [0, 1,  0]
               [1, 0,  0]];
      refR = tom.Rotation.eulerToMatrix([0; -refLatitude; refLongitude])*Raxes;
      [refTX, refTY, refTZ] = tom.WGS84.llaToECEF(refLongitude, refLatitude, 0);
      refT = [refTX; refTY; refTZ];
      refH = tom.Rotation.quatToHomo(tom.Rotation.eulerToQuat(tom.Rotation.matrixToEuler(refR)));
      this.x_imu(1:4, :) = refH*this.x_imu(1:4, :);
      this.x_imu(5:7, :) = refR*this.x_imu(5:7, :)+repmat(refT, [1, N]);
      
      % swap position and quaternion positions
      this.x_imu = this.x_imu([5, 6, 7, 1, 2, 3, 4], :);
    end

    function interval = domain(this)
      interval.first = this.T_imu(1);
      interval.second = this.T_imu(end);
    end

    function pose = evaluate(this, t)
      N = numel(t);
      if(N==0)
        pose = repmat(tom.Pose, [1, N]);
      else
        pose(1, N) = tom.Pose;
        interval = this.domain();
        lowerBound = t>=interval.first;
        upperBound = t<=interval.second;
        pq = cardinalSpline(this.T_imu, this.x_imu, t(lowerBound&upperBound));
        k = 1;
        for n = find(lowerBound)
          if(upperBound(n))
            pose(n).p = pq(1:3, k);
            pose(n).q = pq(4:7, k);
            k = k+1;
          else
            finalTangentPose = this.tangent(interval.second);
            pose(n) = predictPose(finalTangentPose, t(n)-interval.second);
          end
        end
      end
    end

    function tangentPose = tangent(this, t)
      N = numel(t);
      if(N==0)
        tangentPose = repmat(tom.TangentPose, [1, 0]);
      else
        tangentPose(1, N) = tom.TangentPose;
        interval = this.domain();
        lowerBound = t>=interval.first;
        upperBound = t<=interval.second;
        [pq, pqdot] = cardinalSpline(this.T_imu, this.x_imu, t(lowerBound&upperBound));
        k = 1;
        for n = find(lowerBound)
          if(upperBound(n))
            tangentPose(n).p = pq(1:3, k);
            tangentPose(n).q = pq(4:7, k);
            tangentPose(n).r = pqdot(1:3, k);
            w = tom.Rotation.quatToHomo(tom.Rotation.quatInv(pq(4:7, k)))*(2*pqdot(4:7, k)); % 2*conj(q)*qdot
            tangentPose(n).s = w(2:4);
            k = k+1;
          else
            finalTangentPose = this.tangent(interval.second);
            tangentPose(n) = predictTangentPose(finalTangentPose, t(n)-interval.second);
          end
        end
      end
    end
  end

end

function [t, x] = ReadGantry(filename)
  [tg, xg, yg, zg] = textread(filename, '%f %f %f %f'); %#ok until deprecated by MATLAB
  t = tg'-tg(1);
  s = sin(25*pi/180);
  c = cos(25*pi/180);
  N = yg*c-xg*s;
  E = -yg*s-xg*c;
  D = -zg;
  x = [N'; E'; D'];
end

% Cardinal spline interpolation
%
% INPUT
% @param[in]  tRef reference times, double 1-by-N
% @param[in]  pRef reference values, double D-by-N
% @param[in]  t    interpolation times, double 1-by-K
% @param[in]  c    (default 0) tension parameter, double scalar
% @param[out] p    values at interpolation times, double D-by-K
% @param[out] r    derivatives with respect to time at interpolation times, double D-by-K
%
% NOTES
% Returns initial values if queried before tRef(1)
% Returns final values if queried after tRef(N) 
% The default tension parameter yields a Catman Hull spline
function [p, r] = cardinalSpline(tRef, pRef, t, c)

  [D,N] = size(pRef);
  K = numel(t);
  p = zeros(D, K);
  r = zeros(D, K);
  
  if(K==0)
    return;
  end
   
  if(N<2)
    error('At least two points are required to interpolate');
  end

  % transpose reference points for convienience
  pRef = pRef';
  
  % compute the slopes at each given point
  if(nargin<4)
    c = 0;
  end
  wt = (1-c);
  m = zeros(size(pRef));
  m(1, :) = wt*(pRef(2, :)-pRef(1, :))./(tRef(2)-tRef(1));
  for n = 2:(N-1)
    m(n, :) = wt*(pRef(n+1, :)-pRef(n-1, :))./(tRef(n+1)-tRef(n-1));
  end
  m(end, :) = wt*(pRef(end, :)-pRef(end-1, :))/(tRef(end)-tRef(end-1));
 
  % interpolate
  for k = 1:K
    tIndex = find(t(k)>=tRef,1,'last');

    if(isempty(tIndex))
      tIndex = 1;
    end

    if(tIndex==N)
      tIndex = N-1;
    end
    
    tPlus = tIndex+1;
    tRange = tRef(tPlus)-tRef(tIndex);
    tNorm = (t(k)-tRef(tIndex))./tRange;

    h00 = 2*tNorm.^3-3*tNorm.^2+1;
    h10 = tNorm.^3-2*tNorm.^2+tNorm;
    h01 = -2*tNorm.^3+3*tNorm.^2;
    h11 = tNorm.^3-tNorm.^2;

    h00dot = 6*tNorm.^2-6*tNorm;
    h10dot = 3*tNorm.^2-4*tNorm+1;
    h01dot = -6*tNorm.^2+6*tNorm;
    h11dot = 3*tNorm.^2-2*tNorm;

    p(:, k) = (h00.*pRef(tIndex, :)+h10.*(tRange).*m(tIndex, :)+h01.*pRef(tPlus, :)+h11.*(tRange).*m(tPlus, :))';
    r(:, k) = ((h00dot.*pRef(tIndex, :)+h10dot.*(tRange).*m(tIndex, :)+h01dot.*pRef(tPlus, :)+...
      h11dot.*(tRange).*m(tPlus, :))')/(tRange);
  end
end

function pose = predictPose(tP, dt)
  N = numel(dt);
  if(N==0)
    pose = repmat(tom.Pose, [1, 0]);
    return;
  end

  p = tP.p*ones(1, N)+tP.r*dt;
  dq = tom.Rotation.axisToQuat(tP.s*dt);
  q = tom.Rotation.quatMult(dq, tP.q);
  
  pose(1, N) = tom.Pose;
  for n = 1:N
    pose(n).p = p(:, n);
    pose(n).q = q(:, n);
  end
end

function tangentPose = predictTangentPose(tP, dt)
  N = numel(dt);
  if(N==0)
    tangentPose = repmat(tom.TangentPose, [1, 0]);
    return;
  end

  p = tP.p*ones(1, N)+tP.r*dt;
  dq = tom.Rotation.axisToQuat(tP.s*dt); 
  q = tom.Rotation.quatMult(dq, tP.q);

  tangentPose(1, N) = tP;
  for n = 1:N
    tangentPose(n).p = p(:, n);
    tangentPose(n).q = q(:, n);
    tangentPose(n).r = tP.r;
    tangentPose(n).s = tP.s;
  end
end
