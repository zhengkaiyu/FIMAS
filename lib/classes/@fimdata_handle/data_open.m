function [ status, message ] = data_open( obj )
% open data of the class fimdata_handle
% this will replace older data in the handle

%% function complete

% assume worst outcome
status=false;
% error handled trial
try
    % ask for one file to open
    [filename,pathname,~] = uigetfile({'*.fim','FIMAS file (*.fim)';...
        '*.*','All Files (*.*)'},...
        'Select Saved FIMAS Data Analysis File',...
        'MultiSelect','off',obj.path.saved);
    % if files selected
    if pathname~=0
        obj.path.saved = pathname;% update saved path to speed up next time
        temp = load(cat(2,pathname,filename),'-mat'); % load file
        openfig=findobj(0,'Name','FIMAS');
        if numel(openfig)>1
            delete(openfig(1));
        end
        if isfield(temp,'obj') % has object field
            if isa(temp.obj,'fimdata_handle') % is of fimdata_handle class
                % before copy over lets delete current roi
                for memberidx=2:numel(obj.data)
                    numroi=numel(obj.data(memberidx).roi);
                    if numroi>1
                        for roiidx=2:numroi
                            delete(obj.data(memberidx).roi(roiidx).handle);
                        end
                    end
                end
                
                obj.data=temp.obj.data;
                % update saved path just in case file has moved
                obj.path.saved = pathname;
                
                % redraw all the roi
                for memberidx=2:numel(obj.data)
                    obj.current_data=memberidx;
                    obj.roi_add('redraw');
                end
                
                % reset current data to one to avoid index mismatch
                obj.current_data=temp.obj.current_data;
                message = sprintf('%s opened\n',filename);
                %return success status
                status=true;
            else
                %contain wrong class => wrong class
                message=sprintf('%s has object of the wrong class\n',filename);
            end
        else
            %don't contain obj => wrong file format
            message=sprintf('%s has no object.  Wrong file format.\n',filename);
        end
    else
        % import action cancelled
        message=sprintf('File Open Operation Cancelled\n');
    end
catch exception
    message=sprintf('%s\n',exception.message);
end

