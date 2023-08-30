function [ status, message ] = op_MapFunc( data_handle, option, varargin )
%OP_MAPFUNC converts input scalar value to output scalar value according to
%the function specified
%   1. calibration function in the fucntion libarary is inverse logistic x=x0*((a1-y)/(y-a2))^(1/p))
%
%   2. Mapping function of scalar to scalar
%
%---Batch process----------------------------------------------------------
%   Parameter=struct('selected_data','1','calib_func','@(x)128.54063*((0.06294-x)./(x-0.37057)).^(1/1.12492)','t_disp_bound','[0,200,128]','disp_lb','20','disp_ub','100','parameter_space','[Ca2+]');
%   selected_data=data index, 1 means previous generated data
%   calib_func='@(x)', calibration function used to map values
%   t_disp_bound=[0,200,128], display bound with [min,max,nlevels]
%   disp_lb=20, display value lower bound
%   disp_ub=100, display value upper bound
%   parameter_space='[Ca2+]', name for generated parameters 
%--------------------------------------------------------------------------
%   HEADER END
%--------------------------------------------------------------------------
% --- Function Library ---
%----------------------------------------------------------------------

%----LEICA SP8 FLIM confocal 9ns interval--------
%---OGB1---
%1det_37C: '@(x)112.26053.*((0.07608-x)./(x-0.37071)).^(1/1.14805)'
%---Cal590---
%1det 37C: '@(x)42.37263.*((0.10811-x)./(x-0.23606)).^(1/2.1904)'
%------- BH NCPCA test ------
%1det_32C: '@(x)121.58582.*((1.14801-x)./(x-11.02362)).^(1/1.3827)'
%------- BH 2ns NTC interval ------
%1det_19C: '@(x)151.91127.*((0.26097-x)./(x-0.78784)).^(1/1.09167)'
%1det_29C: '@(x)151.57067.*((0.25048-x)./(x-0.78664)).^(1/1.09806)'
%1det_32C: '@(x)150.79112.*((0.24551-x)./(x-0.78859)).^(1/1.08849)'
%------- BH 9ns NTC interval ------
%2det_19C: '@(x)136.49971.*((0.09783-x)./(x-0.39175)).^(1/1.10709)'
%1det_19C: '@(x)164.44795.*((0.06528-x)./(x-0.40378)).^(1/1.0953)'
%1det_32C: '@(x)165.63428.*((0.06433-x)./(x-0.39384)).^(1/1.09587)'
%------- PQ 9ns NTC interval ------
%1det_33C_9ns:
%'@(x)233.97304.*((0.07434-x)./(x-0.37527)).^(1/1.08896)'(ION)
%1det_33C_hg_NTC(5-11ns)
%'@(x)280.12795.*((0.00262-x)./(x-0.16096)).^(1/1.08213)'(ION)
%1det_33C_9ns:
%'@(x)181.39721.*((0.08885-x)./(x-0.38816)).^(1/1.25546)'(UCL)
%------- BH femtonics 9ns NTC interval ------
%1det_33C_UG_9ns: '@(x)128.54063*((0.06294-x)./(x-0.37057)).^(1/1.12492)'
%------------Olga T--------------------------
%------- BH femtonics 9ns NTC interval ------
%1det_34C_UG_9ns: '@(x)146.58*((0.09048-x)./(x-0.32)).^(1/1.03059)'
%1det_34C_UG_9ns: '@(x)139.06885*((0.08921-x)./(x-0.37016)).^(1/0.99636)'(KAI)
%----------------------------------------------------------------------
% --- OGB2 ---
%------- PQ 9ns NTC interval ------
%1det_32C_9ns: '@(x)335.85038.*((0.09304-x)./(x-0.34433)).^(1/1.08089)'
%----------------------------------------------------------------------
% --- Cal590 @910nm excitation ---
%------- BH femtonics 9ns NTC interval ------
%1det_33C_UR_9ns: '@(x)46.55257*((0.05829-x)./(x-0.2305)).^(1/1.88335)'
%------- BH femtonics 3ns NTC interval ------
%1det_33C_UR_3ns_bgcorr: '@(x)46.65768*((0.14742-x)./(x-0.53825)).^(1/1.95332)'
%--------------------------------------------
%


parameters=struct('note','',...
    'operator','op_MapFunc',...
    'parameter_space','[Ca2+]',...
    't_disp_bound',[0,200,128],...
    'disp_lb',20,...
    'disp_ub',100,...
    'calib_func','@(x)139.06885*((0.08921-x)./(x-0.37016)).^(1/0.99636)');

% assume worst
status=false;
% for batch process must return 'Data parentidx to childidx *' for each
% successful calculation
message='';
askforparam=true;
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
               case {'data_index','selected_data'}
                    % specified data indices
                    data_idx=usrval{option_idx};
                case 'batch_param'
                    % batch processing need to modify parameters to user
                    % specfication
                    op_MapFunc(data_handle, 'modify_parameters','data_index',data_idx,'paramarg',usrval{option_idx});
                case 'paramarg'
                    % batch processing passed on modified paramaters
                    varargin=usrval{option_idx};
                    
                    askforparam=false;
            end
        end
    end
    
    switch option
        case 'add_data'
            for current_data=data_idx
                switch data_handle.data(current_data).datatype
                    case {'DATA_IMAGE','DATA_TRACE','RESULT_IMAGE','RESULT_TRACE','RESULT_POINT'}
                        % check data dimension, we only take tXY, tXT, tT, tXYZ,
                        % tXYZT
                        switch bin2dec(num2str(data_handle.data(current_data).datainfo.data_dim>1))
                            case {0,1,9,12,13,14,15}
                                % point (00000) / T (00001) / XT (01001) / XY (01100) /
                                % XYT (01101) / XYZ (01110) / XYZT (01111)
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
                                % combine the parameter fields
                                data_handle.data(new_data).datainfo=setstructfields(data_handle.data(new_data).datainfo,parameters);%parameters field will replace duplicate field in data
                                data_handle.data(new_data).datainfo.parameter_space={'[Ca2+]'};
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
                            message=sprintf('%s\nUnauthorised to change %s',message,parameters);
                            status=false;
                        case 'disp_lb'
                            val=str2double(val);
                            if val>=data_handle.data(current_data).datainfo.disp_ub
                                message=sprintf('%s\ndisp_lb must be strictly < disp_ub',message);
                                status=false;
                            else
                                data_handle.data(current_data).datainfo.disp_lb=val;
                                status=true;
                            end
                        case 'disp_ub'
                            val=str2double(val);
                            if val<=data_handle.data(current_data).datainfo.disp_lb
                                message=sprintf('%s\ndisp_ub must be strictly > disp_up',message);
                                status=false;
                            else
                                data_handle.data(current_data).datainfo.disp_ub=val;
                                status=true;
                            end
                        case 'calib_func'
                            %check function format
                            if isempty(regexp(val,'@[(]x[)]\S*','match'))
                                %have no @(x)*x*
                                errordlg('function must be in the format @(x)f(x)');
                            else
                                data_handle.data(current_data).datainfo.calib_func=val;
                                status=true;
                            end
                        case 'parameter_space'
                            data_handle.data(current_data).datainfo.parameter_space=num2str(val);
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
                % go through each selected data
                parent_data=data_handle.data(current_data).datainfo.parent_data_idx;
                switch data_handle.data(parent_data).datatype
                    case {'DATA_IMAGE','DATA_TRACE','RESULT_IMAGE','RESULT_TRACE','RESULT_POINT'}%originated from 3D/4D traces_image
                        data=data_handle.data(parent_data).dataval;
                        if ~isempty(data)
                            calib_func=str2func(data_handle.data(current_data).datainfo.calib_func);
                            val=calib_func(data(:));
                            val(imag(val)~=0)=nan;%rid of imaginary
                            val(isinf(val))=nan;%rid of infinity
                            val=reshape(val,size(data));
                            data_handle.data(current_data).dataval=val;
                            data_handle.data(current_data).datatype=data_handle.get_datatype;
                            data_handle.data(current_data).datainfo.last_change=datestr(now);
                            message=sprintf('%s\nData %s to %s %s calculated.',message,num2str(parent_data),num2str(current_data),parameters.operator);
                            status=true;
                        else
                            fprintf('Calculate Parent Data first\n');
                        end
                end
            end
    end
catch exception
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
    message=sprintf('%s\n%s',message,exception.message);
end