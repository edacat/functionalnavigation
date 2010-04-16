classdef Objective < handle
  
  properties (GetAccess=public,SetAccess=private)
    input
  end

  properties (GetAccess=private,SetAccess=private)
    measure
    dynamicModelName
    uri
  end
  
  methods (Access=public)
    function this=Objective(dynamicModelName,measureNames,uri)
      assert(isa(dynamicModelName,'char'));
      assert(isa(measureNames{1},'char'));
      assert(isa(uri,'char'));
      this.dynamicModelName=dynamicModelName;
      this.uri=uri;
      for m=1:numel(measureNames)
        this.measure{m}=Measure.factory(measureNames{m},uri);
      end
      [ta,tb]=waitForData(this);
      this.input=DynamicModel.factory(dynamicModelName,ta,uri);
      initialBlock=generateBlock(this.input.initialBlockDescription);
      setInitialBlock(this.input,initialBlock);
      extend(this,tb);
    end
    
    function addInput(this)
      [ta,tb]=domain(this.input(1));
      this.input(end+1)=DynamicModel.factory(this.dynamicModelName,ta,this.uri);
      initialBlock=generateBlock(this.input(end).initialBlockDescription);
      setInitialBlock(this.input(end),initialBlock);
      extend(this,tb);
    end
    
    function num=numMeasures(this)
      num=numel(this.measure);
    end
    
    function [ka,kb]=findEdges(this,m,kaSpan,kbSpan)
      [ka,kb]=findEdges(this.measure{m},kaSpan,kbSpan);
    end
    
    function cost=computeEdgeCost(this,m,k,ka,kb)
      cost=computeEdgeCost(this.measure{m},this.input(k),ka,kb);
    end
    
    function flag=hasData(this,m)
      flag=hasData(this.measure{m});
    end
    
    function ka=first(this,m)
      ka=first(this.measure{m});
    end
    
    function ka=last(this,m)
      ka=last(this.measure{m});
    end
    
    function time=getTime(this,m,k)
      time=getTime(this.measure{m},k);
    end
    
    function refresh(this)
      [ta,tb]=waitForData(this);
      extend(this,tb);
    end
    
    function cost=computeCostMean(this,kaSpan,kbSpan)
      K=numel(this.input);
      M=numMeasures(this);
      B=double(numExtensionBlocks(this.input(1)));
      allGraphs=cell(K,M+1);

      % build cost graph from prior
      for k=1:K
        Fk=this.input(k);
        cost=sparse([],[],[],B+1,B+1,B+1);
        initialBlock=getInitialBlock(Fk);
        cost(1,1)=computeInitialBlockCost(Fk,initialBlock);
        extensionBlocks=getExtensionBlocks(Fk,uint32(0:(B-1)));
        for b=1:B
          cost(b,b+1)=computeExtensionBlockCost(Fk,extensionBlocks(b));
        end
        allGraphs{k,1}=cost;
      end

      % build cost graphs from measures
      numEdges=zeros(1,M);
      for m=1:M
        [ka,kb]=findEdges(this,m,kaSpan,kbSpan);
        numEdges(m)=numel(ka);
        for k=1:K
          if(numEdges(m))
            cost=zeros(1,numEdges(m));
            for edge=1:numEdges(m)
              cost(edge)=computeEdgeCost(this,m,k,ka(edge),kb(edge));
            end
            base=ka(1);
            span=double(kb(end)-base+1);
            allGraphs{k,1+m}=sparse(double(ka-base+1),double(kb-base+1),cost,span,span,numEdges(m));
          else
            allGraphs{k,1+m}=0;
          end
        end
      end

      % sum costs across graphs for each individual
      cost=zeros(K,1);
      for k=1:K
        for m=1:(M+1)
          costkm=allGraphs{k,m};
          cost(k)=cost(k)+sum(costkm(:));
        end
      end

      % normalize costs by total number of blocks and edges
      cost=cost/(1+B+sum(numEdges));
    end
  end
  
  methods (Access=private)    
    function [ta,tb]=waitForData(this)
      ta=Inf;
      tb=-Inf;
      while(isinf(ta))
        for m=1:numel(this.measure)
          gm=this.measure{m};
          refresh(gm);
          if(hasData(gm))
            ta=min(ta,getTime(gm,first(gm)));
            tb=max(tb,getTime(gm,last(gm)));
          end
        end
      end
    end
    
    function extend(this,tbNew)
      for k=1:numel(this.input)
        rate=this.input(k).updateRate;
        if(rate)
          [ta,tb]=domain(this.input(k));
          oldNumBlocks=numExtensionBlocks(this.input(k));
          newNumBlocks=ceil((tbNew-tb)*rate);
          numAppend=newNumBlocks-oldNumBlocks;
          if(newNumBlocks>oldNumBlocks)
            description=this.input(k).extensionBlockDescription;
            for b=1:numAppend
              extensionBlock=generateBlock(description);
              appendExtensionBlocks(this.input(k),extensionBlock);
            end
          end
        end
      end
    end
  end
  
end

function block=generateBlock(description)
  block=struct('logical',logical(rand(1,description.numLogical)>0.5),...
    'uint32',randi([0,4294967295],1,description.numUint32,'uint32'));
end