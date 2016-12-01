function [ status, message ] = roi_delete( obj )
%ROI_DELETE removes selected roi of selected data except templates

%%function complete
status=false;
data_idx=obj.current_data;
%template should not have roi
current_roi=obj.data(data_idx).current_roi;
%forget about ALL roi which should always be present
current_roi=current_roi(current_roi>1);
if ~isempty(current_roi)
    %have to loop through handle objects
    for m=numel(current_roi):-1:1
        delete(obj.data(data_idx).roi(current_roi(m)).handle);%clear handle object
    end
    %empty all information
    obj.data(data_idx).roi(current_roi)=[];
    
    %update temp current roi to the one before the first selected
    current_roi=current_roi(1)-1;
    
    %set colours
    if current_roi>1 %if not the template 'ALL'
        setColor(obj.data(data_idx).roi(current_roi).handle,'w');%set last one as current select
    end
    
    %update real current roi
    obj.data(data_idx).current_roi=current_roi;
    
    message=sprintf('%g roi deleted\n',numel(current_roi));
    status=true;
else
    message=sprintf('template roi cannot be deleted\n');
end