function [ status, message ] = op_dF_R( data_handle, option, varargin )
%op_dF_R calculate delta fluorescence over reference channel (dG/R)
%
%=======================================
%options     values    explanation
%=======================================


%table contents must all have default values
parameters=struct('note','',...
    'operator','op_dF_R',...
    'F_CH',1,...
    'R_CH',2,...
    'f0_t_int',[20,100],...
    'bg_t_int',[0,20],...
    'windowspan',0.01,...
    'basespan',0.01);

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
                    case {'DATA_IMAGE','DATA_TRACE'}
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
                                data_handle.data_add(cat(2,'op_dF_R|',data_handle.data(current_data).dataname),[],[]);
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
                                data_handle.data(new_data).datainfo.bin_dim=data_handle.data(current_data).datainfo.bin_dim;
                                if isempty(data_handle.data(new_data).datainfo.bin_dim)
                                    data_handle.data(new_data).datainfo.bin_dim=[1,1,1,1,1];
                                end
                                message=sprintf('%s%s added\n',message, data_handle.data(new_data).dataname);
                                status=true;
                            otherwise
                                message=sprintf('only take T, XT, XYT or XYZT data type\n');
                        end
                end
            end
            % ---------------------
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
                    case 'operator'
                        message=sprintf('%sUnauthorised to change %s\n',message,parameters);
                        status=false;
                    case {'windowspan','basespan','F_CH','R_CH','f0_t_int','bg_t_int'}
                        val=str2num(val);
                        data_handle.data(current_data).datainfo.(parameters)=val;
                        status=true;
                    otherwise
                        message=sprintf('%sUnauthorised to change %s\n',message,parameters);
                        status=false;
                end
                if status
                    message=sprintf('%s%s has changed to %s\n',message,parameters,val);
                end
            end
            % ---------------------
        case 'calculate_data'
            askforparam=true;
            for current_data=data_idx
                parent_data=data_handle.data(current_data).datainfo.parent_data_idx;
                switch data_handle.data(parent_data).datatype
                    case 'DATA_IMAGE'
                        % get pixel binnin information
                        pX_lim=numel(data_handle.data(parent_data).datainfo.X);
                        pY_lim=numel(data_handle.data(parent_data).datainfo.Y);
                        pZ_lim=numel(data_handle.data(parent_data).datainfo.Z);
                        pT_lim=numel(data_handle.data(parent_data).datainfo.T);
                        Xbin=data_handle.data(current_data).datainfo.bin_dim(2);
                        Ybin=data_handle.data(current_data).datainfo.bin_dim(3);
                        Zbin=data_handle.data(current_data).datainfo.bin_dim(4);
                        Tbin=data_handle.data(current_data).datainfo.bin_dim(5);
                        % binning
                        windowsize=[1,Xbin,Ybin,Zbin,Tbin];
                        fval=data_handle.data(parent_data).dataval([data_handle.data(current_data).datainfo.F_CH,data_handle.data(current_data).datainfo.R_CH],:,:,:,:);
                        fval=convn(fval,ones(windowsize),'same');
                        datasize=[2,data_handle.data(parent_data).datainfo.data_dim(2:end)];
                        % reshape to CST
                        temp=reshape(fval,[datasize(1),prod(datasize(2:4)),datasize(5)]);
                        % calculate background for each channel in each
                        T_int=(data_handle.data(parent_data).datainfo.T>=data_handle.data(current_data).datainfo.bg_t_int(1)&data_handle.data(parent_data).datainfo.T<=data_handle.data(current_data).datainfo.bg_t_int(2));
                        % time frame
                        if isempty(find(T_int))
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
                        message=sprintf('%s%s calculated on %s\n',message,data_handle.data(current_data).datainfo.operator,data_handle.data(current_data).dataname);
                    case 'DATA_TRACE'
                        datasize=[2,data_handle.data(parent_data).datainfo.data_dim(2:end)];
                        % binning
                        Xbin=data_handle.data(current_data).datainfo.bin_dim(2);
                        Ybin=data_handle.data(current_data).datainfo.bin_dim(3);
                        Zbin=data_handle.data(current_data).datainfo.bin_dim(4);
                        Tbin=data_handle.data(current_data).datainfo.bin_dim(5);
                        windowsize=[1,Xbin,Ybin,Zbin,Tbin];
                        fval=data_handle.data(parent_data).dataval([data_handle.data(current_data).datainfo.F_CH,data_handle.data(current_data).datainfo.R_CH],:,:,:,:);
                        fval=convn(fval,ones(windowsize),'same');
                        % calculate background for each channel in each
                        T_int=(data_handle.data(parent_data).datainfo.T>=data_handle.data(current_data).datainfo.bg_t_int(1)&data_handle.data(parent_data).datainfo.T<=data_handle.data(current_data).datainfo.bg_t_int(2));
                        % time frame
                        if isempty(find(T_int))
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
                        message=sprintf('%s%s calculated on %s\n',message,data_handle.data(current_data).datainfo.operator,data_handle.data(current_data).dataname);
                end
            end
            status=true;
        otherwise
    end
catch exception
    message=exception.message;
end