function [ status, message ] = data_split( obj, selected_data, askforparam, defaultparam )
%DATA_SPLIT split data in selected dimension into individual new data items
%--------------------------------------------------------------------------
%   1. Split current data in either one of the t,X,Y,Z or T dimension.
%
%   2. Generally useful for split multi-channel data, z stacks (of size N).
%
%   3. User can use expression such as 1;2;3;4;5 to split into individual channel/slices OR use 1:2:5;2:2:5 to split out every other frames
%
%   4. Use more complicated expression such as [1:1:3];[4,5];[6:2:10] to split channels into designed patterns.  ; is used as split seperator.
%
%---Batch process----------------------------------------------------------
%   Parameter=struct('selected_data','1','dim','1','splitexp','1;2;3');
%   selected_data=data index, 1 means previous generated data
%   dim=[1|2|3|4|5];
%   splitexp=string expression
%--------------------------------------------------------------------------
%   HEADER END

%% function complete

% assume worst
status=false;
% for batch process must return 'Data parentidx to childidx' for each
% successful calculation
message='';
try
    % initialise counter
    data_idx=1;
    % number of data to process
    ndata=numel(selected_data);
    % loop through individual data
    while data_idx<=ndata
        % get the current data index
        current_data=selected_data(data_idx);
        % ---- Parameter Assignment ----
        % if it is not automated, we need manual parameter input/adjustment
        if askforparam
            % get axis information
            button = questdlg('Split in which dimension?','Split Data','t','Spatial','T','Spatial');
            switch button
                case 't'
                    % channel or lifetime dimension
                    dim=1;
                    dimsize=numel(obj.data(current_data).datainfo.t);
                case 'Spatial'
                    button = questdlg('Split in which dimension?','Split Data','X','Y','Z','X');
                    switch button
                        case 'X'
                            dim=2;
                            dimsize=numel(obj.data(current_data).datainfo.X);
                        case 'Y'
                            dim=3;
                            dimsize=numel(obj.data(current_data).datainfo.Y);
                        case 'Z'
                            dim=4;
                            dimsize=numel(obj.data(current_data).datainfo.Z);
                        otherwise
                            %action cancelled
                            dim=[];
                            dimsize=[];
                    end
                case 'T'
                    % time dimension
                    dim=5;
                    dimsize=numel(obj.data(current_data).datainfo.T);
                otherwise
                    %action cancelled
                    dim=[];
                    if numel(selected_data)>1
                        % ask if want to cancel for the rest of the data items
                        askforparam=askapplyall('cancel');
                        if askforparam==false
                            message=sprintf('%s\nAction cancelled!',message);
                            return;
                        end
                    else
                        message=sprintf('%s\nAction cancelled!',message);
                        return;
                    end
            end
            % ask for split instruction string
            prompt=sprintf('Splitting format \n(e.g. 1;2;3;4;5 or [1:1:3];[4,5];[6:2:10]}:');
            dlg_title=sprintf('Splitting Format');
            num_lines=1;
            defans=sprintf('%d;',1:1:dimsize);
            def={defans(1:end-1)};
            options.WindowStyle='modal';
            answer = inputdlg(prompt,dlg_title,num_lines,def,options);
            if isempty(answer)
                %action cancelled
                splitexp=[];
                if numel(selected_data)>1
                    % ask if want to cancel for the rest of the data items
                    askforparam=askapplyall('cancel');
                    if askforparam==false
                        message=sprintf('%s\nAction cancelled!',message);
                        return;
                    end
                else
                    message=sprintf('%s\nAction cancelled!',message);
                end
            else
                splitexp=answer{1};
                % for multiple data ask for apply to all option
                if numel(selected_data)>1
                    % ask if want to apply to the rest of the data items
                    askforparam=askapplyall('apply');
                end
            end
        else
            % user decided to apply same settings to rest or use default
            % assign parameters
            fname=defaultparam(1:2:end);
            fval=defaultparam(2:2:end);
            for fidx=1:numel(fname)
                switch fname{fidx}
                    case 'dim'
                        dim=str2num(fval{fidx});
                    case 'splitexp'
                        splitexp=char(fval{fidx});
                end
            end
            
            % only use waitbar for user attention if we are in
            % automated mode
            if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
                % Report current estimate in the waitbar's message field
                done=data_idx/ndata;
                waitbar(done,waitbar_handle,sprintf('%3.1f%%',100*done));
            else
                % create waitbar if it doesn't exist
                waitbar_handle = waitbar(0,'Please wait...','Progress Bar','Calculating...',...
                    'CreateCancelBtn',...
                    'setappdata(gcbf,''canceling'',1)',...
                    'WindowStyle','normal',...
                    'Color',[0.2,0.2,0.2]);
                setappdata(waitbar_handle,'canceling',0);
            end
        end
        
        % ---- Data Calculation ----
        temp=regexp(splitexp,';','split');
        if ~isempty(obj.data(current_data).datainfo.parameter_space)
            psname=regexp(obj.data(current_data).datainfo.parameter_space,'[|]','split');
            if numel(psname)~=numel(temp)
                indstr=sprintf('%s,',temp{:});
                indstr=eval(cat(2,'[',indstr(1:end-1),']'));
                psname=psname(indstr);
            end
        else
            psname=temp;
        end
        for newdata_idx=1:numel(temp)
            % create new data items
            % add new data
            obj.data_add(sprintf('data_split|%s#%g|%s',psname{newdata_idx},newdata_idx,obj.data(current_data).dataname),[],[]);
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
            message=sprintf('%s\nData %s to %s splitted into %g new dataitems.',message,num2str(current_data),num2str(new_data),numel(temp));
        end
        status=true;
        % increment data index
        data_idx=data_idx+1;
    end
    % close waitbar if exist
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
catch exception
    % error handle
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
    message=sprintf('%s\n%s',message,exception.message);
end