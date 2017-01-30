function [ status, message ] = op_Spiral2Img( data_handle, option, varargin )
%op_Spiral2Img converts spiral/tornado linescan into standard images
% --- Function Library ---

parameters=struct('note','',...
    'operator','op_Spiral2Img',...
    'disp_lb',20,...
    'disp_ub',100);

status=[];message='';

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
                    case {'RESULT_IMAGE'}
                        % check data dimension, we only take tXT
                        switch bin2dec(num2str(data_handle.data(current_data).datainfo.data_dim>1))
                            case {25}
                               %tXT (11001)
                                parent_data=current_data;
                                % add new data
                                data_handle.data_add(cat(2,'op_Spiral2Img|',data_handle.data(current_data).dataname),[],[]);
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
                                message=sprintf('%s added\n',data_handle.data(new_data).dataname);
                                status=true;
                            otherwise
                                message=sprintf('only take XT or XYT data type\n');
                                return;
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
                    case 'disp_lb'
                        val=str2double(val);
                        if val>=data_handle.data(current_data).datainfo.disp_ub;
                            message=sprintf('disp_lb must be strictly < disp_ub\n');
                            status=false;
                        else
                            data_handle.data(current_data).datainfo.disp_lb=val;
                            status=true;
                        end
                    case 'disp_ub'
                        val=str2double(val);
                        if val<=data_handle.data(current_data).datainfo.disp_lb;
                            message=sprintf('disp_ub must be strictly > disp_up\n');
                            status=false;
                        else
                            data_handle.data(current_data).datainfo.disp_ub=val;
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
            % ---------------------
        case 'calculate_data'
            for current_data=data_idx
                % go through each selected data
                parent_data=data_handle.data(current_data).datainfo.parent_data_idx;
                switch data_handle.data(parent_data).datatype
                    case {'RESULT_IMAGE'}%originated from 3D/4D traces_image
                        data=data_handle.data(parent_data).dataval;
                        if ~isempty(data)
                            calib_func=str2func(data_handle.data(current_data).datainfo.calib_func);
                            val=calib_func(data(:));
                            val(imag(val)~=0)=nan;%rid of imaginary
                            val(isinf(val))=nan;%rid of infinity
                            val=reshape(val,size(data));
                            data_handle.data(current_data).dataval=val;
                            data_handle.data(current_data).datatype=data_handle.get_datatype;
                            status=true;
                        else
                            fprintf('Calculate Parent Data first\n');
                        end
                end
            end
    end
catch exception
    message=exception.message;
end

