function [ status, message ] = data_flipdim( obj, selected_data )
% DATA_FLIPDIM Flipimages upside down in selected dimension
%   flip images in either t,X,Y,Z or T dimension
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
            % get axis information
            button = questdlg('Flip which dimension?','Flip Data','t','Spatial','T','Spatial');
            switch button
                case 't'
                    dim=1;
                case 'Spatial'
                    button = questdlg('Flip which dimension?','Flip Data','X','Y','Z','X');
                    switch button
                        case 'X'
                            dim=2;
                        case 'Y'
                            dim=3;
                        case 'Z'
                            dim=4;
                        otherwise
                            %action cancelled
                            dim=[];
                    end
                case 'T'
                    dim=5;
                otherwise
                    %action cancelled
                    dim=[];
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
        if isempty(dim)
            %action cancelled
            message=sprintf('action cancelled\n');
        else
            %flip upside down
            obj.data(current_data).dataval=flip(obj.data(current_data).dataval,dim);
            obj.data(current_data).datainfo.last_change=datestr(now);
            status=true;
            message=sprintf('Data fliped along %s-axis\n',obj.DIM_TAG{dim});
        end
        % increment data index
        data_idx=data_idx+1;
    end
catch exception
    message=exception.message;
end