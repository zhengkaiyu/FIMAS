function [ status, message ] = data_delete( obj, index )
%REMOVE_DATA remove selected data/s from the storage
%   remove data as indexed from the storage
%   but not the template data (index=1)

%% function check
status=false;message='';
try
    index=index(index>1);  %ignore template data, it cannot be deleted
    if ~isempty(index)
        %need to clear roi handles here before clear actual data structure
        for data_idx=1:numel(index)
            num_roi=numel(obj.data(index(data_idx)).roi);
            for r_idx=num_roi:-1:2%the ALL roi is not a handle
                delete(obj.data(index(data_idx)).roi(r_idx).handle);%clear handle
            end
            message=sprintf('%sdeleting data %g\n',message,index(data_idx));
        end
        %clear data structure
        obj.data(index)=[];
        
        % possible check for parent and children data index consistency
        %update data_idx
        for data_idx=min(index):1:numel(obj.data)
            obj.data(data_idx).datainfo.data_idx=data_idx;
        end
        
        %need to efficiently update parent data index
        obj.current_data=min(index)-1;
        message=sprintf('%s%g data removed\n',message,numel(index));
        status=true;
    else
        %only template data selected
        message=sprintf('template data cannot be deleted\n');
    end
catch exception
    message=sprintf('%s\n',exception.message);
end