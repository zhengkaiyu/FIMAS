function [ status, message ] = op_rt( data_handle, option, varargin )
%OP_RT calculate rotational anisotropy r(t) from parallel and perpendicular
%polarised intensity data
%
%=======================================
%options     values    explanation
%=======================================


%table contents must all have default values
parameters=struct('note','',...
    'operator','op_rt',...
    'op_func','@dF_Ffunc',...
    'op_arg','',...
    'background',[],...
    'T_baseline',[]);

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
                                data_handle.data_add(cat(2,'op_Arithmatic|',data_handle.data(current_data).dataname),[],[]);
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
                                data_handle.data(new_data).datainfo.parameter_space=regexp(parameters.op_func,'\w*(?=func)','match');
                                message=sprintf('%s%s added\n',message, data_handle.data(new_data).dataname);
                                status=true;
                            otherwise
                                message=sprintf('only take T, XT, XYT or XYZT data type\n',data_handle.data(current_data).dataname);
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
                    case 'op_func'
                        val=num2str(val);
                        data_handle.data(current_data).datainfo.op_func=val;
                        data_handle.data(current_data).datainfo.parameter_space=regexp(val,'\w*(?=func)','match');
                    case 'op_arg'
                        val=num2str(val);
                        data_handle.data(current_data).datainfo.op_arg=val;
                    case 'T_baseline'
                        
                    case 'background'
                        
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
            current_data=data_handle.current_data;
            parent_data=data_handle.data(current_data).datainfo.parent_data_idx;
            op=str2func(data_handle.data(current_data).datainfo.op_func);
            evalc(cat(2,'data_handle.data(current_data).dataval = op(data_handle.data(parent_data).dataval,));
            Fluo_bg=1;
            Ref_bg=1;
            T_baseline=(data_handle.data(parent_data).datainfo.T>=0)&(data_handle.data(parent_data).datainfo.T<=10);
            data_handle.data(current_data).dataval=op(data_handle.data(parent_data).dataval,...
                1,2,T_baseline,Fluo_bg,Ref_bg);
            data_handle.data(current_data).datainfo.T=data_handle.data(parent_data).datainfo.T;
            
            data_handle.data(current_data).datainfo.data_dim=size(data_handle.data(current_data).dataval);
            data_handle.data(current_data).datatype=data_handle.get_datatype(current_data);
            data_handle.data(current_data).datainfo.data_dim=size(data_handle.data(current_data).dataval);
            data_handle.data(current_data).datainfo.dt=1;
            data_handle.data(current_data).datainfo.t=0;
            
            %{
        data_handle.data(current_data).dataval=op(data_handle.data(data_handle.data(current_data).datainfo.input_list(1)).dataval);
        data_handle.data(current_data).datainfo.T=data_handle.data(data_handle.data(current_data).datainfo.input_list(1)).datainfo.T;
        
            %}
            message=sprintf('%s calculated on %s\n',data_handle.data(current_data).datainfo.op_func,data_handle.data(current_data).dataname);
            status=true;
        otherwise
            
    end
catch exception
    message=exception.message;
end
