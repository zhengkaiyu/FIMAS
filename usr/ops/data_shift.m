function [ status, message ] = data_shift( obj, selected_data )
% DATA_SHIFT shift data in selected dimension
%   circular shift current data in either t,X,Y,Z or T dimension
%   no spc data implementation yet

%% function complete

% assume worst
status=false;
try
    data_idx=1;% initialise counter
    askforparam=true;% always ask for the first one
    while data_idx<=numel(selected_data)
        % get the current data index
        current_data=selected_data(data_idx);
        if askforparam
            % get shifting dimension data
            prompt = {'Enter t shift pixel size',...
                'Enter X shift pixel size',...
                'Enter Y shift pixel size',...
                'Enter Z shift pixel size',...
                'Enter T shift pixel size'};
            dlg_title = cat(2,'Data bin sizes for',obj.data(current_data).dataname);
            num_lines = 1;
            def = {'0','0','0','0','0'};
            set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
            set(0,'DefaultUicontrolForegroundColor','k');
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            set(0,'DefaultUicontrolBackgroundColor','k');
            set(0,'DefaultUicontrolForegroundColor','w');
            if ~isempty(answer)
                shift_size=str2double(answer);
            else
                shift_size=[];
                if numel(selected_data)>1
                    % ask if want to cancel for the rest of the data items
                    button = questdlg('Cancel ALL?','Multiple Selection','Cancel ALL','Just this one','Cancel ALL') ;
                    switch button
                        case 'Apply to Rest'
                            askforparam=false;
                        case 'Just this one'
                            askforparam=true;
                        otherwise
                            % action cancellation
                            askforparam=false;
                    end
                    if askforparam==false
                        message=sprintf('Action cancelled!');
                        return;
                    end
                else
                    message=sprintf('Action cancelled!');
                end
            end
            % for multiple data ask for apply to all option
            if numel(selected_data)>1
                % ask if want to apply to the rest of the data items
                button = questdlg('Apply this setting to: ','Multiple Selection','Apply to Rest','Just this one','Apply to Rest') ;
                switch button
                    case 'Apply to Rest'
                        askforparam=false;
                    case 'Just this one'
                        askforparam=true;
                    otherwise
                        % action cancellation
                        askforparam=false;
                end
            end
        else
            % user decided to apply same settings to rest
            
        end
        % ---- Calculation ----
        if isempty(shift_size)
            %action cancelled
            message=sprintf('action cancelled\n');
        else
            %circular shift data around the specified dimension
            obj.data(current_data).dataval=circshift(obj.data(current_data).dataval,shift_size);
            obj.data(current_data).datainfo.last_change=datestr(now);
            status=true;
            message=sprintf('data shifted by %g pixels in tXYZT-axis\n',shift_size);
        end
        % increment data index
        data_idx=data_idx+1;
    end
catch exception
    message=exception.message;
end