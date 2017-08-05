function [ status, message ] = data_split( obj, selected_data )
%DATA_SPLIT split data in selected dimension into individual new data items
%   split current data in either one of the t,X,Y,Z or T dimension
%   generally useful for split multi-channel data, z stacks (of size N)
%   user can use expression such as 1;2;3;4;5 to split into individual
%   channel/slices OR use 1:2:5;2:2:5 to split out every other frames
%   use more complicated expression such as [1:1:3];[4,5];[6:2:10] to split
%   channels into designed patterns.  ; is used as split seperator.

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
                    message=sprintf('action cancelled\n');
                    return;
            end
            % ask for split instruction string
            set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
            set(0,'DefaultUicontrolForegroundColor','k');
            prompt=sprintf('Splitting format \n(e.g. 1;2;3;4;5 or [1:1:3];[4,5];[6:2:10]}:');
            dlg_title=sprintf('Splitting Format');
            num_lines=1;
            def={'1;2;3'};
            options.WindowStyle='modal';
            answer = inputdlg(prompt,dlg_title,num_lines,def,options);
            set(0,'DefaultUicontrolBackgroundColor','k');
            set(0,'DefaultUicontrolForegroundColor','w');
            if isempty(answer)
                %action cancelled
                message=sprintf('action cancelled\n');
                return;
            else
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
            end
        else
            % user decided to apply same settings to rest
            
        end
        % ---- Calculation ----
        temp=regexp(answer{1},';','split');
        for newdata_idx=1:numel(temp)
            % create new data items
            % add new data
            obj.data_add(sprintf('data_split|#%g|%s',newdata_idx,obj.data(current_data).dataname),[],[]);
            % get new data index
            new_data=obj.current_data;
            % set parent data index
            obj.data(new_data).datainfo=obj.data(current_data).datainfo;
            % set data index
            obj.data(new_data).datainfo.data_idx=new_data;
            % set parent data index
            obj.data(new_data).datainfo.parent_data_idx=current_data;
            obj.data(new_data).datainfo.operator='data_split';
            subsetidx=str2num(temp{newdata_idx});
            % split data set
            switch dim
                case 1%t
                    obj.data(new_data).dataval=obj.data(current_data).dataval(subsetidx,:,:,:,:);
                    obj.data(new_data).datainfo.dt=obj.data(current_data).datainfo.dt;
                    obj.data(new_data).datainfo.t=obj.data(current_data).datainfo.t(subsetidx);
                    obj.data(new_data).datainfo.data_dim(1)=numel(obj.data(new_data).datainfo.t);
                case 2%X
                    obj.data(new_data).dataval=obj.data(current_data).dataval(:,subsetidx,:,:,:);
                    obj.data(new_data).datainfo.dX=obj.data(current_data).datainfo.dX;
                    obj.data(new_data).datainfo.X=obj.data(current_data).datainfo.X(subsetidx);
                    obj.data(new_data).datainfo.data_dim(2)=numel(obj.data(new_data).datainfo.X);
                case 3%Y
                    % assign new data item values
                    obj.data(new_data).dataval=obj.data(current_data).dataval(:,:,subsetidx,:,:);
                    obj.data(new_data).datainfo.dY=obj.data(current_data).datainfo.dY;
                    obj.data(new_data).datainfo.Y=obj.data(current_data).datainfo.Y(subsetidx);
                    obj.data(new_data).datainfo.data_dim(3)=numel(obj.data(new_data).datainfo.Y);
                case 4%Z
                    % assign new data item values
                    obj.data(new_data).dataval=obj.data(current_data).dataval(:,:,:,subsetidx,:);
                    obj.data(new_data).datainfo.dZ=obj.data(current_data).datainfo.dZ;
                    obj.data(new_data).datainfo.Z=obj.data(current_data).datainfo.Z(subsetidx);
                    obj.data(new_data).datainfo.data_dim(4)=numel(obj.data(new_data).datainfo.Z);
                case 5%T
                    % assign new data item values
                    obj.data(new_data).dataval=obj.data(current_data).dataval(:,:,:,:,subsetidx);
                    obj.data(new_data).datainfo.dT=obj.data(current_data).datainfo.dT;
                    obj.data(new_data).datainfo.T=obj.data(current_data).datainfo.T(subsetidx);
                    obj.data(new_data).datainfo.data_dim(5)=numel(obj.data(new_data).datainfo.T);
            end
            %redefine data type
            obj.data(new_data).datatype=obj.get_datatype(new_data);
            % pass on metadata info
            obj.data(new_data).metainfo=obj.data(current_data).metainfo;
            obj.data(new_data).datainfo.parameter_space=[];
            obj.data(new_data).datainfo.last_change=datestr(now);
        end
        status=true;
        message=sprintf('data %s splitted into %g new dataitems\n',obj.data(current_data).dataname,numel(temp));
        % increment data index
        data_idx=data_idx+1;
    end
catch exception
    message=exception.message;
end