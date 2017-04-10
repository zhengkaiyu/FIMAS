function update_info( message, overwrite, handles)
% UPDATE_INFO Changes strings of handles 
%	particularly for display in edit box handles
% --- update information panel ---
%  Usage: update_info(sprintf('%s\n','message'),1,object_handle);
%	no error handling in this function


%% function complete
if overwrite
    % overwrite existing text
    set(handles,'String',{message});
else
    % append to existing text
    original = get(handles,'String');%get original text
    set(handles,'String',[{message};original]);%append and output
end

% pause so we can see the update
%pause(0.001);
