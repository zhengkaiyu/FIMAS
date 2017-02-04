function [ status, message ] = data_export( obj, index )
%DATA_EXPORT export selected data from a session
%  only export selected data for future import

%% function complete

status=false;
try
    [filename,pathname,~]=uiputfile({'*.edf','exported data file (*.edf)';...
        '*.*','All Files (*.*)'},...
        'Select Exported Data Analysis File',obj.path.export);
    if pathname~=0     %if files selected
        filename=cat(2,pathname,filename);
        dataitem=obj.data(index); %#ok<NASGU>
        % clear handles
        for dataidx=2:numel(dataitem)
            dataitem(dataidx).datainfo.panel=[];
            if numel(dataitem(dataidx).roi)>1
                dataitem(dataidx).roi(2:end).panel=[];
                dataitem(dataidx).roi(2:end).handle=[];
            end
        end
        %to cope with large file size
        save(filename,'dataitem','-mat','-v7.3');
        %update saved path
        obj.path.export=pathname;
        message=sprintf('data item %g exported\n',index);
        status=true;
    else
        %action cancelled
        message=sprintf('%s\n','file export action cancelled');
    end
catch exception%error handle
    message=sprintf('%s\n',exception.message);
end