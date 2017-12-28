function [ status, message ] = data_crop( obj, selected_data )
% DATA_CROP crop data with inputted boundaries in all dimensions
%
%   !! The process is irreversible, therefore new data holder will be
%   created !!
%
%   Normal mode retains data in the interval
%   Inverse mode removes data in the interval

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
                'Enter T intervals',...
                'Crop Mode (normal/inverse)'};
            dlg_title = cat(2,'Data crop intervals for',obj.data(current_data).dataname);
            num_lines = 2;
            def = [cellfun(@(x)num2str(x'),dim_interval,'UniformOutput',false),'normal'];
            set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
            set(0,'DefaultUicontrolForegroundColor','k');
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            set(0,'DefaultUicontrolBackgroundColor','k');
            set(0,'DefaultUicontrolForegroundColor','w');
            if ~isempty(answer)
                % get intervals
                dim_interval=cellfun(@(x)str2num(x(1:2,:)),answer(1:5),'UniformOutput',false)'; %#ok<ST2NM>
                mode=answer{6};
                switch mode
                    case {'normal','inverse'}
                        
                    otherwise
                        %default invalid mode to normal crop mode
                        mode='normal';
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
                % cancel clicked don't do anything to this data item
                dim_interval=[];
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
            end
        else
            % user decided to apply same settings to rest
            
        end
        % ---- Calculation Part ----
        if ~isempty(dim_interval)
            % decided to process
            switch obj.data(current_data).datatype
                case 'DATA_SPC'
                    data_size=obj.data(current_data).datainfo.data_dim;
                    switch mode
                        case 'normal'
                            crop_index=cellfun(@(x,y)find(obj.data(current_data).datainfo.(x)>=y(1)&obj.data(current_data).datainfo.(x)<=y(2)),obj.DIM_TAG,dim_interval,'UniformOutput',false);
                            [p,l,f]=ind2sub([data_size(2),data_size(3),data_size(5)],obj.data(current_data).dataval(:,1));
                            spc_index=((obj.data(current_data).dataval(:,2)>=dim_interval{1}(1))&(obj.data(current_data).dataval(:,2)<=dim_interval{1}(2))&...
                                (p>=crop_index{2}(1))&(p<=crop_index{2}(end))&...
                                (l>=crop_index{3}(1))&(l<=crop_index{3}(end))&...
                                (f>=crop_index{5}(1))&(f<=crop_index{5}(end)));
                            newdatasize=cellfun(@(x)numel(x),crop_index);
                            pixel_per_line=newdatasize(2);
                            line_per_frame=newdatasize(3);
                            framenum=newdatasize(5);
                            % reindex
                            clock_data=sub2ind([pixel_per_line,line_per_frame,framenum], p(spc_index)-crop_index{2}(1)+1,l(spc_index)-crop_index{3}(1)+1,f(spc_index)-crop_index{5}(1)+1);
                        case 'inverse'
                            message=sprintf('inverse crop for spc data not implemented yet\n');
                            return;
                    end
                    % add new data
                    [ success, message ] = obj.data_add(cat(2,'data_crop|',obj.data(current_data).dataname),[clock_data,obj.data(current_data).dataval(spc_index,2:3)],[]);
                    % recalculate dimension data
                    if success
                        parent_data=current_data;
                        % get new data index
                        new_data=obj.current_data;
                        % set parent data index
                        obj.data(new_data).datainfo.parent_data_idx=parent_data;
                        obj.data(new_data).datainfo.operator='data_crop';
                        obj.data(new_data).datainfo.operator_mode=mode;
                        obj.data(new_data).datainfo.panel=obj.data(parent_data).datainfo.panel;
                        for dim=obj.DIM_TAG
                            dim=char(dim);
                            obj.data(new_data).datainfo.(cat(2,'d',dim))=obj.data(parent_data).datainfo.(cat(2,'d',dim));
                        end
                        % recalculate dimension data
                        if ~isempty(obj.data(parent_data).datainfo.t)
                            obj.data(new_data).datainfo.t=obj.data(parent_data).datainfo.t(crop_index{1});
                        end
                        if ~isempty(obj.data(parent_data).datainfo.X)
                            obj.data(new_data).datainfo.X=obj.data(parent_data).datainfo.X(crop_index{2});
                        end
                        if ~isempty(obj.data(parent_data).datainfo.Y)
                            obj.data(new_data).datainfo.Y=obj.data(parent_data).datainfo.Y(crop_index{3});
                        end
                        if ~isempty(obj.data(parent_data).datainfo.Z)
                            obj.data(new_data).datainfo.Z=obj.data(parent_data).datainfo.Z(crop_index{4});
                        end
                        if ~isempty(obj.data(parent_data).datainfo.T)
                            obj.data(new_data).datainfo.T=obj.data(parent_data).datainfo.T(crop_index{5});
                        end
                        % correct data type and size
                        obj.data(new_data).datatype=obj.data(parent_data).datatype;
                        obj.data(new_data).datainfo.data_dim=newdatasize;
                        % pass on metadata info
                        obj.data(new_data).metainfo=obj.data(parent_data).metainfo;
                        obj.data(new_data).datainfo.last_change=datestr(now);
                        status=true;
                        message=sprintf('data cropped\n%s',message);
                    end
                otherwise
                    switch mode
                        case 'normal'
                            crop_index=cellfun(@(x,y)(obj.data(current_data).datainfo.(x)>=y(1)&obj.data(current_data).datainfo.(x)<=y(2)),obj.DIM_TAG,dim_interval,'UniformOutput',false);
                        case 'inverse'
                            crop_index=cellfun(@(x,y)~(obj.data(current_data).datainfo.(x)>=y(1)&obj.data(current_data).datainfo.(x)<=y(2)),obj.DIM_TAG,dim_interval,'UniformOutput',false);
                    end
                    emptyidx=cellfun(@(x)isempty(find(x)),crop_index);
                    if find(emptyidx)
                        crop_index{cellfun(@(x)isempty(find(x)),crop_index)}=1;%#ok<EFIND> %make sure we have at least one
                    end
                    newdataval=obj.data(current_data).dataval(crop_index{1},crop_index{2},crop_index{3},crop_index{4},crop_index{5});
                    % add new data
                    [ success, message ] = obj.data_add(cat(2,'data_crop|',obj.data(current_data).dataname),newdataval,[]);
                    % recalculate dimension data
                    if success
                        parent_data=current_data;
                        % get new data index
                        new_data=obj.current_data;
                        % set parent data index
                        obj.data(new_data).datainfo.parent_data_idx=parent_data;
                        obj.data(new_data).datainfo.operator='data_crop';
                        obj.data(new_data).datainfo.operator_mode=mode;
                        for dim=obj.DIM_TAG
                            dim=char(dim);
                            obj.data(new_data).datainfo.(cat(2,'d',dim))=obj.data(parent_data).datainfo.(cat(2,'d',dim));
                        end
                        % recalculate dimension data
                        if ~isempty(obj.data(parent_data).datainfo.t)
                            obj.data(new_data).datainfo.t=obj.data(parent_data).datainfo.t(crop_index{1});
                        end
                        if ~isempty(obj.data(parent_data).datainfo.X)
                            obj.data(new_data).datainfo.X=obj.data(parent_data).datainfo.X(crop_index{2});
                        end
                        if ~isempty(obj.data(parent_data).datainfo.Y)
                            obj.data(new_data).datainfo.Y=obj.data(parent_data).datainfo.Y(crop_index{3});
                        end
                        if ~isempty(obj.data(parent_data).datainfo.Z)
                            obj.data(new_data).datainfo.Z=obj.data(parent_data).datainfo.Z(crop_index{4});
                        end
                        if ~isempty(obj.data(parent_data).datainfo.T)
                            obj.data(new_data).datainfo.T=obj.data(parent_data).datainfo.T(crop_index{5});
                        end
                        % pass on metadata info
                        obj.data(new_data).metainfo=obj.data(parent_data).metainfo;
                        obj.data(new_data).datainfo.last_change=datestr(now);
                        status=true;
                        message=sprintf('data cropped\n%s',message);
                    end
            end
        else
            message=sprintf('action cancelled\n');
        end
        % increment data index
        data_idx=data_idx+1;
    end
catch exception
    message=exception.message;
end