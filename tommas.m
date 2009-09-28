classdef tommas
  
  properties
    optimizer
    trajectory
    measure
    cpuDelta
    popsize
    tmin
  end
  
  methods
    % Construct a Trajectory Optimization Manager for Multiple Algorithms and Sensors
    function this=tommas(config)
      fprintf('\n');
      fprintf('\ntommas::tommas');

      if(nargin~=1)
        error('requires configuration argument');
      end
      
      warning('on','all');
      intwarning('off');
      reset(RandStream.getDefaultStream);

      addpath(config.componentPath);
      fprintf('\npath added: %s',config.componentPath);

      % TODO: set adaptively to manage computation
      this.cpuDelta=0.0;
      this.popsize=10;
      this.tmin=1.3;

      % initialize optimizer
      this.optimizer=feval(config.optimizer);

      % initialize trajectories and measures
      thisSensor=feval(config.sensor);
      this.trajectory=feval(config.trajectory);
      this.measure{1}=feval(config.measure,thisSensor);
      for k=2:this.popsize
        this.trajectory(k,1)=feval(config.trajectory);
        this.measure{1}(k,1)=feval(config.measure,thisSensor);
      end
      % TODO: enable multiple measures
    end
    
    % Execute one step to improve the tail portion of a set of trajectories
    %
    % OUTPUT
    % xEstimate = trajectory objects, popsize-by-1
    % cost = non-negative cost associated with each trajectory object, double popsize-by-1
    % costPotential = uppper bound cost that could have accrued, double scalar
    function [this,xEstimate,cost,costPotential]=step(this)
      parameters=getParameters(this);
      objective('put',this);
      cpuStart=tic;
      costPotential=0;
      for k=1:this.popsize
        costPotential=max(costPotential,upperBound(this.measure{1}(k),this.tmin));
      end
      [this.optimizer,cost]=defineProblem(this.optimizer,@objective,parameters);
      cpuStep=toc(cpuStart);
      while(true)
        [this.optimizer,parameters,cost]=step(this.optimizer);
        if((toc(cpuStart)+cpuStep)>this.cpuDelta)
          break;
        end
      end
      this=putParameters(this,parameters);
      xEstimate=this.trajectory;
    end
    
  end
end

% private
function parameters=getParameters(this)
  parameters=[];
  for k=1:numel(this.trajectory)
    parameters=[parameters;getBits(this.trajectory(k),this.tmin)];
  end
end

% private
function this=putParameters(this,parameters)
  for k=1:this.popsize
    this.trajectory(k)=putBits(this.trajectory(k),parameters(k,:),this.tmin);
  end
end

% private
function varargout=objective(varargin)
  persistent this
  parameters=varargin{1};
  if(~ischar(parameters))
    this=putParameters(this,parameters);
    cost=zeros(this.popsize,1);
    for k=1:this.popsize
      cost(k)=evaluate(this.measure{1}(k),this.trajectory(k),this.tmin);
    end
    % TODO: enable multiple measures
    varargout{1}=cost;
  elseif(strcmp(parameters,'put'))
    this=varargin{2};
  else
    error('incorrect argument list');
  end
end
