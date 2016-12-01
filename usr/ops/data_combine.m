function [ status, message ] = data_combine( obj, selected_data )
%DATA_SHIFT shift data in selected dimension
%   circular shift current data in either t,X,Y,Z or T dimension

%% function check

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
                message=sprintf('action cancelled\n');
            end
            % for multiple data ask for apply to all option
            if numel(selected_data)>1
                % ask if want to apply to the rest of the data items
                button = questdlg('Apply this setting to: ','Multiple Selection','Apply to All','Just this one','Apply to All') ;
                switch button
                    case 'Apply to All'
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
            status=true;
            message=sprintf('data shifted by %g pixels in tXYZT-axis\n',shift_size);
        end
        % increment data index
        data_idx=data_idx+1;
    end
catch exception
    message=exception.message;
end