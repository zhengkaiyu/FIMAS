function [ status, message, axeshandle, panel_idx ] = find_panels( obj, f_handle, panel )
%FIND_PANELS get all the panel parameters and assign values
% f_handle: figure handle
% name: name of the axes, if empty find all axes in the figure

%% function complete
status=false;message='';
% find the new panel
if isempty(panel)
    % empty input
    %assign panel handles
    fname=fieldnames(f_handle);
    panel_idx=find(cellfun(@(x)~isempty(x),regexp(fname,'\<PANEL_\w*','match')));
    panel_names={obj.panel.name};
    %loop through all the panels
    for p_idx=1:1:numel(panel_idx)
        matched_idx=strmatch(fname{panel_idx(p_idx)},panel_names);
        obj.panel(matched_idx).handle=f_handle.(fname{panel_idx(p_idx)});
        %get standard label name
        handlename=cat(2,'LABEL_',fname{panel_idx(p_idx)});
        if isfield(f_handle,handlename)
            %get label handle
            label=f_handle.(cat(2,'LABEL_',fname{panel_idx(p_idx)}));
            if ishandle(label)
                %assign label handle
                obj.panel(matched_idx).label_handle=label;
            end
        else
            %panel has no label
            obj.panel(matched_idx).label_handle=[];
        end
        message=sprintf('panel %s found\n',fname{panel_idx(p_idx)});
        status=true;
    end
elseif ishandle(panel)
    % panel handle passed in and find the corresponding panel
    panel_idx=find(cell2mat(cellfun(@(x)~isempty(x)&&(x==panel),{obj.panel.handle},'UniformOutput',false)));
elseif isnumeric(panel)
    % panel index passed in
    panel_idx=panel;
elseif ischar(panel)
    % panel name passed in find the corresponding panel
    panel_idx=find(cell2mat(cellfun(@(x)strcmp(panel,x),{obj.panel.name},'UniformOutput',false)));
end
if isempty(panel_idx)
    axeshandle=[];
elseif ~isempty(panel)
    axeshandle=obj.panel(panel_idx).handle;
    status=true;
end