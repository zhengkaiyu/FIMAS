function display_data_operator( obj, output_handle, index )
%DISPLAY_DATA_ANALYSER output all related data analyser to user
%   if index is [] display the list of operators
%   if index is specified display the help content for that operator

%% function complete

% find all methods associated with the class
allfile=dir(cat(2,obj.path.userop,filesep,'*.m'));
[~,allmethods,~]=cellfun(@(x)fileparts(x),{allfile.name},'UniformOutput',false);
% find methods starts with op_ or data_
[~,found]=regexp(allmethods,'\<(op|data)_\w*','match');
found_idx=find(cellfun(@(x)~isempty(x),found));
if ~isempty(found_idx)
    if isempty(index)
        %display all found operators
        text=allmethods(found_idx);
    else
        %display help for selected operator
        text=help(allmethods{found_idx(index)});
    end
    if ishandle(output_handle)
        set(output_handle,'String',text);
    else
        if iscell(text)
            cellfun(@(x)fprintf('%s\n',x),text);
        else
            fprintf('%s\n',text);
        end
    end
else
    fprintf('no method was found\n');
end

