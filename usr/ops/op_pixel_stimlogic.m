function [ status, message ] = op_pixel_stimlogic( data_handle, option, varargin )
%op_dF_R calculate delta fluorescence over reference channel (dG/R)
%--------------------------------------------------------------------------
%=======================================
%options     values    explanation
%---Batch process----------------------------------------------------------
%   Parameter=struct('selected_data','1','bin_dim','[1,1,1,1,1]','F_CH','1','R_CH','1','f0_t_int','[20,100]','bg_t_int','[0,20]','R_bin','[1,1,1,1,10]','parameter_space','df/f0');
%   selected_data=data index, 1 means previous generated data
%   F_CH=1, functional channel, usually channel 1
%   R_CH=1, reference channel,usually channel 2
%   f0_t_int=[20,100],time interval for the f0 value in df/f0
%   bg_t_int=[0,20],time interval for the background values
%   R_bin=[1,1,1,1,10],1x5vector specify binning for each dimension,binning for the reference signal
%   parameter_space='df/f0', name for generated parameters
%--------------------------------------------------------------------------
%   HEADER END

%table contents must all have default values
parameters=struct('note','',...
    'operator','op_pixel_stimlogic',...
    'parameter_space','stim1|stim2|stim3|stim4|stim5',...
    'bin_dim',[1,1,1,1,1],...
    'stim_t_int',[100,100,100,100,100],...
    'baseline_t_int',[0,300],...
    'R_bin',[1,1,1,1,1]);

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
                    op_dF_R(data_handle, 'modify_parameters','data_index',data_idx,'paramarg',usrval{option_idx});
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
                        % check data dimension, we only take CT, CXT, CXYT,
                        % CXYZT, where C=channel locates in t dimension
                        switch bin2dec(num2str(data_handle.data(current_data).datainfo.data_dim>1))
                            case {17,25,29,31,1,9,13,15}
                                % multi detector channels
                                % tT (10001) / tXT (11001) / tXYT (11101) / tXYZT (11111)
                                % single detector channel
                                % T (00001) / XT (01001) / XYT (01101) / XYZT (01111)
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
                                data_handle.data(new_data).datainfo.parameter_space={'NTC'};
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
                                message=sprintf('%s\nonly take XT or XYT data type.',message);
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
                        case 'bin_dim'
                            [status,~]=data_handle.edit_datainfo(current_data,'bin_dim',val);
                        case {'R_bin','F_CH','R_CH','f0_t_int','bg_t_int'}
                            val=str2num(val); %#ok<*ST2NM>
                            data_handle.data(current_data).datainfo.(parameters)=val;
                            status=true;
                        otherwise
                            message=sprintf('%s\nUnauthorised to change %s.',message,parameters);
                            status=false;
                    end
                    if status
                        message=sprintf('%s\n%s has changed to %s.',message,parameters,val);
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
                        Xbin=data_handle.data(current_data).datainfo.bin_dim(2);
                        Ybin=data_handle.data(current_data).datainfo.bin_dim(3);
                        Zbin=data_handle.data(current_data).datainfo.bin_dim(4);
                        Tbin=data_handle.data(current_data).datainfo.bin_dim(5);
                        % binning
                        windowsize=[1,Xbin,Ybin,Zbin,Tbin];
                        fval=data_handle.data(parent_data).dataval([data_handle.data(current_data).datainfo.F_CH,data_handle.data(current_data).datainfo.R_CH],:,:,:,:);
                        fval(1,:,:,:,:)=convn(fval(1,:,:,:,:),ones(windowsize),'same');
                        windowsize=data_handle.data(current_data).datainfo.R_bin;
                        fval(2,:,:,:,:)=convn(fval(2,:,:,:,:),ones(windowsize),'same');
                        datasize=[2,data_handle.data(parent_data).datainfo.data_dim(2:end)];
                        % reshape to CST
                        temp=reshape(fval,[datasize(1),prod(datasize(2:4)),datasize(5)]);
                        % calculate background for each channel in each
                        T_int=(data_handle.data(parent_data).datainfo.T>=data_handle.data(current_data).datainfo.bg_t_int(1)&data_handle.data(parent_data).datainfo.T<=data_handle.data(current_data).datainfo.bg_t_int(2));
                        % time frame
                        if isempty(find(T_int, 1))
                            bg_val=zeros(2,1);
                        else
                            bg_val=nanmean(nanmean(temp(:,:,T_int),3),2);
                        end
                        temp=bsxfun(@minus,temp,bg_val);%background subtraction
                        T_int=(data_handle.data(parent_data).datainfo.T>=data_handle.data(current_data).datainfo.f0_t_int(1)&data_handle.data(parent_data).datainfo.T<=data_handle.data(current_data).datainfo.f0_t_int(2));
                        % time frame
                        f0_val=nanmean(temp(1,:,T_int),3);
                        if data_handle.data(current_data).datainfo.F_CH==data_handle.data(current_data).datainfo.R_CH
                            % dF/F
                            temp=bsxfun(@rdivide,temp(1,:,:),f0_val)-1;
                        else
                            % calculation dF/R
                            temp(1,:,:)=bsxfun(@minus,temp(1,:,:),f0_val);
                            temp=temp(1,:,:)./temp(2,:,:);
                        end
                        % reshape to ST
                        temp=reshape(temp,[prod(datasize(2:4)),datasize(5)]);
                        
                        data_handle.data(current_data).dataval=reshape(temp,[1,datasize(2),datasize(3),datasize(4),datasize(5)]);
                        
                        data_handle.data(current_data).datainfo.dt=0;
                        data_handle.data(current_data).datainfo.t=0;
                        data_handle.data(current_data).datainfo.T=data_handle.data(parent_data).datainfo.T;
                        data_handle.data(current_data).datainfo.data_dim=size(data_handle.data(current_data).dataval);
                        data_handle.data(current_data).datainfo.display_dim=(size(data_handle.data(current_data).dataval)>1);
                        data_handle.data(current_data).datatype=data_handle.get_datatype(current_data);
                        data_handle.data(current_data).datainfo.last_change=datestr(now);
                        message=sprintf('%s\nData %s to %s %s calculated.',message,num2str(parent_data),num2str(current_data),parameters.operator);
                        status=true;
                    case {'DATA_TRACE','RESULT_TRACE'}
                        datasize=[2,data_handle.data(parent_data).datainfo.data_dim(2:end)];
                        % binning
                        Xbin=data_handle.data(current_data).datainfo.bin_dim(2);
                        Ybin=data_handle.data(current_data).datainfo.bin_dim(3);
                        Zbin=data_handle.data(current_data).datainfo.bin_dim(4);
                        Tbin=data_handle.data(current_data).datainfo.bin_dim(5);
                        % binning
                        windowsize=[1,Xbin,Ybin,Zbin,Tbin];
                        fval=data_handle.data(parent_data).dataval([data_handle.data(current_data).datainfo.F_CH,data_handle.data(current_data).datainfo.R_CH],:,:,:,:);
                        fval(1,:,:,:,:)=convn(fval(1,:,:,:,:),ones(windowsize),'same');
                        windowsize=data_handle.data(current_data).datainfo.R_bin;
                        fval(2,:,:,:,:)=convn(fval(2,:,:,:,:),ones(windowsize),'same');
                        % calculate background for each channel in each
                        T_int=(data_handle.data(parent_data).datainfo.T>=data_handle.data(current_data).datainfo.bg_t_int(1)&data_handle.data(parent_data).datainfo.T<=data_handle.data(current_data).datainfo.bg_t_int(2));
                        % time frame
                        if isempty(find(T_int, 1))
                            bg_val=zeros(2,1);
                        else
                            bg_val=nanmean(nanmean(fval(:,:,T_int),3),2);
                        end
                        fval=bsxfun(@minus,fval,bg_val);%background subtraction
                        T_int=(data_handle.data(parent_data).datainfo.T>=data_handle.data(current_data).datainfo.f0_t_int(1)&data_handle.data(parent_data).datainfo.T<=data_handle.data(current_data).datainfo.f0_t_int(2));
                        % time frame
                        f0_val=nanmean(fval(1,:,T_int),3);
                        if data_handle.data(current_data).datainfo.F_CH==data_handle.data(current_data).datainfo.R_CH
                            % dF/F
                            fval=bsxfun(@rdivide,fval(1,:,:),f0_val)-1;
                        else
                            % calculation dF/R
                            fval(1,:,:)=bsxfun(@minus,fval(1,:,:),f0_val);
                            fval=fval(1,:,:)./fval(2,:,:);
                        end
                        % reshape to ST
                        fval=reshape(fval,[prod(datasize(2:4)),datasize(5)]);
                        
                        data_handle.data(current_data).dataval=reshape(fval,[1,datasize(2),datasize(3),datasize(4),datasize(5)]);
                        
                        data_handle.data(current_data).datainfo.dt=0;
                        data_handle.data(current_data).datainfo.t=0;
                        data_handle.data(current_data).datainfo.T=data_handle.data(parent_data).datainfo.T;
                        data_handle.data(current_data).datainfo.data_dim=size(data_handle.data(current_data).dataval);
                        data_handle.data(current_data).datainfo.display_dim=(size(data_handle.data(current_data).dataval)>1);
                        data_handle.data(current_data).datatype=data_handle.get_datatype(current_data);
                        data_handle.data(current_data).datainfo.last_change=datestr(now);
                        message=sprintf('%s\nData %s to %s %s calculated.',message,num2str(parent_data),num2str(current_data),parameters.operator);
                        status=true;
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