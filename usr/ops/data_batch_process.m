function [ status, message ] = data_batch_process( obj, selected_data, askforparam, defaultparam )
%DATA_BATCH_PROCESS Summary of this function goes here
%   Detailed explanation goes here
temp=evalc('obj.display_data_operator([],[])');
oplist=regexp(temp,'\s*','split');
oplist=oplist(1:end-1);
header=cellfun(@(x)help(x),oplist,'UniformOutput',false);
batch_capable_func=cellfun(@(x)~isempty(regexp(x,'[-]*Batch process[-]*','match')),header);
fighandle=GUI_BATCH_PROCESS('hDATA',obj,'selDATA',selected_data,'operator',oplist(batch_capable_func));
waitfor(fighandle);
status=true;
message='batch processing window closed';
end