function [ status, message ] = data_batchdelete( obj, selected_data, askforparam, defaultparam )
%DATA_BATCHDELETE delete dataitem, use for batch processing
%--------------------------------------------------------------------------
%   1. Can be used for batch deleting with using fimdata_handle.data_delete
%
%   2. Main purpose is to maintain data index for batch processing
%
%   3. current data index will be reset to 1 (i.e. template) afterwards so for batch processing, the next operation will need to explicitly specify the selected_data field
%
%   4. It is highly likely the index of data to delete is not previous selected (i.e. 1) you will need to specify explicitly the data to delete. e.g. 5:1:20  another e.g. 3:2:20
%
%---Batch process----------------------------------------------------------
%   Parameter=struct('selected_data','1');
%   selected_data=data index, 1 means previous generated data
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
    
    % ---- Parameter Assignment ----
    % if it is not automated, we need manual parameter input/adjustment
    if askforparam
        % need user input/confirm names
        prompt = {sprintf('Batch data delete %s',sprintf('%s; ',obj.data(selected_data).dataname))};
        dlg_title = 'Batch Delete Data';
        def = 'Yes';
        set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
        set(0,'DefaultUicontrolForegroundColor','k');
        answer = questdlg(prompt,dlg_title,'Yes','No',def);
        set(0,'DefaultUicontrolBackgroundColor','k');
        set(0,'DefaultUicontrolForegroundColor','w');
        switch answer
            case 'Yes'
                % yes batch delete selected data
                
            case 'No'
                % cancel clicked don't do anything to this data item
                message=sprintf('%s\nAction cancelled!',message);
                return;
        end
    else
       
    end
    
    % ---- Data Calculation ----
    obj.data_delete(selected_data);
    while data_idx<=ndata
        current_data=selected_data(data_idx);
        message=sprintf('%s\nData %s to %s deleted',message,num2str(current_data),num2str(1));
        data_idx=data_idx+1;
    end
    
    status=true;
    obj.current_data=1;
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