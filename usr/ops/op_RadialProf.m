function [ status, message ] = op_RadialProf( data_handle, option, varargin )
%OP_RADIALPROF Calculate profile of analysis data parameter w.r.t. r
%--------------------------------------------------------------------------
%   op_RadialProf( data_handle, option, varargin )
%   Use fhROI, pROI or all of image with the initial point (fhROI,pROI) or
%   center of the image as the origin (r=0) and radial distribution will be
%   calculated and plotted for all data within the roi or the whole image
%   in the case of ALL or pROI
%---Batch process----------------------------------------------------------
%   Parameter=struct('selected_data','1','dr','1','val_lb','3e-10','val_ub','1000');
%   selected_data=data index, 1 means previous generated data
%   dr=1, 1 means pixel size
%   val_lb=0, lower bound value to accept
%   val_ub=0, upper bound value to accept
%--------------------------------------------------------------------------
%   HEADER END

parameters=struct('note','',...
    'operator','op_RadialProf',...
    'dr',1,...      %dr in number of pixels
    'val_lb',0,...
    'val_ub',1000);

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
                    op_RadialProf(data_handle, 'modify_parameters','data_index',data_idx,'paramarg',usrval{option_idx});
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
                    case {'DATA_IMAGE','RESULT_IMAGE'}
                        % check data dimension, we only take XY, XYT, XYZ, XYZT,
                        % tXY, tXYT, tXYZ, tXYZT
                        switch bin2dec(num2str(data_handle.data(current_data).datainfo.data_dim>1))
                            case {12,28,13,29,14,30,15,31}
                                % XY (01100) / tXY (11100)
                                % XYT (01101) / tXYT (11101)
                                % XYZ (01110) / tXYZ (11110)
                                % XYZT (01111) / tXYZT (11111)
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
                                data_handle.data(new_data).datainfo.bin_dim=data_handle.data(parent_data).datainfo.bin_dim;
                                if isempty(data_handle.data(new_data).datainfo.bin_dim)
                                    data_handle.data(new_data).datainfo.bin_dim=[1,1,1,1,1];
                                end
                                % pass on metadata info
                                data_handle.data(new_data).metainfo=data_handle.data(parent_data).metainfo;
                                message=sprintf('%s\nData %s to %s added.',message,num2str(parent_data),num2str(new_data));
                                status=true;
                            otherwise
                                message=sprintf('only take XY, XYT, XYZ, XYZT, tXY, tXYT, tXYZ, tXYZT data type\n');
                                return;
                        end
                end
            end
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
                            errordlg('Unauthorised to change parameter');
                            status=false;
                        case 'val_lb'
                            val=str2double(val);
                            if val>=data_handle.data(current_data).datainfo.val_ub
                                fprintf('val_lb must be strictly < val_ub\n');
                            else
                                data_handle.data(current_data).datainfo.val_lb=val;
                            end
                        case 'val_ub'
                            val=str2double(val);
                            if val<=data_handle.data(current_data).datainfo.val_lb
                                fprintf('val_ub must be strictly > val_lb\n');
                            else
                                data_handle.data(current_data).datainfo.val_ub=val;
                                status=true;
                            end
                        case 'dr'
                            val=str2double(val);
                            val=max(val,0.005);
                            data_handle.data(current_data).datainfo.dr=val;
                            status=true;
                    end
                    if status
                        message=sprintf('%s%s has changed to %s\n',message,parameters,val);
                    end
                end
            end
        case 'calculate_data'
            for current_data=data_idx
                % go through each selected data
                parent_data=data_handle.data(current_data).datainfo.parent_data_idx;
                current_roi=data_handle.data(parent_data).current_roi(1);%only take one ROI
                data=squeeze(data_handle.data(parent_data).dataval);
                roi=data_handle.data(parent_data).roi(current_roi);

                [r,v,centerval]=calculate_rprofile( data, data_handle.data(parent_data).datainfo, data_handle.data(current_data).datainfo, roi );
                %message=sprintf('%s\n MaxVal=%f \t Xc=%f \t Yc=%f.',message,centerval(1),centerval(2),centerval(3));
                data_handle.data(current_data).dataval=v;
                data_handle.data(current_data).datainfo.X=r;
                data_handle.data(current_data).datainfo.dX=r(2)-r(1);
                data_handle.data(current_data).datainfo.data_dim=[1,numel(v),1,1,1];
                data_handle.data(current_data).datatype=data_handle.get_datatype(current_data);
                data_handle.data(current_data).datainfo.last_change=datestr(now);

                message=sprintf('%s\nData %s to %s %s calculated.',message,num2str(parent_data),num2str(current_data),parameters.operator);
                status=true;
            end
    end
catch exception
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
    message=sprintf('%s\n%s',message,exception.message);
end