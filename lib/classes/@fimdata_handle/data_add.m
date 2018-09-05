function [ status, message ] = data_add( obj, name, data, selected )
%ADD_DATA add new data from rawdata slices/other fluorescent data/values
%   if selected=[] and data is of fimdata_handle class, data will be appended
%   if selected is a mx2 array, slices will be added as new data
%   if data=[], a new placeholder of data will be added, this will be
%   useful for operation generated data

%% function check
status=false;
try
    %obj.data_select(1);
    if isempty(data)
        %add a new data using template
        obj.data(end+1)=obj.data(1);
        current_data=numel(obj.data);
        %assign data name
        obj.data(current_data).dataname=name;
        %update data index
        obj.data(current_data).datainfo.data_idx=current_data;
        %update data last change date
        obj.data(current_data).datainfo.last_change=datestr(now);
        %return information and success status
        message=sprintf('new data %s added\n',name);
        status=true;
    elseif isa(data,'fimdata_handle')
        
        %return information and success status
        message=sprintf('%g of fluorescent data added\n',num_data);
        status=true;
    elseif isnumeric(data)||islogical(data)
        %create new data and add values including placeholder with data=[]
        
        %add a new data using template
        obj.data(end+1)=obj.data(1);
        current_data=numel(obj.data);        
        %copy over numerical data
        obj.data(current_data).dataval=data;
        %update data name
        obj.data(current_data).dataname=name;
        %update data index
        obj.data(current_data).datainfo.data_idx=current_data;
        %work out data dimension
        datasize=size(data);
        datasize=[datasize,ones(1,5-numel(datasize))];
        obj.data(current_data).datainfo.data_dim=datasize;
        %work out data type
        obj.data(current_data).datatype=obj.get_datatype;
        %update data last change date
        obj.data(current_data).datainfo.last_change=datestr(now);
        %return information and success status
        message=sprintf('one new data added\n');
        status=true;
    elseif ischar(data)
        % file for adding exported fimas files (edf)
        temp=load(data,'-mat');
        % copy over all items inside the exported fim files
        num_data=numel(temp.dataitem);
        for d_idx=1:1:num_data
            obj.data(end+1)=temp.dataitem(d_idx);
            current_data=numel(obj.data);
            obj.data(current_data).datainfo.data_idx=current_data;
        end
        %return information and success status
        message=sprintf('%g of fluorescent data added from %s\n',num_data,data);
        status=true;
    elseif isstruct(data)
        %from user operations
        %add a new data using existing data
        obj.data(end+1).current_roi=1;
        current_data=numel(obj.data);
        fname=fieldnames(data);
        for fidx=1:numel(fname)
            fieldname=fname{fidx};
            if isempty(strfind(fieldname,'roi'))
                obj.data(current_data).(fieldname)=data.(fieldname);
            end
        end
        obj.data(current_data).datainfo.data_idx=current_data;
        obj.data(current_data).datainfo.last_change=datestr(now);
        obj.data(current_data).dataname=name;
        obj.data(current_data).roi=obj.data(1).roi;%reset roi
        
        %return information and success status
        message=sprintf('one new data added\n');
        status=true;
    end
    if status==true;
        % update current data pointer
        obj.data_select(current_data);
    end
catch exception
    message=exception.message;
end