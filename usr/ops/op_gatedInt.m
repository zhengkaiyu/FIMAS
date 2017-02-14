function [ status, message ] = op_gatedInt( data_handle, option, varargin )
%op_gatedInt Calculate Normalised Total Count from traces or images by
%gate2/gate1 values.  This can be used for
%

parameters=struct('note','',...
    'operator','op_gatedInt',...
    'parameter_space','gInt',...
    'gate1',[0,1],...
    'gate2',[5,10],...
    'normalise',0); %background threshold

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
                    case {'DATA_IMAGE'}
                        % check data dimension, we only take tXY, tXT, tT, tXYZ,
                        % tXYZT
                        switch bin2dec(num2str(data_handle.data(current_data).datainfo.data_dim>1))
                            case {17,25,28,29,30,31}
                                % tT (10001) / tXT (11001) / tXY (11100) /
                                % tXYT (11101) / tXYZ (11110) / tXYZT (11111)
                                parent_data=current_data;
                                % add new data
                                data_handle.data_add(cat(2,'op_gatedInt|',data_handle.data(current_data).dataname),[],[]);
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
                    case 'operator'
                        message=sprintf('%sUnauthorised to change %s\n',message,parameters);
                        status=false;
                    case 'gate1'
                        val=str2num(val);
                        if numel(val)~=2
                            message=sprintf('%s\ngate1 must have two elements.\n',message);
                            status=false;
                        else
                            data_handle.data(current_data).datainfo.gate1=val;
                            status=true;
                        end
                    case 'gate2'
                        val=str2num(val);
                        if numel(val)~=2
                            message=sprintf('%s\ngate2 must have two elements.\n',message);
                            status=false;
                        else
                            data_handle.data(current_data).datainfo.gate2=val;
                            status=true;
                        end
                    case 'normalise'
                        if str2double(val)
                            data_handle.data(current_data).datainfo.normalise=true;
                        else
                            data_handle.data(current_data).datainfo.normalise=false;
                        end
                        status=true;
                    case 'parameter_space'
                        data_handle.data(current_data).datainfo.parameter_space=val;
                        status=true;
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
                        
                        % get dt dimension information
                        t=data_handle.data(parent_data).datainfo.t;
                        
                        if data_handle.data(current_data).datainfo.normalise
                            I=nansum(data_handle.data(parent_data).dataval(1:end,:),2);%get max position from total data
                            [~,max_idx]=max(I);% get max position
                        else
                            max_idx=[];
                        end
                        windowsize=[Xbin,Ybin,Zbin,Tbin];
                        % get gate range
                        t_gate1=(t>=data_handle.data(current_data).datainfo.gate1(1))&(t<=data_handle.data(current_data).datainfo.gate1(2));
                        t_gate2=(t>=data_handle.data(current_data).datainfo.gate2(1))&(t<=data_handle.data(current_data).datainfo.gate2(2));
                        
                        fval=convn(data_handle.data(parent_data).dataval,ones(windowsize),'same');
                        fval=calculate_gateratio(fval,t_gate1,t_gate2,data_handle.data(current_data).datainfo.normalise,max_idx);
                        
                        data_handle.data(current_data).dataval=reshape(fval(1,:),[1,pX_lim,pY_lim,pZ_lim,pT_lim]);
                        data_handle.data(current_data).datainfo.data_dim=[1,pX_lim,pY_lim,pZ_lim,pT_lim];
                        data_handle.data(current_data).datatype=data_handle.get_datatype(current_data);
                        data_handle.data(current_data).datainfo.dt=0;
                        data_handle.data(current_data).datainfo.t=0;
                        
                        data_handle.data(current_data).datainfo.last_change=datestr(now);
                        status=true;
                    case {'DATA_TRACE'}
                        t=data_handle.data(current_data).datainfo.t;
                        % get gate range
                        t_gate1=(t>=data_handle.data(current_data).datainfo.gate1(1))&(t<=data_handle.data(current_data).datainfo.gate1(2));
                        t_gate2=(t>=data_handle.data(current_data).datainfo.gate2(1))&(t<=data_handle.data(current_data).datainfo.gate2(2));
                        if data_handle.data(current_data).datainfo.normalise
                            I=nansum(data_handle.data(parent_data).dataval(1:end,:),2);%get max position from total data
                            [~,max_idx]=max(I);% get max position
                        else
                            max_idx=[];
                        end
                        fval=calculate_gateratio(data_handle.data(parent_data).dataval,t_gate1,t_gate2,data_handle.data(current_data).datainfo.normalise,max_idx);
                        data_handle.update_data('dataval',fval);
                        data_handle.data(current_data).datatype=data_handle.get_datatype(current_data);
                        data_handle.data(current_data).datainfo.dt=0;
                        data_handle.data(current_data).datainfo.t=0;
                        data_handle.data(current_data).datainfo.last_change=datestr(now);
                        message=sprintf('NTC = %g\n',fval);
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

    function val=calculate_gateratio(data,gate1,gate2,normalise,maxidx)
        if normalise
            data=data./data(maxidx);
        end
        %calculate area
        val=nanmean(data(gate2,:,:,:,:),1)./nanmean(data(gate1,:,:,:,:),1);
        val(isinf(val))=nan;
    end
end