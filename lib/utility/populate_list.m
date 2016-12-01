function populate_list(list_handle,list_string,list_val)
% populate_list update lists and it's value in matlab uilist,uidropmen
% handle.
% Usage: populate_list(list_handle,output_list,current_selection_index)


%% function complete
list_val=max(list_val,1);%make sure we have valid value so that list don't disappear

set(list_handle,'String',list_string);%set content string
set(list_handle,'Value',list_val); %select item

