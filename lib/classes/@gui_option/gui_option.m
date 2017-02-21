classdef ( ConstructOnLoad = true ) gui_option < handle
    %gui_option is user options storage class
    
    properties ( Constant )
        PANEL_NAME_LIST={'PANEL_DATA_dt','PANEL_DATA_MAP','PANEL_DATA_gT',...
            'PANEL_RESULT_param','PANEL_RESULT_MAP','PANEL_RESULT_gT',...
            'PANEL_aux'};
        COLOR_MAP_LIST={'jet','gray','colorcube','hsv','parula','hot','prism',...
            'cool','spring','summer','autumn','winter','bone','copper','pink','lines','flag'};
    end
    
    properties ( SetAccess = public, GetAccess = public )
        rootpath;%data root path storage
        usage;
        
        panel;%panel setting structure initialise at start
        current_panel=1;%current panel pointer
        panel_control_handle=[];%panel_control_gui handle
        panel_control_active=false;%status of panel_control_gui
        
        color_order;    %line plot color sequence
    end
    
    %---constructor functions---
    methods (Access = public)
        function obj=gui_option(varargin)
            % --- Various Root Folder Locations ---
            obj.rootpath.programme_path=cat(2,'.',filesep);
            obj.rootpath.icon_path=cat(2,'.',filesep,'gui_interfaces',filesep,'icons',filesep);
            obj.rootpath.userop=cat(2,'.',filesep,'usr',filesep,'ops',filesep);
                        
            obj.rootpath.raw_data=cat(2,pwd,filesep);
            obj.rootpath.saved_data=cat(2,pwd,filesep);
            obj.rootpath.exported_data=cat(2,pwd,filesep);
     
            obj.usage=cat(2,'.',filesep,'usr',filesep,'Manual.pdf');
            % --- Panel ---
            for panel_idx=1:1:numel(obj.PANEL_NAME_LIST)
                obj.panel(panel_idx).name=obj.PANEL_NAME_LIST{panel_idx};
                obj.panel(panel_idx).handle=[];     %panel handel
                obj.panel(panel_idx).label_handle=[];   %panel label handle
                obj.panel(panel_idx).Z_seq=false;%whether has Z Slice sequence
                obj.panel(panel_idx).T_seq=false;%whether has T Page sequence
                obj.panel(panel_idx).hold=false;    % is panel on hold
                obj.panel(panel_idx).norm=false;    % should plot be normalised
                obj.panel(panel_idx).xscale=[0,1,0,0];%[min,max,islog,isfix]
                obj.panel(panel_idx).xbound=[0,1,0,0];%[min,max,minlevel,maxlevel]
                obj.panel(panel_idx).yscale=[0,1,0,0];%[min,max,islog,isfix]
                obj.panel(panel_idx).ybound=[0,1,0,0];%[min,max,minlevel,maxlevel]
                obj.panel(panel_idx).zscale=[0,1,0,0];%[min,max,islog,isfix]
                obj.panel(panel_idx).zbound=[0,1,2,128];%[min,max,minlevel,maxlevel]
                obj.panel(panel_idx).cscale=[0,1,0,0];%[min,max,islog,isfix]
                obj.panel(panel_idx).cbound=[0,1,2,128];%[min,max,minlevel,maxlevel]
                obj.panel(panel_idx).colormap=obj.COLOR_MAP_LIST{panel_idx};     %panel handel
            end
            
            temp=load(cat(2,'.',filesep,'lib',filesep,'color_order.mat'),'-mat');
            obj.color_order=temp.cmap;
        end
    end
    
    % ----------------------------
    methods
        [ status, message, axeshandle, panel_idx ] = find_panels( obj, f_handle, panel );
        [ status, message, panel_handle ] = change_panel( obj, panel );
        [ status, message ] = update_panel_control( obj, action, varargin );
        [ status, message ] = export_panel( obj, panel_handle );
    end
end