function [ status, message, panel_handle ] = change_panel( obj, panel )
%CHANGE_PANEL change selected panel
%   label and corresponding changes need to happen

%% function complete

% assume worst
status=false;

% change old panel label background to black
set(obj.panel(obj.current_panel).label_handle,'BackgroundColor',[0.3,0.3,0.3]);

% avoid handle confusion
if panel==1
    panel_idx=panel;
else
    [~,~,panel_handle,panel_idx]=obj.find_panels([],panel);    
end

% if we have found the new panel
if ~isempty(panel_idx)
    % change current panel to selected
    obj.current_panel=panel_idx;
    % change selected panel label background to red
    set(obj.panel(panel_idx).label_handle,'BackgroundColor','r');
    
    % return success
    status=true;
    message=sprintf('changed to panel: %s',obj.panel(panel_idx).name);
    
    % update panel control if opened
    if obj.panel_control_active
        obj.update_panel_control('display');
    end
else
    obj.panel(end).handle=panel;% assign it to aux panel
    message=sprintf('panel not found\n');
end