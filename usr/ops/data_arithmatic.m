function [ status, message ] = data_arithmatic( obj, selected_data )
%data_arithmatic apply simple arithmatic operations to selected data items
%   the operation must not change the dimensionality of the data, i.e. must
%   be a 1-to-1 mapping
%   e.g. 1. $d/255, $d-10, %d*2, etc
%        2. log($d), exp(%d), etc
%        3. %d.^2
%        4. 0.2989 * $d(1,:,:,:,:) + 0.5870 * $d(2,:,:,:,:) + 0.1140 *
%        $d(3,:,:,:,:); %rgb convertion

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
            % get OPERATION
            prompt = {sprintf('Operation string \nUse $d as substitute variable\ne.g. 10*$d)')};
            dlg_title = cat(2,'Data arithmatic for',obj.data(current_data).dataname);
            num_lines = 1;
            if isfield(obj.data(current_data).datainfo,'operation_string')
                def = {obj.data(current_data).datainfo.operation_string};
                newdata=false;
            else
                def = {'bsxfun(@minus,$d,mean($d(1:10,:,:,:,:),1))'};
                newdata=true;
            end
            set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
            set(0,'DefaultUicontrolForegroundColor','k');
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            set(0,'DefaultUicontrolBackgroundColor','k');
            set(0,'DefaultUicontrolForegroundColor','w');
            if isempty(answer)
                %cancelled
                message=sprintf('Data arithmatic operation cancelled\n');
                return;
            else
                operation=answer{1};
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
        if isempty(operation)
            %action cancelled
            % for multiple data ask for apply to all option
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
        else
            %circular shift data around the specified dimension
            opstr=regexprep(operation,'\$d','obj.data(parent_data).dataval');
            if newdata
                % create new data item
                parent_data=current_data;
                % add new data
                obj.data_add(cat(2,'data_arithmatic|',obj.data(parent_data).dataname),[],[]);
                % get new data index
                current_data=obj.current_data;
                % pass on metadata info
                obj.data(current_data).metainfo=obj.data(parent_data).metainfo;
                % set parent data index
                obj.data(current_data).datainfo=obj.data(parent_data).datainfo;
                % set data index
                obj.data(current_data).datainfo.data_idx=current_data;
                % set parent data index
                obj.data(current_data).datainfo.parent_data_idx=parent_data;
                obj.data(current_data).datainfo.operator='data_arithmatic';
            else
                parent_data=obj.data(current_data).datainfo.parent_data_idx;
                current_data=obj.current_data;
            end
            obj.data(current_data).datainfo.operation_string=operation;
            evalc(cat(2,'obj.data(current_data).dataval=',opstr));
            obj.data(current_data).datainfo.data_dim=[size(obj.data(current_data).dataval,1),...
                size(obj.data(current_data).dataval,2),...
                size(obj.data(current_data).dataval,3),...
                size(obj.data(current_data).dataval,4),...
                size(obj.data(current_data).dataval,5)];
            obj.data(current_data).datatype=obj.get_datatype(current_data);
            obj.data(current_data).datainfo.last_change=datestr(now);
            message=sprintf('data arithmatic %s applied\n',operation);
            status=true;
        end
        % increment data index
        data_idx=data_idx+1;
    end
catch exception
    message=exception.message;
end