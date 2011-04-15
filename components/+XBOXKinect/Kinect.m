classdef Kinect < XBOXKinect.XBOXKinectConfig & tom.Sensor
  
  properties (Constant = true)
    steps = uint32(480);
    strides = uint32(640);
    appName = 'kinectapp';
    fileFormat = '%06d';
    maxDepth = 4.9; % sensitive parameter
    minDepth = 0.8; % sensitive parameter
    maxInt = 2^11;
  end
  
  properties
    imageFocal
    depthFocal
    initialTime
    na
    nb
    ready
  end
  
  methods (Access = public)
    function this = Kinect(initialTime)
      this = this@tom.Sensor(initialTime);
      if(this.verbose)
        fprintf('\nInitializing %s', class(this));
      end
      
      this.initialTime = initialTime;
      this.imageFocal = double(this.strides)*cot(this.imageFieldOfView/2);
      this.depthFocal = double(this.strides)*cot(this.depthFieldOfView/2);      
      
      if(~exist(this.localCache, 'dir'))
        mkdir(this.localCache);
      end
      if(this.overwrite)
        delete(fullfile(this.localCache, 'depth*.dat'));
        delete(fullfile(this.localCache, 'video*.dat'));
        delete(fullfile(this.localCache, 'time*.dat'));
        
        userPath = pwd;
        cd(this.localCache);
        try
          unix(fullfile(this.localCache, 'kinectapp &'));
        catch err
          cd(userPath);
          error(err.message);
        end
        cd(userPath);
      end
      
      this.na = uint32(0);
      this.nb = uint32(0);
  
      this.ready = false;
      refTime = clock;
      while(etime(clock, refTime)<this.timeOut)
        if(this.isValid(0))
          this.ready = true;
          break;
        end
      end
      
      this.refresh(tom.DynamicModelDefault(initialTime, ''));
    end

    function refresh(this, x)
      assert(isa(x, 'tom.Trajectory'));
      while(this.isValid(this.nb+uint32(1)))
        this.nb = this.nb+uint32(1);
        this.ready = true;
      end
    end
    
    function flag = hasData(this)
      flag = this.ready;
    end
    
    function na = first(this)
      assert(this.ready)
      na = this.na;
    end

    function nb = last(this)
      assert(this.ready)      
      nb = this.nb;
    end
    
    function time = getTime(this, n)
      assert(this.ready)
      time = tom.WorldTime(dlmread(fullfile(this.localCache, ['time', num2str(n, this.fileFormat), '.dat'])));
    end
    
    function num = numStrides(this)
      num = uint32(640);
    end
      
    function num = numSteps(this)
      num = uint32(480);
    end
    
    function data = getImage(this, n)
      assert(this.ready)
      fid = fopen(fullfile(this.localCache, ['video', num2str(n, this.fileFormat), '.dat']));
      data = fread(fid, this.steps*this.strides*3, '*uint8');
      fclose(fid);
      data = permute(reshape(data, [3, this.strides, this.steps]), [3, 2, 1]);
    end
    
    function data = getDepth(this, n)
      assert(this.ready)
      fid = fopen(fullfile(this.localCache, ['depth', num2str(n, this.fileFormat), '.dat']));
      data = fread(fid, this.strides*this.steps,'*uint16');
      fclose(fid);
      data = reshape(data, [this.strides, this.steps])';
      data = double(data);
      bad = logical(data(:)>=(this.maxInt-1));
      M = [this.maxDepth, this.maxInt/2*this.maxDepth; this.minDepth, this.maxInt/4*this.minDepth];
      a = M\[1; 1];
      data = 1./(a(1)+a(2)*data);
      % data = 1./(3.3309-0.0030711*data);
      [pix1, pix2] = ndgrid(0:(double(this.steps)-1), 0:(double(this.strides)-1));
      ray = this.depthInverseProjection([pix2(:)'; pix1(:)']);
      data = data./reshape(ray(1, :), [this.steps, this.strides]);
      data(bad) = NaN;
    end
    
    function pix = imageProjection(this, ray, varargin)
      c1 = ray(1, :);
      c2 = ray(2, :);
      c3 = ray(3, :);
      m = double(this.steps);
      n = double(this.strides);
      mc = (m-1)/2;
      nc = (n-1)/2;
      c1((c1<=0)|(c1>1)) = NaN;
      r = this.imageFocal*sqrt(1-c1.*c1)./c1; % r = f*tan(acos(c1))
      theta = atan2(c3, c2);
      pm = r.*sin(theta)+mc;
      pn = r.*cos(theta)+nc;
      outside = ((-0.5>pm)|(-0.5>pn)|(pn>(n-0.5))|(pm>(m-0.5)));
      pm(outside) = NaN;
      pn(outside) = NaN;
      pix = [pn; pm];
    end
    
    function ray = imageInverseProjection(this, pix, varargin)
      m = double(this.steps);
      n = double(this.strides);
      mc = (m-1)/2;
      nc = (n-1)/2;
      pm = pix(2, :);
      pn = pix(1, :);
      outside = ((-0.5>pm)|(-0.5>pn)|(pn>(n-0.5))|(pm>(m-0.5)));
      pm(outside) = NaN;
      pn(outside) = NaN;
      pm = pm-mc;
      pn = pn-nc;
      r = sqrt(pm.*pm+pn.*pn);
      alpha = atan(r/this.imageFocal);
      theta = atan2(pm, pn);
      c1 = cos(alpha);
      c2 = sin(alpha).*cos(theta);
      c3 = sin(alpha).*sin(theta);
      ray = [c1; c2; c3];
    end
    
    function pix = depthProjection(this, ray, varargin)
      c1 = ray(1, :);
      c2 = ray(2, :);
      c3 = ray(3, :);
      m = double(this.steps);
      n = double(this.strides);
      mc = (m-1)/2;
      nc = (n-1)/2;
      c1((c1<=0)|(c1>1)) = NaN;
      r = this.depthFocal*sqrt(1-c1.*c1)./c1; % r = f*tan(acos(c1))
      theta = atan2(c3, c2);
      pm = r.*sin(theta)+mc;
      pn = r.*cos(theta)+nc;
      outside = ((-0.5>pm)|(-0.5>pn)|(pn>(n-0.5))|(pm>(m-0.5)));
      pm(outside) = NaN;
      pn(outside) = NaN;
      pix = [pn; pm];
    end
    
    function ray = depthInverseProjection(this, pix, varargin)
      m = double(this.steps);
      n = double(this.strides);
      mc = (m-1)/2;
      nc = (n-1)/2;
      pm = pix(2, :);
      pn = pix(1, :);
      outside = ((-0.5>pm)|(-0.5>pn)|(pn>(n-0.5))|(pm>(m-0.5)));
      pm(outside) = NaN;
      pn(outside) = NaN;
      pm = pm-mc;
      pn = pn-nc;
      r = sqrt(pm.*pm+pn.*pn);
      alpha = atan(r/this.depthFocal);
      theta = atan2(pm, pn);
      c1 = cos(alpha);
      c2 = sin(alpha).*cos(theta);
      c3 = sin(alpha).*sin(theta);
      ray = [c1; c2; c3];
    end

    % Stops the image capture process
    function delete(this)
      if(this.overwrite)
        unix(['killall -INT ', this.appName]);
      end
    end
  end
  
  methods (Access = private)
    function flag = isValid(this, n)
      flag = exist(fullfile(this.localCache, ['time', num2str(n, this.fileFormat), '.dat']), 'file');
    end
  end
  
end
