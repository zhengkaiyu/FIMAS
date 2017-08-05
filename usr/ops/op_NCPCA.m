function [ status, message ] = op_NCPCA( data_handle, option, varargin )
%op_NCPCA Calculate Noise-Corrected Principal Component Analysis
% reference: Marois, L. A., Labouesse, S & Suhling, K.
%            Noise?Corrected Principal Component Analysis of fluorescence lifetime imaging data.
%            Journal of  Biophotonics (2016). doi:10.1002/jbio.201600160
%

parameters=struct('note','',...
    'operator','op_NCPCA',...
    'parameter_space','PC1|PC2|PC3',... %principle component determined by max_component
    'bin_dim',[1,1,1,1,1],...
    'fit_t0',3e-10,... %start look for peak here
    'fit_t1',9e-9,... %ns after peak to calculate
    'data_norm',1,... %normalise FLIM trace
    'bg_threshold',10,... %background threshold for peak value
    'noise_type','poisson',... % noise correction type (none/poisson/variance)
    'max_component',3,...   %maximum number of principle component to extract
    't_disp_bound',[0.05,0.5,64],...
    'eigenvec',[]);

status=false;message='';

try
    data_idx=data_handle.current_data;%default to current data
    % get optional input if exist
    if nargin>2
        % get parameters argument
        usroption=varargin(1:2:end);
        % get value argument
        usrval=varargin(2:2:end);
        % loop through to assign input values
        for option_idx=1:numel(usroption)
            switch usroption{option_idx}
                case 'data_index'
                    % specified data indices
                    data_idx=usrval{option_idx};
            end
        end
    end
    
    switch option
        case 'add_data'
            for current_data=data_idx
                switch data_handle.data(current_data).datatype
                    case {'DATA_IMAGE','DATA_TRACE','RESULT_IMAGE','RESULT_TRACE'}
                        % check data dimension, we only take tXY, tXT, tT, tXYZ,
                        % tXYZT
                        switch bin2dec(num2str(data_handle.data(current_data).datainfo.data_dim>1))
                            case {16,17,25,28,29,30,31}
                                % t (10000) / tT (10001) / tXT (11001) / tXY (11100) /
                                % tXYT (11101) / tXYZ (11110) / tXYZT (11111)
                                parent_data=current_data;
                                % add new data
                                data_handle.data_add(cat(2,'op_NCPCA|',data_handle.data(current_data).dataname),[],[]);
                                % get new data index
                                new_data=data_handle.current_data;
                                % copy over datainfo
                                data_handle.data(new_data).datainfo=data_handle.data(parent_data).datainfo;
                                % set data index
                                data_handle.data(new_data).datainfo.data_idx=new_data;
                                % set parent data index
                                data_handle.data(new_data).datainfo.parent_data_idx=parent_data;
                                % combine the parameter fields
                                data_handle.data(new_data).datainfo=setstructfields(data_handle.data(new_data).datainfo,parameters);%parameters field will replace duplicate field in data
                                data_handle.data(new_data).datainfo.dt=1;
                                data_handle.data(new_data).datainfo.t=1:1:parameters.max_component;% only two parameters
                                data_handle.data(new_data).datainfo.data_dim(1)=parameters.max_component;
                                % pass on metadata info
                                data_handle.data(new_data).metainfo=data_handle.data(parent_data).metainfo;
                                message=sprintf('%s added\n',data_handle.data(new_data).dataname);
                                status=true;
                            otherwise
                                message=sprintf('only take tXY, tXT, tT, tXYZ data type\n');
                                return;
                        end
                end
            end
        case 'modify_parameters'
            current_data=data_handle.current_data;
            %change parameters from this method only
            for pidx=numel(varargin)/2
                parameters=varargin{2*pidx-1};
                val=varargin{2*pidx};
                switch parameters
                    case 'note'
                        data_handle.data(current_data).datainfo.note=num2str(val);
                        status=true;
                    case {'operator','parameter_space'}
                        message=sprintf('%sUnauthorised to change %s\n',message,parameters);
                        status=false;
                    case 'fit_t0'
                        val=str2double(val);
                        if val>=data_handle.data(current_data).datainfo.fit_t1;
                            message=sprintf('%sfit_t0 must be strictly < fit_t1\n',message);
                            status=false;
                        else
                            data_handle.data(current_data).datainfo.fit_t0=val;
                            status=true;
                        end
                    case 'fit_t1'
                        val=str2double(val);
                        if val<=data_handle.data(current_data).datainfo.fit_t0;
                            message=sprintf('%sfit_t1 must be strictly > fit_t0\n',message);
                            status=false;
                        else
                            data_handle.data(current_data).datainfo.fit_t1=val;
                            status=true;
                        end
                    case 'noise_type'
                        switch val
                            case {'none','poisson','variance'}
                                data_handle.data(current_data).datainfo.noise_type=val;
                            otherwise
                                %default to poisson noise cancellation
                                data_handle.data(current_data).datainfo.noise_type='poisson';
                        end
                        status=true;
                    case 'data_norm'
                        val=str2double(val);
                        if val==0
                            data_handle.data(current_data).datainfo.data_norm=false;
                        else
                            data_handle.data(current_data).datainfo.data_norm=true;
                        end
                    case 'bg_threshold'
                        val=str2double(val);
                        data_handle.data(current_data).datainfo.bg_threshold=val;
                        status=true;
                    case 'max_component'
                        val=str2double(val);
                        data_handle.data(current_data).datainfo.max_component=val;
                        %make PC# pattern for parameter_space
                        pstr=sprintf('PC%g|',1:1:val);
                        data_handle.data(current_data).datainfo.parameter_space=pstr(1:end-1);
                        status=true;
                    case 'eigenvec'
                        if isempty(data_handle.data(current_data).datainfo.eigenvec)
                            % load eigenvector from text mat
                            [filename,pathname,~]=uigetfile({'*.dat','Exported ascii eigenvectors (*.dat)'},'Select Raw Data File','MultiSelect','off',data_handle.path.export);
                            if pathname~=0
                                temp=load(cat(2,pathname,filename),'-ascii');
                                data_handle.data(current_data).datainfo.eigenvec=temp([1,2:2:end],:)';
                                data_handle.data(current_data).datainfo.max_component=size(temp,1)/2;
                                status=true;
                            else
                                
                            end
                        elseif isempty(val)
                            % remove current eigenvectors
                            data_handle.data(current_data).datainfo.eigenvec=[];
                            status=true;
                        else
                            % plot+export eigenvector
                            %Display NC-PCA results
                            figure('Name',sprintf('NC-PCA Principal Components for %s',data_handle.data(current_data).dataname),...
                                'NumberTitle','off',...
                                'MenuBar','none',...
                                'ToolBar','figure',...
                                'Keypressfcn',@export_panel);
                            plot(data_handle.data(current_data).datainfo.eigenvec(:,1),data_handle.data(current_data).datainfo.eigenvec(:,2:end));
                            title('Press F3 to export');
                            legend({'PC1','PC2','PC3','PC4','PC5','PC6'});
                            status=true;
                        end
                    otherwise
                        message=sprintf('%sUnauthorised to change %s\n',message,parameters);
                        status=false;
                end
                if status
                    message=sprintf('%s%s has changed to %s\n',message,parameters,val);
                end
            end
        case 'calculate_data'
            for current_data=data_idx
                % go through each selected data
                parent_data=data_handle.data(current_data).datainfo.parent_data_idx;
                switch data_handle.data(parent_data).datatype
                    case {'DATA_IMAGE'}%originated from 3D/4D traces_image
                        % get pixel binnin information
                        pX_lim=numel(data_handle.data(parent_data).datainfo.X);
                        pY_lim=numel(data_handle.data(parent_data).datainfo.Y);
                        pZ_lim=numel(data_handle.data(parent_data).datainfo.Z);
                        pT_lim=numel(data_handle.data(parent_data).datainfo.T);
                        Xbin=data_handle.data(current_data).datainfo.bin_dim(2);
                        Ybin=data_handle.data(current_data).datainfo.bin_dim(3);
                        Zbin=data_handle.data(current_data).datainfo.bin_dim(4);
                        Tbin=data_handle.data(current_data).datainfo.bin_dim(5);
                        
                        windowsize=[1,Xbin,Ybin,Zbin,Tbin];
                        
                        fval=convn(data_handle.data(parent_data).dataval,ones(windowsize),'same');
                        [eigenval,eigenvec]=calculate_NCPCA(fval,data_handle.data(current_data).datainfo.noise_type,...
                            data_handle.data(current_data).datainfo.data_norm,...
                            data_handle.data(current_data).datainfo.bg_threshold,...
                            data_handle.data(current_data).datainfo.max_component,...
                            data_handle.data(parent_data).datainfo.data_dim,...
                            data_handle.data(current_data).datainfo.eigenvec);
                        
                        data_handle.data(current_data).dataval=eigenval;
                        data_handle.data(current_data).datainfo.eigenvec=[data_handle.data(parent_data).datainfo.t(:),eigenvec];
                        data_handle.data(current_data).datainfo.data_dim=[data_handle.data(current_data).datainfo.max_component,pX_lim,pY_lim,pZ_lim,pT_lim];
                        data_handle.data(current_data).datatype=data_handle.get_datatype(current_data);
                        data_handle.data(current_data).datainfo.dt=1;
                        data_handle.data(current_data).datainfo.t=1:1:data_handle.data(current_data).datainfo.max_component;% only two parameters
                        data_handle.data(current_data).datainfo.last_change=datestr(now);
                        status=true;
                    case {'DATA_TRACE'}
                        Xbin=data_handle.data(current_data).datainfo.bin_dim(2);
                        Ybin=data_handle.data(current_data).datainfo.bin_dim(3);
                        Zbin=data_handle.data(current_data).datainfo.bin_dim(4);
                        Tbin=data_handle.data(current_data).datainfo.bin_dim(5);
                        windowsize=[1,Xbin,Ybin,Zbin,Tbin];
                        fval=convn(data_handle.data(parent_data).dataval,ones(windowsize),'same');
                        [eigenval,eigenvec]=calculate_NCPCA(fval,data_handle.data(current_data).datainfo.noise_type,...
                            data_handle.data(current_data).datainfo.data_norm,...
                            data_handle.data(current_data).datainfo.bg_threshold,...
                            data_handle.data(current_data).datainfo.max_component,...
                            data_handle.data(parent_data).datainfo.data_dim,...
                            data_handle.data(current_data).datainfo.eigenvec);
                        data_handle.update_data('dataval',eigenval);
                        data_handle.data(current_data).datainfo.eigenvec=[data_handle.data(parent_data).datainfo.t(:),eigenvec];
                        data_handle.data(current_data).datainfo.data_dim=[data_handle.data(current_data).datainfo.max_component,pX_lim,pY_lim,pZ_lim,pT_lim];
                        data_handle.data(current_data).datatype=data_handle.get_datatype(current_data);
                        data_handle.data(current_data).datainfo.dt=1;
                        data_handle.data(current_data).datainfo.t=1:1:data_handle.data(current_data).datainfo.max_component;% only two parameters
                        data_handle.data(current_data).datainfo.last_change=datestr(now);
                        status=true;
                end
            end
    end
catch exception
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
    message=exception.message;
end

    function export_panel(handle,eventkey)
        global SETTING;
        switch eventkey.Key
            case {'f3'}
                SETTING.export_panel(findobj(handle,'Type','Axes'));
        end
    end

    function [val,vec]=calculate_NCPCA(data,NoiseType,datanorm,threshold,MaxDims,datasize,eigvec)
        % arrange to only decay profile no 2D info
        % image arranged as vectors containing each a decay.
        % in the format of p x n, where p is the number of variables and n
        % is number of samples
        data=reshape(data,datasize(1),prod(datasize(2:end)));
        % calculate noise from data
        switch NoiseType
            % Poisson scaling of data to account for detection noise. Other types for demo only.
            case 'none'
                NoiseCorrection=1;
            case 'poisson'
                %Scaling factor = square root of average intensity at each time
                %bin.
                NoiseCorrection=sqrt(mean(data,2)+eps);
            case 'variance'
                %Scaling factor = standard deviation at each time bin
                NoiseCorrection=std(data,0,2)+eps;
        end
        % find peak
        [maxv,peak_ind]=max(squeeze(mean(data,2)));
        mask_ncpca=(data(peak_ind,:))>threshold;
        % The background is removed before the normalization, however, the norm is estimated including the background
        data=bsxfun(@times,data,mask_ncpca);%Bg is single value
        %Image is normalised by scaling factor
        data_norm = bsxfun(@rdivide,data,NoiseCorrection);
        if datanorm
            data_norm(:,mask_ncpca) = bsxfun(@rdivide,data_norm(:,mask_ncpca),max(data_norm(:,mask_ncpca),[],1));
        end
        
        % single value decomposition to find out eigenvec and eigenval
        if isempty(eigvec)
            % Data is centered by subtract variable means (i.e. p dimension)
            data_norm_cent=bsxfun(@minus, data_norm,mean(data_norm,1));
            %covariance matrix of dataset (pxp using C=X*transpose(X)/(n-1))
            myc = (data_norm_cent*data_norm_cent')/(size(data_norm_cent,2)-1);
            %SVD of covariance matrix
            [U D V] = svds(transpose(myc),MaxDims,'largest');% really need transpose?
            
            %Extraction of first desired eigenvectors
            %mybasis=V(:,1:MaxDims);
            mybasis=V;
            %Optional : force positive maximum of Eigenvectors
            for i=1:MaxDims;
                if abs(min(mybasis(:,i)))>abs(max(mybasis(:,i)));
                    mybasis(:,i)=-mybasis(:,i);
                end
            end
            %calculate orthogonal projection of pixel data on the selected eigenvectors
            %= pixel scores
            projected=transpose(transpose(mybasis)*(data_norm));
            Scores=reshape(projected,[datasize(2) datasize(3) datasize(4) datasize(5) MaxDims]);
            % Apply reverse scaling to eigenvectors
            if numel(NoiseCorrection) > 1
                Eigenvectors=mybasis .* repmat(double(squeeze(NoiseCorrection)),[1 size(mybasis,2)]);
            else
                Eigenvectors=mybasis .* NoiseCorrection;
            end
            
            %Display NC-PCA results
            figure('Name','NC-PCA Principal Components',...
                'NumberTitle','off',...
                'MenuBar','none',...
                'ToolBar','figure',...
                'Keypressfcn',@export_panel);
            plot(Eigenvectors);
            legend({'PC1','PC2','PC3','PC4','PC5','PC6'});
            %{
        %Filtering
        DF=D;
        DF(MaxDims+1:end,MaxDims+1:end)=0;
        % Forces all "unwanted" Eigenvalues to be zero and the others to be one.
        %Thus only a projection onto the subspace is performed.
        for n=1:MaxDims
            DF(n,n)=1;
        end
        Filtered = (U*(DF*(transpose(V)*data_norm)));
        FiltImg=bsxfun(@times,reshape(Filtered,[size(Filtered,1) datasize(2) datasize(3) datasize(4) datasize(5)]),NoiseCorrection);
        figure;mesh(squeeze(sum(FiltImg,1)),'FaceColor','interp','EdgeColor','none');view([0 -90]);
            %}
            vec=mybasis;
            val=permute(Scores,[5,1,2,3,4]);
        else
            % do eigenvec/eigenval calculation
            if size(eigvec,1)==datasize(1)
                mybasis=eigvec(:,2:end);
            else
                mybasis=zeros(datasize(1),size(eigvec,2)-1);
                for m=1:1:size(mybasis,2)
                    mybasis(:,m) = interp1(eigvec(:,1),eigvec(:,m+1),data_handle.data(parent_data).datainfo.t);
                end
                mybasis(isnan(mybasis))=0;
            end
            projected=transpose(transpose(mybasis)*(data_norm));
            Scores=reshape(projected,[datasize(2) datasize(3) datasize(4) datasize(5) MaxDims]);
            vec=mybasis;
            val=permute(Scores,[5,1,2,3,4]);
        end
    end
end