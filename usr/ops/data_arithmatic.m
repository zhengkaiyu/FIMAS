function [ status, message ] = data_arithmatic( obj, selected_data, askforparam, defaultparam )
%DATA_ARITHMATIC apply simple arithmatic operations to selected data items.  The operation must not change the dimensionality of the data, i.e. must be a 1-to-1 mapping
%   $d represents current data
%--------------------------------------------------------------------------
%   e.g. 1. $d/255, $d-10, %d*2 for simple scalar division, subtraction, multiplication
%        2. log($d), exp(%d), %d.^2, etc for simple maths function
%        3. $d(2,:,:,:,:)./$d(1,:,:,:,:) channel ratio
%        4. 0.2989 * $d(1,:,:,:,:) + 0.5870 * $d(2,:,:,:,:) + 0.1140 * $d(3,:,:,:,:) for rgb convertion assuming CXYZT data
%        5. bsxfun(@minus,$d,mean($d(1:10,:,:,:,:),1)) subtract baseline
%
%---Batch process----------------------------------------------------------
%   Parameter=struct('selected_data','1','newdata','1','operation','bsxfun(@minus,$d,mean($d(1:10,:,:,:,:),1))');
%   selected_data=data index, 1 means previous generated data
%   newdata=0|1; for batch process it needs to be 1
%   operation=function string
%--------------------------------------------------------------------------
%   HEADER END

%% function complete

% assume worst
status=false;
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
            % get OPERATION
            prompt = {sprintf('Operation string \nUse $d as substitute variable\ne.g. 10*$d)')};
            dlg_title = cat(2,'Data arithmatic for',obj.data(current_data).dataname);
            num_lines = 1;
            if isfield(obj.data(current_data).datainfo,'operation_string')
                % already has operation specified
                def = {obj.data(current_data).datainfo.operation_string};
                newdata=false;
            else
                % operation has not been specified
                def = {'bsxfun(@minus,$d,mean($d(1:10,:,:,:,:),1))'};
                newdata=true;
            end
            set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
            set(0,'DefaultUicontrolForegroundColor','k');
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            set(0,'DefaultUicontrolBackgroundColor','k');
            set(0,'DefaultUicontrolForegroundColor','w');
            if isempty(answer)
                % cancelled
                message=sprintf('%s\nOperation cancelled',message);
                operation=[];
            else
                operation=answer{1};
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
                    case 'operation'
                        operation=char(fval{fidx});
                    case 'newdata'
                        newdata=logical(fval{fidx});
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
        if isempty(operation)
            %action cancelled
            % for multiple data ask for apply to all option
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
            % decided to process
            % get function string by replacing $d with actual dataval
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
                current_data=obj.current_data;
            end
            obj.data(current_data).datainfo.operation_string=operation;
            % apply actual arithmatic operation
            evalc(cat(2,'obj.data(current_data).dataval=',opstr));
            % get correct dimension size again
            obj.data(current_data).datainfo.data_dim=[size(obj.data(current_data).dataval,1),...
                size(obj.data(current_data).dataval,2),...
                size(obj.data(current_data).dataval,3),...
                size(obj.data(current_data).dataval,4),...
                size(obj.data(current_data).dataval,5)];
            % get data type
            obj.data(current_data).datatype=obj.get_datatype(current_data);
            % update datainfo
            obj.data(current_data).datainfo.last_change=datestr(now);
            message=sprintf('%s\nData %s to %s arithmatic %s applied',message,num2str(parent_data),num2str(current_data),operation);
            status=true;
        end
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