function [ status, message ] = data_adaptive_bin( obj, selected_data, askforparam, defaultparam )
% data_adaptive_bin bin currently selected data in provided dimensions
%   The process is irreversible, therefore new data holder will be created.
%   Data which does not fit into whole bins at the end will be discarded
%   Default mode is sum. nan* mode should be used if data contain nan

%% function check

% assume worst
status=false;
try
    data_idx=1;% initialise counter
    askforparam=true;% always ask for the first one
    while data_idx<=numel(selected_data)
        % get the current data index
        current_data=selected_data(data_idx);
        % check for data operator
        if strmatch(obj.data(current_data).datainfo.operator,'data_adaptive_bin','exact')
            % existing data
            newdata=false;
        else
            % new data will need to be created
            newdata=true;
        end
        if askforparam % ask if it is the first one
            % check for bin dimension
            if isfield(obj.data(current_data).datainfo,'binsize')
                % use current bin dimension
                binsize=obj.data(current_data).datainfo.binsize;
            else
                % bin dimension don't exist need to get set it to full size
                binsize=[];
            end
            % check for bin calculation mode
            if isfield(obj.data(current_data).datainfo,'operator_mode')
                opmode=obj.data(current_data).datainfo.operator_mode;% default bin mode
            else
                opmode='sum';% default bin mode
            end
            % check for bin calculation mode
            if isfield(obj.data(current_data).datainfo,'calculator_mode')
                calcmode=obj.data(current_data).datainfo.calculator_mode;% default bin mode
            else
                calcmode='same';% default bin mode
            end
            if isfield(obj.data(current_data).datainfo,'tail_threshold')
                tail_threshold=obj.data(current_data).datainfo.tail_threshold;% default threshold
            else
                tail_threshold=3;
            end
            if isfield(obj.data(current_data).datainfo,'cv_threshold')
                cv_threshold=obj.data(current_data).datainfo.cv_threshold;% default threshold
            else
                cv_threshold=1.1;
            end
            if isfield(obj.data(current_data).datainfo,'t_tail')
                t_tail=obj.data(current_data).datainfo.t_tail;% default threshold
            else
                t_tail=10e-9;%ns
            end
            % check mode is correct
            switch opmode
                case {'mean','nanmean','sum','nansum','max','nanmax','min','nanmin','median','nanmedian'}
                    
                otherwise
                    opmode='sum';
            end
            % need user input/confirm bin size
            % get binning information
            prompt = {'This is based on the current data (mean/sum/max/min/median and nan mode)',...
                'tail threshold',...
                't_tail',...
                'cv threshold',...
                'Calculation Mode (reduce/same)'};
            dlg_title = cat(2,'Data bin option for',obj.data(current_data).dataname);
            num_lines = 1;
            def = {opmode,num2str(tail_threshold),num2str(t_tail),num2str(cv_threshold),calcmode};
            set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
            set(0,'DefaultUicontrolForegroundColor','k');
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            set(0,'DefaultUicontrolBackgroundColor','k');
            set(0,'DefaultUicontrolForegroundColor','w');
            if ~isempty(answer)
                % calculation mode
                opmode=answer{1};
                tail_threshold=str2double(answer{2});
                t_tail=str2double(answer{3});
                cv_threshold=str2double(answer{4});
                calcmode=answer{5};
                switch opmode
                    case {'mean','nanmean','sum','nansum','max','nanmax','min','nanmin','median','nanmedian'}
                        
                    otherwise
                        message=sprintf('unknown binning mode entered\n Use sum or mean\n');
                        return;
                end
                switch calcmode
                    case {'reduce','same'}
                        
                    otherwise
                        message=sprintf('unknown calcmode mode entered\n Use reduce or same\n');
                        return;
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
                status=true;
            else
                % cancel clicked don't do anything to this data item
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
        if status
            status=false;
            % decided to process
            if newdata
                parent_data=current_data;
                % add new data
                obj.data_add(cat(2,'data_adaptive_bin|',obj.data(parent_data).dataname),[],[]);
                % get new data index
                current_data=obj.current_data;
                obj.data(current_data).datainfo=obj.data(parent_data).datainfo;
                % set parent data index
                obj.data(current_data).datainfo.parent_data_idx=parent_data;
            else
                % get parent data index
                parent_data=obj.data(current_data).datainfo.parent_data_idx;
            end
            obj.data(current_data).datainfo.operator='data_adaptive_bin';
            obj.data(current_data).datainfo.binsize=binsize;
            obj.data(current_data).datainfo.operator_mode=opmode;
            obj.data(current_data).datainfo.calculator_mode=calcmode;
            obj.data(current_data).datainfo.tail_threshold=tail_threshold;
            obj.data(current_data).datainfo.t_tail=t_tail;
            obj.data(current_data).datainfo.cv_threshold=cv_threshold;
            dim_size=obj.data(parent_data).datainfo.data_dim;
            rawdata=obj.data(parent_data).dataval;
            % work out new data size
            T=obj.data(parent_data).datainfo.T;
            t_end=find(obj.data(parent_data).datainfo.t>t_tail,1,'first');
            T_idx=1;
            new_T_idx=1;
            %initialise waitbar
            waitbar_handle = waitbar(0,'Please wait...','Progress Bar','Calculating...',...
                'Name',cat(2,'Calculating ',obj.data(current_data).datainfo.operator,' for ',obj.data(current_data).dataname),...
                'CreateCancelBtn',...
                'setappdata(gcbf,''canceling'',1)',...
                'WindowStyle','normal',...
                'Color',[0.2,0.2,0.2]);
            global SETTING; %#ok<TLEV>
            javaFrame = get(waitbar_handle,'JavaFrame');
            javaFrame.setFigureIcon(javax.swing.ImageIcon(cat(2,SETTING.rootpath.icon_path,'main_icon.png')));
            setappdata(waitbar_handle,'canceling',0);
            % get total calculation step
            N_steps=dim_size(5);barstep=0;
            while T_idx<dim_size(5)
                % check waitbar
                if getappdata(waitbar_handle,'canceling')
                    message=sprintf('data adaptive bin calculation cancelled\n');
                    delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
                    return;
                end
                % Report current estimate in the waitbar's message field
                done=T_idx/N_steps;
                if floor(100*done)>=barstep
                    % update waitbar
                    waitbar(done,waitbar_handle,sprintf('%g%%',barstep));
                    barstep=barstep+1;
                end
                Tbin=0;
                tailval=0;
                stable=true;
                while stable&&(tailval<tail_threshold)
                    if Tbin>0
                        switch opmode
                            case {'sum','nansum','mean','nanmean','median','nanmedian'}
                                tempval=eval(cat(2,opmode,'(rawdata(:,:,:,:,T_idx:T_idx+Tbin),5);'));
                            case {'max','nanmax','min','nanmin'}
                                tempval=eval(cat(2,opmode,'(rawdata(:,:,:,:,T_idx:T_idx+Tbin),[],5);'));
                        end
                    else
                        tempval=rawdata(:,T_idx);
                    end
                    tailval=mean(tempval(t_end:end));
                    intensity=sum(rawdata(:,T_idx:T_idx+Tbin),1);
                    cv=var(intensity)/mean(intensity);
                    if cv>=cv_threshold
                        stable=false;
                    end
                    Tbin=Tbin+1;
                    if T_idx+Tbin>dim_size(5)
                        T_idx=dim_size(5);
                        tailval=tail_threshold+1;
                    end
                end
                tempdata(:,:,:,:,new_T_idx)=tempval(:);
                tempT(new_T_idx)=T(T_idx);
                binsize(new_T_idx)=Tbin;
                new_T_idx=new_T_idx+1;
                switch calcmode
                    case 'reduce'
                        T_idx=T_idx+Tbin;
                    case 'same'
                        T_idx=T_idx+1;
                end
            end
            delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
            obj.data(current_data).dataval=tempdata;
            obj.data(current_data).datainfo.T=tempT;
            %obj.data(current_data).datainfo.dT=;
            obj.data(current_data).datainfo.binsize=binsize(1:end);
            status=true;
            % recalculate dimension data
            message=sprintf('data binned\n');
            %redefine data type
            obj.data(current_data).datainfo.data_dim=size(tempdata);
            obj.data(current_data).datatype=obj.get_datatype(current_data);
        else
            message=sprintf('action cancelled\n');
        end
        % increment data index
        data_idx=data_idx+1;
    end
catch exception
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
    message=exception.message;
end