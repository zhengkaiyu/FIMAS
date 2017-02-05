function [ status, message ] = data_rearrangedim( obj, selected_data )
% DATA_REARRANGEDIM permutes dimensions of a 5D data
%   input permutation vector for dimension index and
%   operation will apply to the current data selected
%   process is reversible
%   e.g. input [1,2,5,4,3] will change a tXYZT data to tXTZY

%% function complete
status=false;message='';
try
    data_idx=1;% initialise counter
    askforparam=true;% always ask for the first one
    % process through all selected data
    while data_idx<=numel(selected_data)
        % get current data index
        current_data=selected_data(data_idx);
        if askforparam
            % ask for user input
            options.Resize='on';options.WindowStyle='modal';options.Interpreter='tex';
            set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
            set(0,'DefaultUicontrolForegroundColor','k');
            answer = inputdlg(sprintf('swap dimensions using dim index [1,2,3,4,5]=[t,X,Y,Z,T]\nThis operation will apply to data %s',num2str(selected_data)),...
                'Swap Dimensions',1,...
                {'[1,2,3,4,5]'},options);
            set(0,'DefaultUicontrolBackgroundColor','k');
            set(0,'DefaultUicontrolForegroundColor','w');
            if ~isempty(answer)
                %swap dim
                new_dim=eval(answer{1});
            else
                % cancel clicked don't do anything to this data item
                new_dim=[];
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
        % ---- Calculation Part ----
        if isempty(new_dim)
            message=sprintf('Data swap action cancelled\n');
        else
            % check validity
            old_dim=obj.data(current_data).datainfo.data_dim;
            obj.data(current_data).datainfo.data_dim=obj.data(current_data).datainfo.data_dim(new_dim);
            newtype=obj.get_datatype(current_data);
            if isempty(newtype)
                %invalid swap happenend
                new_dim=[];% don't do anything later on
                obj.data(current_data).datainfo.data_dim=old_dim;
                message=sprintf('Invalid swap\n');
            else
                %do actual swap of value
                obj.data(current_data).dataval=permute(obj.data(current_data).dataval,new_dim);
                %get old order
                old_axis={obj.data(current_data).datainfo.t,...
                    obj.data(current_data).datainfo.X,...
                    obj.data(current_data).datainfo.Y,...
                    obj.data(current_data).datainfo.Z,...
                    obj.data(current_data).datainfo.T};
                old_daxis={obj.data(current_data).datainfo.dt,...
                    obj.data(current_data).datainfo.dX,...
                    obj.data(current_data).datainfo.dY,...
                    obj.data(current_data).datainfo.dZ,...
                    obj.data(current_data).datainfo.dT};
                %do actual swap of axes
                for dim_idx=1:5
                    if new_dim(dim_idx)~=dim_idx
                        %change
                        old_dim_tag=char(obj.DIM_TAG(dim_idx));
                        obj.data(current_data).datainfo.(old_dim_tag)=old_axis{new_dim(dim_idx)};
                        obj.data(current_data).datainfo.(cat(2,'d',old_dim_tag))=old_daxis{new_dim(dim_idx)};
                    end
                end
                obj.data(current_data).datatype=newtype;
                obj.data(current_data).datainfo.last_change=datestr(now);
                %return true
                status=true;
                message=sprintf('%s Data swapped to %s\n',message,char(obj.DIM_TAG(new_dim)));
            end
        end
        % increment data index
        data_idx=data_idx+1;
    end
catch exception
    message=exception.message;
    obj.data(current_data).datainfo.data_dim=old_dim;
end