classdef opticalFlowPyramid < measure
  
  properties (GetAccess=private,SetAccess=private)
    cameraHandle
    windowSize
    numLevels
    iterations
  end  
  
  methods (Access=public)
    
    function this=opticalFlowPyramid(cameraHandle)
    
      fprintf('\n');
      fprintf('\nopticalFlowPyramid::opticalFlowPyramid');
      this.cameraHandle=cameraHandle;
      this.windowSize=3; 
      this.numLevels=3; 
      this.iterations=3; 
    end
    
    function cost=evaluate(this,x,tmin)
    
      fprintf('\n');
      fprintf('\nopticalFlowPyramid::evaluate');
      [a,b]=domain(this.cameraHandle);
      tmin=getTime(this.cameraHandle,a);
      tmax=getTime(this.cameraHandle,b);
      pqa=evaluate(x,tmin);
      fprintf('\nx(%f) = < ',tmin);
      fprintf('%f ',pqa);
      fprintf('>');
      pqb=evaluate(x,tmax);      
      fprintf('\nx(%f) = < ',tmax);
      fprintf('%f ',pqb);
      fprintf('>');
      im1=getImage(this.cameraHandle,a); 
	  im2=getImage(this.cameraHandle,b); 
	  if(interpretLayers(this.cameraHandle)=='rgb')
	    im1=rgb2gray(im1); 
	    im2=rgb2gray(im2); 
	  end
	  [u,v]=hierarchicalLK(this,im1,im2);
	  pa=pqa(1:3,:);
	  qa=pqa(4:7,:);
	  pb=pqb(1:3,:);
	  qb=pqb(4:7,:);
 	  Ea=quat2EulerDD(this,qa);
	  Eb=quat2EulerDD(this,qb);
	  translation(1)=pb(1)-pa(1);
	  translation(2)=pb(2)-pa(2);
	  translation(3)=pb(3)-pa(3);
	  rotation(1)=Eb(1)-Ea(1);
	  rotation(2)=Eb(2)-Ea(2);
	  rotation(3)=Eb(3)-Ea(3);	
	  [uvr,uvt]=generateFlow(this,translation,rotation);
	  cost=computeCost(this,u,v,uvr, uvt);
	  fprintf('\ncost = %f',cost);
    end
  end
  
  methods (Access=private)
  
		function [u,v]=hierarchicalLK(x,im1,im2)
		% Hierarchical Lucas Kanade (using pyramids)
		% Tested for pyramids of height 1, 2, 3 only... operation with
		% pyramids of height 4 might be unreliable
		% NUMLEVELS    Pyramid Levels (typical value 3)
		% WINDOWSIZE   Size of smoothing window (typical value 1-4)
		% ITERATIONS   number of iterations (typical value 1-5)
		% Sohaib Khan, edited 05-15-03 (Yaser) yaser@cs.ucf.edu
		% [1]   B.D. Lucas and T. Kanade, "An Iterative Image Registration technique,
		%       with an Application to Stero Vision," Int'l Joint Conference Artifical 
		%       Intelligence, pp. 121-130, 1981. 
		
		if (size(im1,1)~=size(im2,1)) | (size(im1,2)~=size(im2,2))
		    error('images are not same size');
		end;
		if (size(im1,3) ~= 1) | (size(im2, 3) ~= 1)
		    error('input should be gray level images');
		end;
		% check image sizes and crop if not divisible
		if (rem(size(im1,1), 2^(x.numLevels - 1)) ~= 0)
		    warning('image will be cropped in height, size of output will be smaller than input!');
		    im1 = im1(1:(size(im1,1) - rem(size(im1,1), 2^(x.numLevels - 1))), :);
		    im2 = im2(1:(size(im1,1) - rem(size(im1,1), 2^(x.numLevels - 1))), :);
		end;
		if (rem(size(im1,2), 2^(x.numLevels - 1)) ~= 0)
		    warning('image will be cropped in width, size of output will be smaller than input!');
		    im1 = im1(:, 1:(size(im1,2) - rem(size(im1,2), 2^(x.numLevels - 1))));
		    im2 = im2(:, 1:(size(im1,2) - rem(size(im1,2), 2^(x.numLevels - 1))));
		end;
		%Build Pyramids
		pyramid1=im1;
		pyramid2=im2;
		for i=2:x.numLevels
		    im1=reduce(x,im1);
		    im2=reduce(x,im2);
		    pyramid1(1:size(im1,1), 1:size(im1,2), i) = im1;
		    pyramid2(1:size(im2,1), 1:size(im2,2), i) = im2;
		end;
		% base level computation
		disp('Computing Level 1');
		baseIm1=pyramid1(1:(size(pyramid1,1)/(2^(x.numLevels-1))), 1:(size(pyramid1,2)/(2^(x.numLevels-1))), x.numLevels);
		baseIm2=pyramid2(1:(size(pyramid2,1)/(2^(x.numLevels-1))), 1:(size(pyramid2,2)/(2^(x.numLevels-1))), x.numLevels);
		[u,v]=lucasKanade(x,baseIm1,baseIm2);
		for r=1:x.iterations
		    [u,v,cert]=lucasKanadeRefined(x,u,v,baseIm1,baseIm2);
		end
		%propagating flow 2 higher levels
		for i = 2:x.numLevels
		    disp(['Computing Level ', num2str(i)]);
		    uEx=2 * imresize(u,size(u)*2);   % use appropriate expand function (gaussian, bilinear, cubic, etc).
		    vEx=2 * imresize(v,size(v)*2);
		    curIm1=pyramid1(1:(size(pyramid1,1)/(2^(x.numLevels - i))), 1:(size(pyramid1,2)/(2^(x.numLevels - i))), (x.numLevels - i)+1);
		    curIm2=pyramid2(1:(size(pyramid2,1)/(2^(x.numLevels - i))), 1:(size(pyramid2,2)/(2^(x.numLevels - i))), (x.numLevels - i)+1);
		    [u, v]=lucasKanadeRefined(x,uEx,vEx,curIm1,curIm2);
		    for r=1:x.iterations
		        [u, v, cert]=lucasKanadeRefined(x,u,v,curIm1,curIm2);
		    end
		end;
   		%figure, quiver(reduce(x,(reduce(x,medfilt2(flipud(u),[5 5])))), -reduce(x,(reduce(medfilt2(flipud(v),[5 5])))), 0), axis equal
	end

	function [u,v,cert]=lucasKanadeRefined(x,uIn,vIn,im1,im2);

		% Lucas Kanade Refined computes lucas kanade flow at the current level given previous estimates!
		%current implementation is only for a 3x3 window
		uIn=round(uIn);
		vIn=round(vIn);
		u=zeros(size(im1));
		v=zeros(size(im2));
		%to compute derivatives, use a 5x5 block... the resulting derivative will be 5x5...
		% take the middle 3x3 block as derivative
		for i=3:size(im1,1)-2
		   for j=3:size(im2,2)-2
		      curIm1=im1(i-2:i+2, j-2:j+2);
		      lowRindex=i-2+vIn(i,j);
		      highRindex=i+2+vIn(i,j);
		      lowCindex=j-2+uIn(i,j);
		      highCindex=j+2+uIn(i,j);
		      if (lowRindex < 1) 
		         lowRindex=1;
		         highRindex=5;
		      end;
		      if (highRindex > size(im1,1))
		         lowRindex=size(im1,1)-4;
		         highRindex=size(im1,1);
		      end;
		      if (lowCindex < 1) 
		         lowCindex=1;
		         highCindex=5;
		      end;
		      if (highCindex > size(im1,2))
		         lowCindex=size(im1,2)-4;
		         highCindex=size(im1,2);
		      end;
		      if isnan(lowRindex)
		         lowRindex=i-2;
		         highRindex=i+2;
		      end;
		      if isnan(lowCindex)
		         lowCindex=j-2;
		         highCindex=j+2;
		      end;
		      curIm2=im2(lowRindex:highRindex, lowCindex:highCindex);
		      [curFx, curFy, curFt]=computeDerivatives(x,curIm1,curIm2);
		      curFx=curFx(2:4, 2:4);
		      curFy=curFy(2:4, 2:4);
		      curFt=curFt(2:4, 2:4);
		      curFx=curFx';
		      curFy=curFy';
		      curFt=curFt';
			  curFx=curFx(:);
		      curFy=curFy(:);
		      curFt=-curFt(:);
		      A=[curFx curFy];
		      U=pinv(A'*A)*A'*curFt;
		      u(i,j)=U(1);
		      v(i,j)=U(2);
		      cert(i,j)=rcond(A'*A);
		   end;
		end;
		u=u+uIn;
		v=v+vIn;
	end		
		
	function [fx, fy, ft]=computeDerivatives(x,im1,im2);
		%ComputeDerivatives	Compute horizontal, vertical and time derivative
		%							between two gray-level images.
		if (size(im1,1) ~= size(im2,1)) | (size(im1,2) ~= size(im2,2))
		   error('input images are not the same size');
		end;
		if (size(im1,3)~=1) | (size(im2,3)~=1)
		   error('method only works for gray-level images');
		end;
		fx=conv2(double(im1),double(0.25* [-1 1; -1 1])) + conv2(double(im2), double(0.25*[-1 1; -1 1]));
		fy=conv2(double(im1), double(0.25*[-1 -1; 1 1])) + conv2(double(im2), double(0.25*[-1 -1; 1 1]));
		ft=conv2(double(im1), double(0.25*ones(2))) + conv2(double(im2), double(-0.25*ones(2)));
		% make same size as input
		fx=fx(1:size(fx,1)-1, 1:size(fx,2)-1);
		fy=fy(1:size(fy,1)-1, 1:size(fy,2)-1);
		ft=ft(1:size(ft,1)-1, 1:size(ft,2)-1);
	end

	function [u,v] = lucasKanade(x, im1, im2)

        %LucasKanade  lucas kanade algorithm, without pyramids (only 1 level);
		[fx, fy, ft]=computeDerivatives(x, im1, im2);
		u=zeros(size(im1));
		v=zeros(size(im2));
		halfWindow = floor(x.windowSize/2);
		for i=halfWindow+1:size(fx,1)-halfWindow
		for j=halfWindow+1:size(fx,2)-halfWindow
		  curFx=fx(i-halfWindow:i+halfWindow, j-halfWindow:j+halfWindow);
		  curFy=fy(i-halfWindow:i+halfWindow, j-halfWindow:j+halfWindow);
		  curFt=ft(i-halfWindow:i+halfWindow, j-halfWindow:j+halfWindow);
		  curFx=curFx';
		  curFy=curFy';
		  curFt=curFt';
		  curFx=curFx(:);
		  curFy=curFy(:);
		  curFt=-curFt(:);
		  A=[curFx curFy];
		  U=pinv(A'*A)*A'*curFt;
		  u(i,j)=U(1);
		  v(i,j)=U(2);
		end;
		end;
		u(isnan(u))=0;
		v(isnan(v))=0;
    end 
    
    function smallIm=reduce(x,im)
		% REDUCE	Compute smaller layer of Gaussian Pyramid
		% Sohaib Khan, Feb 16, 2000
		%Algo
		%Gaussian mask = [0.05 0.25 0.4 0.25 0.05] 
		% Apply 1d mask to alternate pixels along each row of image
		% apply 1d mask to each pixel along alternate columns of resulting image
		mask=[0.05 0.25 0.4 0.25 0.05];
		hResult=conv2(double(im),double(mask));
		hResult=hResult(:,3:size(hResult,2)-2);
		hResult=hResult(:, 1:2:size(hResult,2));
		vResult=conv2(double(hResult),double(mask'));
		vResult=vResult(3:size(vResult,1)-2, :);
		vResult=vResult(1:2:size(vResult,1),:);
		smallIm=vResult;
	end

	function [uvr,uvt]=generateFlow(x,translation,rotation)
		
		s1=sin(rotation(1));
		c1=cos(rotation(1));
		s2=sin(rotation(2));
		c2=cos(rotation(2));
		s3=sin(rotation(3));
		c3=cos(rotation(3));
		R = [c3*c2, c3*s2*s1-s3*c1, s3*s1+c3*s2*c1; s3*c2, c3*c1+s3*s2*s1, s3*s2*c1-c3*s1; -s2, c2*s1, c2*c1];
		[m,n]=getImageSize(x.cameraHandle);
		[jj,ii]=meshgrid((1:m)-1,(1:n)-1);
		pix=[jj(:)';ii(:)'];
		ray=inverseProjection(x.cameraHandle,pix);
		ray_new=transpose(R)*ray; 
		x_new=projection(x.cameraHandle,ray_new);
		fr(1,:)=pix(1,:)-x_new(1,:);
		fr(2,:)=pix(2,:)-x_new(2,:);
		T_norm=(1E-8)*translation/sqrt(dot(translation,translation));
		ray_new(1,:)=ray(1,:)-T_norm(3);
		ray_new(2,:)=ray(2,:)-T_norm(1);
		ray_new(3,:)=ray(3,:)-T_norm(2);
		x_new=projection(x.cameraHandle,ray_new);
		ft(1,:)=pix(1,:)-x_new(1,:);
		ft(2,:)=pix(2,:)-x_new(2,:);
		uvr(1,:,:)=reshape(fr(1,:),m,n);
		uvr(2,:,:)=reshape(fr(2,:),m,n);
		uvt(1,:,:)=reshape(ft(1,:),m,n);
		uvt(2,:,:)=reshape(ft(2,:),m,n);
		uvr(isnan(uvr(:,:,:))) = 0;
		uvt(isnan(uvt(:,:,:))) = 0;
	end

	function cost=computeCost(x,Vx_OF,Vy_OF,uvr,uvt)
			
			[FIELD_Y,FIELD_X]=size(Vx_OF);
			upperBound=(FIELD_X.*FIELD_Y.*2);
			Vxr(:,:)=uvr(1,:,:);
			Vyr(:,:)=uvr(2,:,:);
			Vxt(:,:)=uvt(1,:,:);
			Vyt(:,:)=uvt(2,:,:);
		    % Drop magnitude of translation
		    mag = (Vxt.^2 + Vyt.^2).^.5; % TODO: use faster magnitude calculation
		 	mag(mag(:)==0)=1; 
	        Vxt=Vxt./mag;
	        Vyt=Vyt./mag;
		    % remove rotation effect
		    Vx_OFT=(Vx_OF - Vxr);
		    Vy_OFT=(Vy_OF - Vyr);
		    % Drop magnitude and keep direction only
		    mag=(Vx_OFT.^2 + Vy_OFT.^2).^.5;
		    mag(mag(:)==0)=1; 
		    Vx_OFTD=Vx_OFT./mag;
		    Vy_OFTD=Vy_OFT./mag;
		    % remove NaNs
		    Vx_OFTD(isnan(Vx_OFTD))=0;
		    Vy_OFTD(isnan(Vy_OFTD))=0;
		    % Calculate Error
		    ErrorX=(Vx_OFTD - Vxt);
		    ErrorY=(Vy_OFTD - Vyt);
		    ErrorMag=(ErrorX.^2 + ErrorY.^2).^.5;
		    cost=sum(ErrorMag(:))/upperBound; % TODO: check this calculation
	end
	
	function E=quat2EulerDD(x,Q)
		
		N=size(Q,2);
		Q=quatNormDD(x,Q);
		q1=Q(1,:);
		q2=Q(2,:);
		q3=Q(3,:);
		q4=Q(4,:);
		q11=q1.*q1;
		q22=q2.*q2;
		q33=q3.*q3;
		q44=q4.*q4;
		q12=q1.*q2;
		q23=q2.*q3;
		q34=q3.*q4;
		q14=q1.*q4;
		q13=q1.*q3;
		q24=q2.*q4;
		if isnumeric(Q)
		  E=zeros(3,N);
		  E(1,:)=atan2(2*(q34+q12),q11-q22-q33+q44);
		  E(2,:)=real(asin(-2*(q24-q13)));
		  E(3,:)=atan2(2*(q23+q14),q11+q22-q33-q44);
		else
		  E=sym(zeros(3,N));
		  E(1,:)=atan((2*(q34+q12))./(q11-q22-q33+q44));
		  E(2,:)=asin(-2*(q24-q13));
		  E(3,:)=atan((2*(q23+q14))./(q11+q22-q33-q44));
		end
	end
	
	function Q=quatNormDD(x,Q)

		  % input checking
		  if(size(Q,1)~=4)
		    error('argument must be 4-by-n');
		  end
		  % extract elements
		  q1=Q(1,:);
		  q2=Q(2,:);
		  q3=Q(3,:);
		  q4=Q(4,:);
		  % normalization factor
		  n=sqrt(q1.*q1+q2.*q2+q3.*q3+q4.*q4);
		  % handle negative first element and zero denominator
		  s=sign(q1);
		  ns=n.*s;
		  ns(ns==0)=1;
		  % normalize
		  Q(1,:)=q1./ns;
		  Q(2,:)=q2./ns;
		  Q(3,:)=q3./ns;
		  Q(4,:)=q4./ns;
	end

  end
  
end