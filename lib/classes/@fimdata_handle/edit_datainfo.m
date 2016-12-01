function [ status, message ] = edit_datainfo( obj, data_idx, which_field, val )
%EDIT_DATAINFO changes made to datainfo fields
%   User alteration of data info
%Usage:
%   obj.edit_datainfo(data index,field name, new value);

%% function complete
status=false;message='';
%#ok<*ST2NM>
try
    switch which_field
        % --- base fields cannot be changed ---
        case 'dataval'
            errordlg('Unable to change.  dataval is not open to arbitrary changes','Error','modal');
        case 'metainfo'
            errordlg('Unable to change.  metainfo comes from raw data file.','Error','modal');
        case {'datainfo','roi'}
            errordlg(sprintf('Unable to change.  %s is structured variable.',which_field),'Error','modal');
        case 'current_roi'
            errordlg('unable to change.  use LIST_ROI to select roi.','Error','modal');
            
            % --- base fields need checking ---
        case 'dataname'
            obj.data(data_idx).dataname=num2str(val);%copy over text
            status=true;
        case 'datatype'
            val=num2str(val);
            if strmatch(val,obj.DATA_TYPE,'exact')
                % if we found the inputted type
                obj.data(data_idx).datatype=val;
                status=true;
            else
                % some user input error show options
                [type,button] = listdlg('PromptString','Select correct datatype:',...
                    'SelectionMode','single',...
                    'ListString',obj.DATA_TYPE,...
                    'OKString','Select');
                if button
                    obj.data(data_idx).datatype=obj.DATA_TYPE{type};
                    status=true;
                else
                    message=sprintf('Data type change cancelled\n');
                end
            end
            
            % --- datainfo fields cannot be changed---
        case {'data_idx'}
            errordlg('Unable to change.  data_idx is generated automatically','Error','modal');
        case {'t','X','Y','Z','T'}
            errordlg(sprintf('Unable to change %s.\n Consider change d%s for scaling.',which_field,which_field),'Error','modal');
        case 'operator'
            errordlg('Unable to change.  data_idx is generated automatically','Error','modal');
        case 'panel'
            errordlg('Unable to change.  panel is predefined','Error','modal');
        case 'last_change'
            errordlg('Unable to change.  last_change time is generated automatically','Error','modal');
        case 'data_dim'
            errordlg('Unable to change.  data_dim is generated automatically','Error','modal');
            
            % --- datainfo fields need checking
        case {'parent_data_idx','child_data_idx'}
            val=str2num(val);% convert to number
            if isempty(val)
                obj.data(data_idx).datainfo.(which_field)=[];
            else
                if (val>1) && val<=numel(obj.data) && (val~=data_idx)
                    % index is between 2 and maximum data item number excluding
                    % the data itself
                    obj.data(data_idx).datainfo.(which_field)=val;
                    status=true;
                else
                    errordlg(sprintf('%s is invalid, check your input.',which_field),'Error','modal');
                end
            end
        case 'note'
            obj.data(data_idx).datainfo.note=num2str(val);
            status=true;
        case 'T_acquisition'
            val=str2num(val);
            if val>0
                obj.data(data_idx).datainfo.T_acquisition=val;
                status=true;
            else
                errordlg('acquisition time has to be greater than zero.','Error','modal');
            end
        case {'dt','dX','dY','dZ','dT'}
            val=str2num(val);
            if numel(val)==1
                obj.data(data_idx).datainfo.(which_field)=val;
                startval=obj.data(data_idx).datainfo.(which_field(2))(1);
                dim_idx=strfind(char(obj.DIM_TAG)',which_field(2));
                endval=startval+val*(obj.data(data_idx).datainfo.data_dim(dim_idx)-1);
                obj.data(data_idx).datainfo.(which_field(2))=startval:val:endval;
                status=true;
            else
                errordlg('singleton value has to be greater than 0!');
            end
        case 'bin_dim'
            val=str2num(val);
            if isempty(val)
                obj.data(data_idx).datainfo.bin_dim=[];
            else
                % make sure no negative bin numbers
                val=max(val,ones(size(val)));
                if numel(val)==5
                    obj.data(data_idx).datainfo.bin_dim=val;
                    status=true;
                else
                    errordlg('bin_dim must specified for all 5 tXYZT dimensions.','Error','modal');
                end
            end
        case 'display_dim'
            val=str2num(val);
            if numel(val)==5
                % make sure display only existing data dims
                val=and(val,obj.data(data_idx).datainfo.data_dim-1);
                obj.data(data_idx).datainfo.display_dim=val;
                status=true;
            else
                errordlg('bin_dim must specified for all 5 tXYZT dimensions.','Error','modal');
            end
        case {'t_disp_bound','X_disp_bound','Y_disp_bound','Z_disp_bound','T_disp_bound'}
            val=str2num(val);
            if numel(val)==3
                val(3)=max(val(3),2);%minimum 2 levels black/white
                val(3)=min(val(3),256);%maximum 256 levels
                obj.data(data_idx).datainfo.(which_field)=val;
                status=true;
            else
                errordlg('display bound must be vector of length 3, [min,max,levels]','Error','modal');
            end
        case {'optical_zoom','digital_zoom'}
            val=max(1,str2num(val));%must be greater than or equal to 1
            obj.data(data_idx).datainfo.(which_field)=val;
            if isempty(obj.data(data_idx).datainfo.scale_func)
                errordlg('Please input a valid scale function first.','Error','modal');
            else
                scale_func=str2func(obj.data(data_idx).datainfo.scale_func);
                % get scaling from scale_func
                scaling=scale_func(obj.data(data_idx).datainfo.optical_zoom,obj.data(data_idx).datainfo.digital_zoom);
                % need to recalculate data X and Y scale
                obj.data(data_idx).datainfo.dX=scaling;
                obj.data(data_idx).datainfo.dY=scaling;
                X_scale=scaling*obj.data(data_idx).datainfo.data_dim(2);
                Y_scale=scaling*obj.data(data_idx).datainfo.data_dim(3);
                obj.data(data_idx).datainfo.X=linspace(0,1,obj.data(data_idx).datainfo.data_dim(2))'*X_scale;
                obj.data(data_idx).datainfo.Y=linspace(0,1,obj.data(data_idx).datainfo.data_dim(3))'*Y_scale;
                status=true;
            end
        case {'mag_factor'}
            obj.data(data_idx).datainfo.scale_func=max(str2num(val),1);
            status=true;
        case {'scale_func'}
            helpdlg({'linear fitting y=a*x+c, y is the scaling factor ','default @(op_zoom,dig_zoom)(1.7505*op_zoom-10.018)*op_zoom/dig_zoom/256'},'Magnification Fitting Function explained');
            obj.data(data_idx).datainfo.scale_func=num2str(val);
            status=true;
            
            % --- Possible userop addition fields ---
        otherwise
            % check if operator is used, if so pass argument onto userop
            % functions
            if ~isempty(obj.data(data_idx).datainfo.operator)
                %user function must have input
                %(DATA structure for I/O, data/analysis parameter table handle,options)
                %user function must have output
                %[result]; message is all the command output from the user function
                store_idx=obj.current_data;% store the current data idx temporarily
                obj.current_data=data_idx;
                [message, ~] = evalc(cat(2,obj.data(data_idx).datainfo.operator,'(obj,''modify_parameters'',which_field,val)'));
                obj.current_data=store_idx;% restore the current data idx
            else
                errordlg('Unable to change.  Contact Author for more information.');
            end
    end
catch exception
    errordlg({'Unable to change',...
        exception.message,...
        cat(2,'Filename: ',exception.stack(1).file),...
        cat(2,'Line num: ',num2str(exception.stack(1).line)),...
        cat(2,'Function: ',exception.stack(1).name)});
end