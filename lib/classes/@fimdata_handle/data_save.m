function [ status, message ] = data_save( obj )
%saves currently opend fimdata_handle into matlab format
%

%% function complete

% assume the worst
status=false;
% error handle trial
try
    % get default pathname or existing datafile name
    switch obj.data(1).dataname
        case 'template'
            pathname=obj.path.saved;
        otherwise
            pathname=obj.data(1).dataname;
    end
    % get output file
    [filename,pathname,~]=uiputfile({'*.fim','FIMAS (*.fim)';...
        '*.*','All Files (*.*)'},...
        'Select Saved FIMAS File',pathname);pause(0.001);
    if pathname~=0
        % if files selected get filename
        filename=cat(2,pathname,filename);
        % update template name to filename
        obj.data(1).dataname=filename;
        for dataidx=2:numel(obj.data)
            % clear handles
            obj.data(dataidx).datainfo.panel=[];
            if numel(obj.data(dataidx).roi)>1
                obj.data(dataidx).roi(2:end).panel=[];
                obj.data(dataidx).roi(2:end).handle=[];
            end
        end
        %try
        % ver 7 is much faster and create smaller file than ver 7.3
        %    save(filename,'obj','-mat','-v7');
        %    version='7';
        %catch
        % if data is >2G we need v7.3
        save(filename,'obj','-mat','-v7.3');
        version='7.3';
        %end
        % update saved path
        obj.path.saved=pathname;
        message=sprintf('%s saved in ver %s\n',filename,version);
        % return success status
        status=true;
    else
        % user interuption
        message=sprintf('file save operation cancelled\n');
    end
catch exception
    message=sprintf('%s\n',exception.message);
end
