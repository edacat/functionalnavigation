% Evaluate cost associated with trajectory and sensor noise sets
%
% INPUTS
% g = sensor data object
% x = trajectory objects, 1-by-K
% w = sensor noise objects, 1-by-K
%
% OUTPUT
% s = cost, 1-by-K


function s=eval(g,x,w)

% process each trajectory independently
K=numel(x);
s=zeros(1,K);
for k=1:K
  s(k)=sensor_eval_individual(g,x(k),w(:,k));
end

return;


function s=sensor_eval_individual(g,x,w)

% default cost
s=0;

% get sensor event indices
[ka,kb]=domain(g);
k=ka:kb;

% identify sensor events within trajectory domain
[tmin,tmax]=domain(x);
t=gettime(g,k);
inside=find((t>=tmin)&(t<=tmax));
k=k(inside);
t=t(inside);

% check whether at least two events occurred
if( numel(inside)<2 )
  return;
end

% arbitrarily select the first and last events
ka=k(1);
kb=k(end);
ta=t(1);
tb=t(end);

% evaluate position of sensor (forward-right-down relative to camera's initial frame)
pa=evalPosition(x,ta); 
pb=evalPosition(x,tb);

% evaluate orientation of sensor
qa=evalQuaternion(x,ta);
qb=evalQuaternion(x,tb);
  
% convert quaternions to rotation matrices
Ra=Quat2Matrix(qa);
Rb=Quat2Matrix(qb);

% get data from sensor
ia=getdata(g,ka);
ib=getdata(g,kb);

%%% INSERT OPTICAL FLOW ALGORITHM HERE %%%
% NOTE: disregard w and focal length for now

return;
