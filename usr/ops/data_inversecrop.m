function [ status, message ] = data_inversecrop( obj, selected_data )
% DATA_CROP crop data with inputted boundaries in all dimensions
%
%   !! The process is irreversible, therefore new data holder will be
%   created !!
%

%% function complete

% assume worst
status=false;
try
    data_idx=1;% initialise counter
    askforparam=true;% always ask for the first one
    while data_idx<=numel(selected_data)
        % get the current data index
        current_data=selected_data(data_idx);
        if askforparam % ask if it is the first one
            % work out full interval as default
            dim_interval=cellfun(@(x)[obj.data(current_data).datainfo.(x)(1),obj.data(current_data).datainfo.(x)(end)],...
                obj.DIM_TAG,'UniformOutput',false);
            % need user input/confirm crop intervals
            % get interval information
            prompt = {'Enter t intervals',...
                'Enter X intervals',...
                'Enter Y intervals',...
                'Enter Z intervals',...
                'Enter T intervals'};
            dlg_title = cat(2,'Data crop intervals for',obj.data(current_data).dataname);
            num_lines = 2;
            def = cellfun(@(x)num2str(x'),dim_interval,'UniformOutput',false);
            set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
            set(0,'DefaultUicontrolForegroundColor','k');
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            set(0,'DefaultUicontrolBackgroundColor','k');
            set(0,'DefaultUicontrolForegroundColor','w');
            if ~isempty(answer)
                % get intervals
                dim_interval=cellfun(@(x)str2num(x(1:2,:)),answer,'UniformOutput',false)'; %#ok<ST2NM>
                % for multiple data ask for apply to all option
                if numel(selected_data)>1
                    % ask if want to apply to the rest of the data items
                    button = questdlg('Apply this setting to: ','Multiple Selection','Apply to Rest','Just this one','Apply to All') ;
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
                % cancel clicked don't do anything to this data item
                dim_interval=[];
            end
        else
            % user decided to apply same settings to rest
            
        end
        % ---- Calculation Part ----
        if ~isempty(dim_interval)
            % decided to process
            crop_index=cellfun(@(x,y)(obj.data(current_data).datainfo.(x)>=y(1)&obj.data(current_data).datainfo.(x)<=y(2)),obj.DIM_TAG,dim_interval,'UniformOutput',false);
            newdataval=obj.data(current_data).dataval(crop_index{1},crop_index{2},crop_index{3},crop_index{4},crop_index{5});
            % add new data
            [ success, message ] = obj.data_add(cat(2,'data_crop|',obj.data(current_data).dataname),newdataval,[]);
            % recalculate dimension data
            if success
                % get new data index
                new_data=obj.current_data;
                % set parent data index
                obj.data(new_data).datainfo.parent_data_idx=current_data;
                obj.data(new_data).datainfo.operator='data_crop';
                % assign new data index pointer
                parent_data=current_data;
                current_data=new_data;
                % recalculate dimension data
                if ~isempty(obj.data(parent_data).datainfo.t)
                    obj.data(current_data).datainfo.t=obj.data(parent_data).datainfo.t(crop_index{1});
                end
                if ~isempty(obj.data(current_data).datainfo.X)
                    obj.data(current_data).datainfo.X=obj.data(parent_data).datainfo.X(crop_index{2});
                end
                if ~isempty(obj.data(current_data).datainfo.Y)
                    obj.data(current_data).datainfo.Y=obj.data(parent_data).datainfo.Y(crop_index{3});
                end
                if ~isempty(obj.data(current_data).datainfo.Z)
                    obj.data(current_data).datainfo.Z=obj.data(parent_data).datainfo.Z(crop_index{4});
                end
                if ~isempty(obj.data(current_data).datainfo.T)
                    obj.data(current_data).datainfo.T=obj.data(parent_data).datainfo.T(crop_index{5});
                end
            end
            status=true;
            message=sprintf('data cropped\n%s',message);
        else
            message=sprintf('action cancelled\n');
        end
        % increment data index
        data_idx=data_idx+1;
    end
catch exception
    message=exception.message;
end