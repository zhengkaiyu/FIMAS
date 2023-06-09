function [ status, message ] = op_Eventfinder2D( data_handle, option, varargin )
%OP_EVENTFINDER2D using neighbouring correlation to find event in XYT data
%--------------------------------------------------------------------------
%=======================================
%options     values    explanation
%---Batch process----------------------------------------------------------
%   Parameter=struct('selected_data','1','rawdata_bin','[1,1,1,1,2]','delta_dim','[3,3,2]','percent_neighbour','25','threshold','0.1','parameter_space','Event');
%   selected_data=data index, 1 means previous generated data
%   rawdata_bin=[1,1,1,1,2], data binning
%   delta_dim=[3,3,2], n-nearest neighbour in XYT, min [1,1,1]
%   percent_neighbour=25,   percentage of neighbours have the same trend
%   threshold=0.1,    deltaI threshold for register increae/decrease
%   parameter_space='Event', name for generated parameters
%--------------------------------------------------------------------------
%   HEADER END

%table contents must all have default values
parameters=struct('note','',...
    'operator','op_Eventfinder2D',...
    'parameter_space','Event',...
    'rawdata_bin',[1,1,1,1,2],...
    'delta_dim',[3,3,2],...
    'percent_neighbour',25,...
    'threshold',0.1);

% assume worst
status=false;
% for batch process must return 'Data parentidx to childidx *' for each
% successful calculation
message='';
askforparam=true;
try
    %default to current data
    data_idx=data_handle.current_data;
    % get optional input if exist
    if nargin>2
        % get parameters argument
        usroption=varargin(1:2:end);
        % get value argument
        usrval=varargin(2:2:end);
        % loop through to assign input values
        for option_idx=1:numel(usroption)
            switch usroption{option_idx}
                case {'data_index','selected_data'}
                    % specified data indices
                    data_idx=usrval{option_idx};
                case 'batch_param'
                    % batch processing need to modify parameters to user
                    % specfication
                    op_Eventfinder2D(data_handle, 'modify_parameters','data_index',data_idx,'paramarg',usrval{option_idx});
                case 'paramarg'
                    % batch processing passed on modified paramaters
                    varargin=usrval{option_idx};
                    % batch processing avoid any manual input
                    askforparam=false;
            end
        end
    end
    
    switch option
        case 'add_data'
            for current_data=data_idx
                switch data_handle.data(current_data).datatype
                    case {'DATA_IMAGE','DATA_TRACE','RESULT_IMAGE','RESULT_TRACE'}
                        % check data dimension, we only take XYT at the
                        % moment
                        % CXYZT, where C=channel locates in t dimension
                        switch bin2dec(num2str(data_handle.data(current_data).datainfo.data_dim>1))
                            case {13}
                                % single detector channel XYT (01101)
                                parent_data=current_data;
                                % add new data
                                data_handle.data_add(sprintf('%s|%s',parameters.operator,data_handle.data(current_data).dataname),[],[]);
                                % get new data index
                                new_data=data_handle.current_data;
                                % copy over datainfo
                                data_handle.data(new_data).datainfo=data_handle.data(parent_data).datainfo;
                                % set data index
                                data_handle.data(new_data).datainfo.data_idx=new_data;
                                % set parent data index
                                data_handle.data(new_data).datainfo.parent_data_idx=parent_data;
                                data_handle.data(new_data).datainfo.parameter_space={'Event'};
                                % combine the parameter fields
                                data_handle.data(new_data).datainfo=setstructfields(data_handle.data(new_data).datainfo,parameters);%parameters field will replace duplicate field in data
                                data_handle.data(new_data).datainfo.bin_dim=data_handle.data(current_data).datainfo.bin_dim;
                                if isempty(data_handle.data(new_data).datainfo.bin_dim)
                                    data_handle.data(new_data).datainfo.bin_dim=[1,1,1,1,1];
                                end
                                % pass on metadata info
                                data_handle.data(new_data).metainfo=data_handle.data(parent_data).metainfo;
                                message=sprintf('%s\nData %s to %s added.',message,num2str(parent_data),num2str(new_data));
                                status=true;
                            otherwise
                                message=sprintf('%s\nonly take XYT data type.',message);
                                return;
                        end
                end
            end
            % ---------------------
        case 'modify_parameters'
            for current_data=data_idx
                %change parameters from this method only
                for pidx=1:1:numel(varargin)/2
                    parameters=varargin{2*pidx-1};
                    val=varargin{2*pidx};
                    switch parameters
                        case 'note'
                            data_handle.data(current_data).datainfo.note=num2str(val);
                            status=true;
                        case 'operator'
                            message=sprintf('%s\nUnauthorised to change %s.',message,parameters);
                            status=false;
                        case 'parameter_space'
                            data_handle.data(current_data).datainfo.parameter_space=num2str(val);
                            status=true;
                        case 'rawdata_bin'
                            val=max(str2num(val),[1,1,1,1,1]);
                            data_handle.data(current_data).datainfo.(parameters)=val;
                            status=true;
                        case 'delta_dim'
                            val=max(str2num(val),[1,1,1]);
                            data_handle.data(current_data).datainfo.(parameters)=val;
                            status=true;
                        case 'percent_neighbour'
                            val=str2double(val); %#ok<*ST2NM>
                            val=min(100,max(val,1));% value between 1 and 100
                            data_handle.data(current_data).datainfo.(parameters)=val;
                            status=true;
                        case 'threshold'
                            val=str2double(val); %#ok<*ST2NM>
                            val=max(0.005,val);
                            data_handle.data(current_data).datainfo.(parameters)=val;
                            status=true;
                        otherwise
                            message=sprintf('%s\nUnauthorised to change %s.',message,parameters);
                            status=false;
                    end
                    if status
                        message=sprintf('%s\n%s has changed to %s.',message,parameters,num2str(val));
                    end
                end
            end
            % ---------------------
        case 'calculate_data'
            for current_data=data_idx
                parent_data=data_handle.data(current_data).datainfo.parent_data_idx;
                switch data_handle.data(parent_data).datatype
                    case {'DATA_IMAGE','RESULT_IMAGE'}
                        % get pixel binnin information
                        Cbin=data_handle.data(current_data).datainfo.rawdata_bin(1);
                        Xbin=data_handle.data(current_data).datainfo.rawdata_bin(2);
                        Ybin=data_handle.data(current_data).datainfo.rawdata_bin(3);
                        Zbin=data_handle.data(current_data).datainfo.rawdata_bin(4);
                        Tbin=data_handle.data(current_data).datainfo.rawdata_bin(5);
                        % binning
                        windowsize=[Cbin,Xbin,Ybin,Zbin,Tbin];
                        % do the smoothing
                        fval=convn(data_handle.data(parent_data).dataval(:,:,:,:,:),ones(windowsize),'same');
                        % get new data size
                        datasize=size(fval);
                        
                        nns=data_handle.data(current_data).datainfo.delta_dim;
                        midslice=ceil(((nns(3)*2)+1)/2);
                        threshold=data_handle.data(current_data).datainfo.threshold;
                        %pertagenn=ceil(data_handle.data(current_data).datainfo.percent_neighbour/100*(prod(nns(1:2)*2+1)-1));
                        pertagenn=(data_handle.data(current_data).datainfo.percent_neighbour/100);
                        logicimg=zeros(datasize);
                        kernel=ones([1,2*nns(1)+1,2*nns(2)+1,1,2*nns(3)+1]);
                        
                        %initialise waitbar
                        waitbar_handle = waitbar(0,'Please wait...','Progress Bar','Calculating...',...
                            'Name',cat(2,'Calculating ',parameters.operator,' for ',data_handle.data(current_data).dataname),...
                            'CreateCancelBtn',...
                            'setappdata(gcbf,''canceling'',1)',...
                            'WindowStyle','normal',...
                            'Color',[0.2,0.2,0.2]);
                        global SETTING; %#ok<TLEV>
                        javaFrame = get(waitbar_handle,'JavaFrame');
                        javaFrame.setFigureIcon(javax.swing.ImageIcon(cat(2,SETTING.rootpath.icon_path,'main_icon.png')));
                        setappdata(waitbar_handle,'canceling',0);
                        N_steps=datasize(5)-nns(3)*2-1;barstep=0;
                        
                        for Tidx=(1+nns(3)):(datasize(5)-nns(3))
                            % check waitbar
                            if getappdata(waitbar_handle,'canceling')
                                message=sprintf('%s\n%s calculation cancelled.',message,parameters.operator);
                                delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
                                return;
                            end
                            % Report current estimate in the waitbar's message field
                            done=Tidx/N_steps;
                            if floor(100*done)>=barstep
                                % update waitbar
                                waitbar(done,waitbar_handle,sprintf('%g%%',barstep));
                                barstep=barstep+1;
                            end
                            
                            blockimg=fval(1,1+nns(1):end-nns(1),1+nns(2):end-nns(2),1,Tidx-nns(3):Tidx+nns(3));
                            %{
                              figure(1);
                              subplot(2,3,1);imagesc(squeeze(blockimg(:,:,:,:,nns(3))));
                              subplot(2,3,2);imagesc(squeeze(blockimg(:,:,:,:,nns(3)+1)));
                              subplot(2,3,3);imagesc(squeeze(blockimg(:,:,:,:,nns(3)+2)));
                            %}
                            testimg=diff(blockimg,1,5);
                            %figure(1);subplot(2,3,4);imagesc(squeeze(sum(testimg,5)));
                            
                            bwimg=sign(testimg).*(abs(testimg)>=(mean(blockimg(:,:,:,:,:),5)*threshold));
                            bwimg=sum(convn(bwimg,kernel,'same'),5)/sum(kernel(:));
                            %figure(1);subplot(2,3,5);imagesc(squeeze(bwimg));
                            
                            logicimg(1,1+nns(1):end-nns(1),1+nns(2):end-nns(2),1,Tidx)=squeeze((bwimg>=pertagenn));
                            %figure(1);subplot(2,3,6);imagesc(squeeze(logicimg(1,:,:,1,Tidx)));
                        end
                        delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
                        
                        data_handle.data(current_data).dataval=logicimg;%.*data_handle.data(parent_data).dataval;
                        
                        data_handle.data(current_data).datainfo.dt=0;
                        data_handle.data(current_data).datainfo.t=0;
                        data_handle.data(current_data).datainfo.X=data_handle.data(parent_data).datainfo.X;
                        data_handle.data(current_data).datainfo.Y=data_handle.data(parent_data).datainfo.Y;
                        data_handle.data(current_data).datainfo.T=data_handle.data(parent_data).datainfo.T;
                        data_handle.data(current_data).datainfo.data_dim=size(data_handle.data(current_data).dataval);
                        data_handle.data(current_data).datainfo.display_dim=(size(data_handle.data(current_data).dataval)>1);
                        data_handle.data(current_data).datatype=data_handle.get_datatype(current_data);
                        data_handle.data(current_data).datainfo.last_change=datestr(now);
                        message=sprintf('%s\nData %s to %s %s calculated.',message,num2str(parent_data),num2str(current_data),parameters.operator);
                        status=true;
                    otherwise
                        
                end
            end
        otherwise
            
    end
catch exception
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
    message=sprintf('%s\n%s',message,exception.message);
end