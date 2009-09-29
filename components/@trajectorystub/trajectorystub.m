classdef trajectorystub < trajectory
  properties
    pose
    parametersPerSecond
    dynamicParameters
  end
  methods
    function this=trajectorystub
      fprintf('\n');
      fprintf('\ntrajectorystub::trajectorystub');
      this.parametersPerSecond=15;
      this.pose=[0;0;0;1;0;0;0];
      this.dynamicParameters=logical(rand(1,30)>0.5);
    end

    function bits=getBits(this,tmin)
      bits=this.dynamicParameters;
    end

    function this=putBits(this,bits,tmin)
      fprintf('\n');
      fprintf('\n%s::putBits',class(this));
      fprintf('\ntmin = %f',tmin);
      fprintf('\nbits = ');
      fprintf('%d',bits);
      this.dynamicParameters=bits;
    end
    
    function cost=priorCost(this,bits,tmin)
      cost=zeros(size(bits,1),1);
    end
     
    function [a,b]=domain(this)
      a=0;
      b=numel(this.dynamicParameters)/this.parametersPerSecond;
    end
   
    function posquat=evaluate(this,t)
      N=numel(t);
      posquat=repmat(this.pose,[1,N]);
      posquat(2,:)=t;
      [a,b]=domain(this);
      posquat(:,t<a|t>b)=NaN;
    end
    
    function posquatdot=derivative(this,t)
      N=numel(t);
      posquatdot=zeros(7,N);
      posquatdot(2,:)=1;
      [a,b]=domain(this);
      posquatdot(:,t<a|t>b)=NaN;
    end
  end  
end