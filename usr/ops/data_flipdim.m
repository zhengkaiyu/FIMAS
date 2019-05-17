function [ status, message ] = data_flipdim( obj, selected_data, askforparam, defaultparam )
% DATA_FLIPDIM Flipimages upside down in selected dimension
%--------------------------------------------------------------------------
%   1. Flip images in either t,X,Y,Z or T dimension
%
%   2. SPC data not implementation yet, although not difficult
%
%---Batch process----------------------------------------------------------
%   Parameter=struct('selected_data','1','dim','1');
%   selected_data=data index, 1 means previous generated data
%   dim=[1|2|3|4|5];
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
                    dim=[];
            end
            if isempty(dim)
                % action cancelled previously
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
        if isempty(dim)
            %action cancelled
            message=sprintf('%s\nAction cancelled!',message);
        else
            % flip data upside down along the dimension
            obj.data(current_data).dataval=flip(obj.data(current_data).dataval,dim);
            % flip dimension information
            obj.data(current_data).datainfo.(obj.DIM_TAG{dim})=flip(obj.data(current_data).datainfo.(obj.DIM_TAG{dim}));
            % update change time
            obj.data(current_data).datainfo.last_change=datestr(now);
            status=true;
            message=sprintf('%s\nData %s to %s flipped along %s-axis.',message,num2str(current_data),num2str(current_data),obj.DIM_TAG{dim});
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