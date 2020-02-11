function [ status, message ] = data_rearrangedim( obj, selected_data, askforparam, defaultparam )
% DATA_REARRANGEDIM permutes dimensions of a 5D data
%--------------------------------------------------------------------------
%   1. Input 1x5 permutation vector for dimension index
%
%   2. Operation will apply to the current data selected and process is reversible
%
%   3. e.g. Input [1,2,5,4,3] will change a tXYZT data to tXTZY and apply again to reverse back
%
%   4. SPC data not implementation yet
%
%---Batch process----------------------------------------------------------
%   Parameter=struct('selected_data','1','new_dim','[1,2,3,4,5]');
%   selected_data=data index, 1 means previous generated data
%   new_dim= 1x5 vector of element interval [1,5]
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
        % get current data index
        current_data=selected_data(data_idx);
        % ---- Parameter Assignment ----
        if askforparam
            % ask for user input
            options.Resize='on';options.WindowStyle='modal';options.Interpreter='tex';
            answer = inputdlg(sprintf('swap dimensions using dim index [1,2,3,4,5]=[t,X,Y,Z,T]\nThis operation will apply to data %s',num2str(selected_data)),...
                'Swap Dimensions',1,...
                {'[1,2,3,4,5]'},options);
            if ~isempty(answer)
                % swap dim, assuming user knows what they are doing
                new_dim=eval(answer{1});
            else
                % cancel clicked don't do anything to this data item
                new_dim=[];
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
                    case 'new_dim'
                        new_dim=str2num(fval{fidx});
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
                    'Name','Data Rearrange dimensions',...
                    'Progress Bar','Calculating...',...
                    'CreateCancelBtn',...
                    'setappdata(gcbf,''canceling'',1)',...
                    'WindowStyle','normal',...
                    'Color',[0.2,0.2,0.2]);
                setappdata(waitbar_handle,'canceling',0);
            end
        end
        
        % ---- Data Calculation ----
        if isempty(new_dim)
            message=sprintf('%s\nData swap action cancelled',message);
        else
            % check validity
            old_dim=obj.data(current_data).datainfo.data_dim;
            obj.data(current_data).datainfo.data_dim=obj.data(current_data).datainfo.data_dim(new_dim);
            newtype=obj.get_datatype(current_data);
            if isempty(newtype)
                %invalid swap happenend
                new_dim=[];% don't do anything later on
                obj.data(current_data).datainfo.data_dim=old_dim;
                message=sprintf('%s\nInvalid swap',message);
            else
                %do actual swap of value
                obj.data(current_data).dataval=permute(obj.data(current_data).dataval,new_dim);
                %get old order
                old_axis={obj.data(current_data).datainfo.t,...
                    obj.data(current_data).datainfo.X,...
                    obj.data(current_data).datainfo.Y,...
                    obj.data(current_data).datainfo.Z,...
                    obj.data(current_data).datainfo.T};
                %get delta axis values as well which need to be swapped
                old_daxis={obj.data(current_data).datainfo.dt,...
                    obj.data(current_data).datainfo.dX,...
                    obj.data(current_data).datainfo.dY,...
                    obj.data(current_data).datainfo.dZ,...
                    obj.data(current_data).datainfo.dT};
                %do actual swap of axes
                for dim_idx=1:5
                    if new_dim(dim_idx)~=dim_idx
                        %change
                        old_dim_tag=char(obj.DIM_TAG(dim_idx));
                        obj.data(current_data).datainfo.(old_dim_tag)=old_axis{new_dim(dim_idx)};
                        obj.data(current_data).datainfo.(cat(2,'d',old_dim_tag))=old_daxis{new_dim(dim_idx)};
                    end
                end
                % swap display dim as well
                obj.data(current_data).datainfo.display_dim=obj.data(current_data).datainfo.display_dim(new_dim);
                % assign new type property
                obj.data(current_data).datatype=newtype;
                % assign last change date
                obj.data(current_data).datainfo.last_change=datestr(now);
                %return true
                status=true;
                message=sprintf('%s\nData %s to %s swapped %s dimension.',message,num2str(current_data),num2str(current_data),char(obj.DIM_TAG(new_dim)));
            end
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
    % make sure the data_dim is returned to old one if there is a problem
    obj.data(current_data).datainfo.data_dim=old_dim;
end