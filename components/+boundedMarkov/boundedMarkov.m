% This class represents the integration of linear Markov motion model with a bounded forcing function
classdef boundedMarkov < boundedMarkov.boundedMarkovConfig & dynamicModel
  
  properties (GetAccess=private,SetAccess=private)
    numStates
    firstNewBlock % one-based indexing
    chunkSize
    ta
    tb
    block % one-based indexing
    numInputs
    state % body state starting at initial time
    Ad % discrete version of state space A matrix
    Bd % discrete version of state space A matrix
    ABZ % intermediate formulation of A and B matrices with zeros appended
  end
  
  methods (Static=true,Access=public)
    function description=getInitialBlockDescription
      description=struct('numLogical',uint32(0),'numUint32',uint32(0));      
    end
    
    function description=getExtensionBlockDescription
      description=struct('numLogical',uint32(0),'numUint32',uint32(size(dynamicModelStub.dynamicModelStubConfig.B,2)));
    end
    
    function blocksPerSecond=getUpdateRate
      blocksPerSecond=dynamicModelStub.dynamicModelStubConfig.blocksPerSecond;
    end
  end
  
  methods (Access=public)
    function this=boundedMarkov(uri,initialTime,initialBlock)
      this=this@dynamicModel(uri,initialTime,initialBlock);
      fprintf('\n\n%s',class(this));
      this.numStates=12;
      this.firstNewBlock=1;
      this.chunkSize=256;
      this.ta=initialTime;
      this.tb=initialTime;
      this.block=struct('logical',{},'uint32',{});
      this.numInputs=size(this.B,2);
      this.state=zeros(this.numStates,this.chunkSize);
      this.ABZ=[this.A,this.B;sparse(this.numInputs,this.numStates+this.numInputs)];
      ABd=expmApprox(this.ABZ/this.blocksPerSecond);
      this.Ad=sparse(ABd(1:this.numStates,1:this.numStates));
      this.Bd=sparse(ABd(1:this.numStates,(this.numStates+1):end));
    end

    function cost=computeInitialBlockCost(this,initialBlock)
      assert(isa(this,'dynamicModel'));
      assert(isa(initialBlock,'struct'));
      assert(~isempty(initialBlock));
      cost=0;
    end
    
    function setInitialBlock(this,initialBlock)
      assert(isa(this,'dynamicModel'));
      assert(isa(initialBlock,'struct'));
      assert(~isempty(initialBlock));
    end
    
    function cost=computeExtensionBlockCost(this,block)
      assert(isa(this,'dynamicModel'));
      assert(isa(block,'struct'));
      assert(~isempty(block));
      cost=0;
    end
    
    function numExtensionBlocks=getNumExtensionBlocks(this)
      numExtensionBlocks=numel(this.block);
    end
    
    function setExtensionBlocks(this,k,blocks)
      assert(numel(k)==numel(blocks));
      if(isempty(blocks))
        return;
      end
      assert((k(end)+1)<=numel(this.block));
      k=k+1; % convert to one-based index
      this.block(k)=blocks;
      this.firstNewBlock=min(this.firstNewBlock,k(1));
    end
    
    function appendExtensionBlocks(this,blocks)
      if(isempty(blocks))
        return;
      end
      this.block=cat(2,this.block,blocks);
      N=numel(this.block);
      if((N+1)>size(this.state,2))
        this.state=[this.state,zeros(this.numStates,this.chunkSize)];
      end
      this.tb=this.ta+N/this.blocksPerSecond;
    end
     
    function [ta,tb]=domain(this)
      ta=this.ta;
      tb=this.tb;
    end
   
    function [position,rotation,positionRate,rotationRate]=evaluate(this,t)
      N=numel(t);
      dt=t-this.ta;
      dk=dt*this.blocksPerSecond;
      dkFloor=floor(dk);
      dtFloor=dkFloor/this.blocksPerSecond;
      dtRemain=dt-dtFloor;
      position=NaN(3,N);
      rotation=NaN(4,N);
      positionRate=NaN(3,N);
      rotationRate=NaN(4,N);
      good=logical((t>=this.ta)&(t<=this.tb));
      firstGood=find(good,1,'first');
      lastGood=find(good,1,'last');
      blockIntegrate(this,ceil(dk(lastGood))); % ceil is not floor+1 for integers
      % Apply initial state while processing outputs
      for n=firstGood:lastGood
        substate=subIntegrate(this,dkFloor(n),dtRemain(n));
        position(:,n)=substate(1:3)+this.initialPosition;
        if(nargout>1)
          rotation(:,n)=Quat2Homo(AxisAngle2Quat(substate(4:6)))*this.initialRotation; % verified
          if(nargout>2)
            positionRate(:,n)=substate(7:9)+this.initialPositionRate;
            if(nargout>3)
              rotationRate(:,n)=0.5*Quat2Homo(rotation(:,n))*([0;this.initialOmega+substate(10:12)]);
            end
          end
        end
      end
    end
  end
  
  methods (Access=private)
    function blockIntegrate(this,K)
      for k=this.firstNewBlock:K
        force=block2unitforce(this.block(k));
        this.state(:,k+1)=this.Ad*this.state(:,k)+this.Bd*force;
      end
      this.firstNewBlock=K+1;
    end
    
    function substate=subIntegrate(this,kF,dt)
      sF=kF+1;
      if(dt<eps)
        substate=this.state(:,sF);
      else
        ABsub=expmApprox(this.ABZ*dt);
        Asub=ABsub(1:this.numStates,1:this.numStates);
        Bsub=ABsub(1:this.numStates,(this.numStates+1):end);
        force=block2unitforce(this.block(sF));
        substate=Asub*this.state(:,sF)+Bsub*force;
      end
    end
  end
    
end

function expA=expmApprox(A)
  expA=speye(size(A))+A+(A*A)/2;
end

function force=block2unitforce(block)
  halfIntMax=2147483647.5;
  force=double(block.uint32')/halfIntMax-1; % transpose
end

function h=Quat2Homo(q)
  q1=q(1);
  q2=q(2);
  q3=q(3);
  q4=q(4);
  h=[[q1,-q2,-q3,-q4]
     [q2, q1,-q4, q3]
     [q3, q4, q1,-q2]
     [q4,-q3, q2, q1]];
end

function q=AxisAngle2Quat(v)
  v1=v(1,:);
  v2=v(2,:);
  v3=v(3,:);
  n=sqrt(v1.*v1+v2.*v2+v3.*v3);
  n(n<eps)=eps;
  a=v1./n;
  b=v2./n;
  c=v3./n;
  th2=n/2;
  s=sin(th2);
  q1=cos(th2);
  q2=s.*a;
  q3=s.*b;
  q4=s.*c;
  q=[q1;q2;q3;q4];
end