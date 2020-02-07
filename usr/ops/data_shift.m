function [ status, message ] = data_shift( obj, selected_data, askforparam, defaultparam )
% DATA_SHIFT shift data in selected dimension
%--------------------------------------------------------------------------
%   1. Circular shift current data in any combination of t,X,Y,Z,T dimension
%
%   2. Input 1x5 vector for no of pixels to shift in each dimension
%
%   3. Shifted data will be moved to the end of other side
%
%   4. e.g. Input [0,-1,1,2,0] will shift 1 pixel to the left in x, one to
%   the right in y and two in z
%
%   5. SPC data not implementation yet
%
%---Batch process----------------------------------------------------------
%   Parameter=struct('selected_data','1','shift_size','[0,0,0,0,0]');
%   selected_data=data index, 1 means previous generated data
%   shift_size= 1x5 vector of element interval [-Inf,Inf] of integers
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
        if askforparam
            % get shifting dimension data
            prompt = {'Enter t shift pixel size',...
                'Enter X shift pixel size',...
                'Enter Y shift pixel size',...
                'Enter Z shift pixel size',...
                'Enter T shift pixel size'};
            dlg_title = cat(2,'Data bin sizes for',obj.data(current_data).dataname);
            num_lines = 1;
            def = {'0','0','0','0','0'};
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            if ~isempty(answer)
                shift_size=round(cellfun(@(x)str2double(x),answer));
            else
                shift_size=[];
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
            end
            % for multiple data ask for apply to all option
            if numel(selected_data)>1
                % ask if want to apply to the rest of the data items
                askforparam=askapplyall('apply');
            end
        else
            % user decided to apply same settings to rest or use default
            % assign parameters
            fname=defaultparam(1:2:end);
            fval=defaultparam(2:2:end);
            for fidx=1:numel(fname)
                switch fname{fidx}
                    case 'shift_size'
                        shift_size=round(str2num(fval{fidx}));
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
        if isempty(shift_size)
            %action cancelled
            message=sprintf('%s\nAction cancelled!',message);
        else
            %circular shift data around the specified dimension
            obj.data(current_data).dataval=circshift(obj.data(current_data).dataval,shift_size);
            obj.data(current_data).datainfo.last_change=datestr(now);
            status=true;
            message=sprintf('%s\nData %s to %s shifted by [%s] pixels in tXYZT-axis\n',message,num2str(current_data),num2str(current_data),num2str(shift_size));
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