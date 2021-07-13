function [ status, message ] = data_batchexport( obj, selected_data, askforparam, defaultparam )
%DATA_BATCHEXPORT EXPORT INDIVIDUAL dataitem, use for batch processing
%--------------------------------------------------------------------------
%   1. Can be used for batch exporting with using fimdata_handle.data_export
%
%   2. Main purpose is to maintain data index for batch processing
%
%---Batch process----------------------------------------------------------
%   Parameter=struct('selected_data','1','format','edf','directory','','bundle','true');
%   selected_data=data index, 1 means previous generated data
%   format=mat|edf|tiff|tif|TIFF|TIF
%   directory=path to which data are exported, default '' uses global path
%   bundle=0|1, as a single file bundle or separate individual files
%--------------------------------------------------------------------------
%   HEADER END
%% function complete
global SETTING;
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
            prompt = {sprintf('format (mat,edf,tiff)'),'export path','bundle'};
            dlg_title = 'Data batch export';
            num_lines = 1;
            def = {'edf',SETTING.rootpath.exported_data,'true'};
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            if ~isempty(answer)
                switch answer{1}
                    case {'mat','edf','tiff','TIFF','tif','TIF'}
                        exportformat=answer{1};
                    otherwise
                        exportformat='edf';
                end
                if isempty(answer{2})||~isdir(answer{2})
                    exportpath=SETTING.rootpath.exported_data;
                else
                    exportpath=answer{2};
                end
                switch answer{3}
                    case {'1','true'}
                        bundle=true;
                    otherwise
                        bundle=false;
                end
                % for multiple data ask for apply to all option
                if ~bundle && numel(selected_data)>1
                    askforparam=askapplyall('apply');
                end
            else
                exportformat=[];exportpath=[];
            end
        else
            % user decided to apply same settings to rest or use default
            % assign parameters
            fname=defaultparam(1:2:end);
            fval=defaultparam(2:2:end);
            for fidx=1:numel(fname)
                switch fname{fidx}
                    case 'format'
                        switch fval{fidx}
                            case {'mat','edf','tiff','TIFF','tif','TIF'}
                                exportformat=fval{fidx};
                            otherwise
                                exportformat='edf';
                        end
                    case 'directory'
                        if isempty(fval{fidx})||~isdir(fval{fidx})
                            exportpath=SETTING.rootpath.exported_data;
                        else
                            exportpath=fval{fidx};
                        end
                    case 'bundle'
                        switch fval{fidx}
                            case {'1','true'}
                                bundle=true;
                            otherwise
                                bundle=false;
                        end
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
                    'Name','Data Exporting',...
                    'Progress Bar','Calculating...',...
                    'CreateCancelBtn',...
                    'setappdata(gcbf,''canceling'',1)',...
                    'WindowStyle','normal',...
                    'Color',[0.2,0.2,0.2]);
                setappdata(waitbar_handle,'canceling',0);
            end
        end
        
        if isempty(exportpath)
            % decided to cancel action
            if numel(selected_data)>1
                askforparam=askapplyall('cancel');
                if askforparam==false
                    % quit if in automated mode
                    message=sprintf('%s\nAction cancelled!',message);
                    return;
                end
            else
                message=sprintf('%sAction cancelled!',message);
            end
        else
            % ---- Data Calculation ----
            if bundle
                % export as one file
                % make filename
                filename=sprintf('%s%s%s_bundle.%s',exportpath,filesep,obj.data(selected_data(1)).dataname,exportformat);
                % export
                obj.data_export(selected_data,filename);
                message=sprintf('%s\nData %s to %s exported',message,num2str(selected_data),num2str(current_data));
                status=true;
                % close waitbar if exist
                if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
                    delete(waitbar_handle);
                end
                return;
            else
                % make filename
                filename=sprintf('%s%s%s.%s',exportpath,filesep,obj.data(current_data).dataname,exportformat);
                % export
                obj.data_export(current_data,filename);
                message=sprintf('%s\nData %s to %s exported',message,num2str(current_data),num2str(current_data));
            end
        end
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