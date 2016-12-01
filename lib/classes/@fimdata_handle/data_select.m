function [ message ] = data_select(obj, data_idx )
%data_select update roi list, file info table and parameter table to the
%selected data according to data_idx
%select_data(obj,data_idx);

%% function check
try
    %------------------------------------
    %get current roi and switch them off
    num_roi=numel(obj.data(obj.current_data).roi);
    
    for m=2:num_roi
        %remove old roi handles
        if isvalid(obj.data(obj.current_data).roi(m).handle)
            set(obj.data(obj.current_data).roi(m).handle,'Visible','off');
        end
    end
    
    %------------------------------------
    %update current data index
    obj.current_data=data_idx;
    
    %------------------------------------

    switch obj.data(data_idx).datatype
        case {'DATA_POINT','RESULT_POINT'}
            message=sprintf('%s selected\n\nval=%f\n',obj.data(data_idx).dataname,obj.data(data_idx).dataval);
        otherwise
            message=sprintf('%s selected\n',obj.data(data_idx).dataname);
    end
    
catch exception
    message=sprintf('%s\n',exception.message);
end