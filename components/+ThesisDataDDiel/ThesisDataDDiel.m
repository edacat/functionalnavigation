classdef ThesisDataDDiel < ThesisDataDDiel.ThesisDataDDielConfig & DataContainer

  properties (GetAccess=private,SetAccess=private)
    hasRef
    bodyRef
    sensors
    names
  end
  
  methods (Access=public)
    function this=ThesisDataDDiel
      this=this@DataContainer;
      dataSetName=this.dataSetName;
      repository=this.repository;
      localDir=fileparts(mfilename('fullpath'));
      localCache=fullfile(localDir,dataSetName);

      if(~exist(localCache,'dir'))
        zipName=[dataSetName,'.zip'];
        localZip=[localDir,'/',zipName];
        url=[repository,zipName];
        fprintf('\ncaching: %s',url);
        urlwrite(url,localZip);
        fprintf('\nunzipping: %s',localZip);
        unzip(localZip,localDir);
        delete(localZip);
      end
      this.hasRef=true;
      this.bodyRef=ThesisDataDDiel.BodyReference(localCache,dataSetName);   
      this.sensors{1}=ThesisDataDDiel.CameraSim(localCache);
      this.names{1}='CAMERA';
      this.sensors{2}=ThesisDataDDiel.InertialSim(localCache);
      this.names{2}='IMU';
    end
      
    function list=listSensors(this,type)
      assert(isa(type,'char'));
      K=numel(this.sensors);
      flag=false(K,1);
      for k=1:K
        if(isa(this.sensors{k},type))
          flag(k)=true;
        end
      end
      list=uint32(find(flag)-1);
    end
    
    function name=getSensorName(this,id)
      assert(isa(id,'uint32'));
      name=this.names{id+1};
    end
    
    function obj=getSensor(this,id)
      assert(isa(id,'uint32'));
      obj=this.sensors{id+1};
    end
    
    function flag=hasReferenceTrajectory(this)
      flag=this.hasRef;
    end
    
    function x=getReferenceTrajectory(this)
      x=this.bodyRef;
    end
  end
  
end