function [ status, message ] = data_batchrename( obj, selected_data, askforparam, defaultparam )
%DATA_BATCHRENAME rename dataitem, useful for batch processing
%--------------------------------------------------------------------------
%   1. Can be used for batch renaming with some indexing
%
%   2. common part must contain %s placeholder for indexed parts
%
%   3. common part contain only %s to use existing name as common part
%
%   4. Indexed part empty for same names
%
%   5. e.g. common='trial_%s_Ch1', indexed=1:1:10, ,replace=''
%           common='%s',indexd=1:1:10,,replace=''
%           common='trial',indexed=[],,replace=''
%           common='([\w|]*pos#\d[|])',indexed=[],replace='UG'
%
%---Batch process----------------------------------------------------------
%   Parameter=struct('selected_data','1','common','([\w|]*pos#\d[|])','indexed','[]','replace','');
%   selected_data=data index, 1 means previous generated data
%   common=string of common name expressiong
%   indexed=string of expression used to index or differentiate dataitems
%--------------------------------------------------------------------------
%   HEADER END
%% function complete

% assume worst
status=false;
% for batch process must return 'Data parentidx to childidx *' for each
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
            % need user input/confirm names
            prompt = {sprintf('Common part naming string\n%%s as placeholder for indexed part\n%%s only to use exiting name'),...
                'Indexed part naming string'};
            dlg_title = cat(2,'Data rename',obj.data(current_data).dataname);
            num_lines = 1;
            def = {'trial_%s_Ch1','[1:1:10]',''};
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            if ~isempty(answer)
                % make out automated naming using common and indexed part
                common=answer{1};
                if isempty(answer{2})
                    % don't want index?
                    indexed=char(' '*ones(1,numel(selected_data)));
                else
                    indexed=eval(answer{2});
                end
                replace=answer{3}
                if numel(indexed)==numel(selected_data)
                    % we are ok with the index

                else
                    % index doesn't match number of selected data
                    message=sprintf('%s\nSpecified index has %g elements does not match %g selected data.',message,numel(indexed),numel(selected_data));
                    return;
                end
            else
                % cancel clicked don't do anything to this data item
                common=[];indexed=[];replace=[];
                message=sprintf('%s\nAction cancelled!',message);
                return;
            end
            % for multiple data ask for apply to all option
            if numel(selected_data)>1
                % we always want to apply to rest
                askforparam=false;
            end
        else
            % user decided to apply same settings to rest or use default
            % assign parameters
            fname=defaultparam(1:2:end);
            fval=defaultparam(2:2:end);
            for fidx=1:numel(fname)
                switch fname{fidx}
                    case 'common'
                        common=fval{fidx};
                    case 'indexed'
                        indexed=eval(fval{fidx});
                    case 'replace'
                        replace=fval{fidx};
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
                waitbar_handle = waitbar(0,'Please wait...',...
                    'Name','Data Renaming',...
                    'Progress Bar','Calculating...',...
                    'CreateCancelBtn',...
                    'setappdata(gcbf,''canceling'',1)',...
                    'WindowStyle','normal',...
                    'Color',[0.2,0.2,0.2]);
                setappdata(waitbar_handle,'canceling',0);
            end
        end

        % ---- Data Calculation ----
        if isempty(common)
            % action cancelled
            return;
        else
            if ischar(replace)
                oldname=obj.data(current_data).dataname;
                newname=regexprep(oldname,common,replace);
            else
                if strcmp(common,'%s')
                    % use exiting name as backbone
                    oldname=obj.data(current_data).dataname;
                    newname=eval(cat(2,'sprintf(''',oldname,'_%s'',num2str(indexed(data_idx)));'));
                else
                    newname=eval(cat(2,'sprintf(''',common,''',num2str(indexed(data_idx)));'));
                end
            end
            obj.data(current_data).dataname=newname;

            % same data to same data for renaming
            message=sprintf('%s\nData %s to %s renamed',message,num2str(current_data),num2str(current_data));
        end

        % increment data index
        data_idx=data_idx+1;
        status=true;
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