function [ status, message ] = update_panel_control( obj, action, varargin )
% UPDATE_PANEL_CONTROL update information about plotting axes handle controls
%   valid input examples
%	('clear')
%	('hold',true|false)

%% function check

% assume worst
status=false;message='';

% get the handle for the current axes panel
panel_idx=obj.current_panel;	% only singular should be allowed here
panel_handle=obj.panel(panel_idx).handle;	% get the handle

if ishandle(panel_handle)
    % if current panel handle exist
    switch action
        case 'clear'
            % clear selected panels
            cla(panel_handle);	% clear axes
            set(panel_handle,'UserData',[]);
            % reset control values to default
            obj.panel(panel_idx).xscale=[0,1,0,0];
            obj.panel(panel_idx).yscale=[0,1,0,0];
            obj.panel(panel_idx).zscale=[0,1,0,0];
            obj.panel(panel_idx).cscale=[0,1,0,0];
            
            obj.panel(panel_idx).xbound=[0,1,0,0];
            obj.panel(panel_idx).ybound=[0,1,0,0];
            obj.panel(panel_idx).zbound=[0,1,2,512];
            obj.panel(panel_idx).cbound=[0,1,2,512];
            obj.panel(panel_idx).T_seq=false;
            obj.panel(panel_idx).Z_seq=false;
            
            if obj.panel_control_active
                % redisplays the controls
                obj.update_panel_control('display',obj.panel_control_handle);
            end
            panel_handle.Tag=obj.panel(panel_idx).name;
            % notify user
            message=sprintf('%s cleared\n',obj.panel(panel_idx).name);
            status=true;
        case 'hold'
            % change plot hold mode
            val=varargin{1};% get argument
            if val
                % hold on
                set(obj.panel(panel_idx).handle,'NextPlot','add');
                obj.panel(panel_idx).hold=true;
                % notify user
                message=sprintf('%s hold all\n',obj.panel(panel_idx).name);
            else
                % hold off
                set(obj.panel(panel_idx).handle,'NextPlot','replace');
                obj.panel(panel_idx).hold=false;
                % notify user
                message=sprintf('%s hold off\n',obj.panel(panel_idx).name);
            end
            status=true;
        case 'norm'
            % change plot normalisation mode
            val=varargin{1};% get argument
            if val
                obj.panel(panel_idx).norm=true;
            else
                obj.panel(panel_idx).norm=false;
            end
            status=true;
        case 'display'
            % display saved control parameters
            if obj.panel_control_active	% if we have opened panel control
                ui_handle=obj.panel_control_handle;
                if isstruct(ui_handle)% check validity
                    % panel name
                    set(ui_handle.MENU_PANEL,'Value',panel_idx);
                    
                    % x axis slider control
                    set(ui_handle.SLIDER_MINX,'Value',obj.panel(panel_idx).xscale(1));
                    set(ui_handle.SLIDER_MINX,'Min',obj.panel(panel_idx).xbound(1));
                    set(ui_handle.SLIDER_MINX,'Max',obj.panel(panel_idx).xbound(2));
                    set(ui_handle.VAL_MINX,'String',obj.panel(panel_idx).xscale(1));
                    set(ui_handle.VAL_XMINBOUND,'String',obj.panel(panel_idx).xbound(1));
                    set(ui_handle.SLIDER_MAXX,'Value',obj.panel(panel_idx).xscale(2));
                    set(ui_handle.SLIDER_MAXX,'Min',obj.panel(panel_idx).xbound(1));
                    set(ui_handle.SLIDER_MAXX,'Max',obj.panel(panel_idx).xbound(2));
                    set(ui_handle.VAL_MAXX,'String',obj.panel(panel_idx).xscale(2));
                    set(ui_handle.VAL_XMAXBOUND,'String',obj.panel(panel_idx).xbound(2));
                    set(ui_handle.TOGGLE_LOGX,'Value',obj.panel(panel_idx).xscale(3));
                    
                    % y axis slider control
                    set(ui_handle.SLIDER_MINY,'Value',obj.panel(panel_idx).yscale(1));
                    set(ui_handle.SLIDER_MINY,'Min',obj.panel(panel_idx).ybound(1));
                    set(ui_handle.SLIDER_MINY,'Max',obj.panel(panel_idx).ybound(2));
                    set(ui_handle.VAL_MINY,'String',obj.panel(panel_idx).yscale(1));
                    set(ui_handle.VAL_YMINBOUND,'String',obj.panel(panel_idx).ybound(1));
                    set(ui_handle.SLIDER_MAXY,'Value',obj.panel(panel_idx).yscale(2));
                    set(ui_handle.SLIDER_MAXY,'Min',obj.panel(panel_idx).ybound(1));
                    set(ui_handle.SLIDER_MAXY,'Max',obj.panel(panel_idx).ybound(2));
                    set(ui_handle.VAL_MAXY,'String',obj.panel(panel_idx).yscale(2));
                    set(ui_handle.VAL_YMAXBOUND,'String',obj.panel(panel_idx).ybound(2));
                    set(ui_handle.TOGGLE_LOGY,'Value',obj.panel(panel_idx).yscale(3));
                    
                    % z/c axis slider control
                    set(ui_handle.SLIDER_MINC,'Value',obj.panel(panel_idx).zscale(1));
                    set(ui_handle.SLIDER_MINC,'Min',obj.panel(panel_idx).zbound(1));
                    set(ui_handle.SLIDER_MINC,'Max',obj.panel(panel_idx).zbound(2));
                    set(ui_handle.VAL_MINC,'String',obj.panel(panel_idx).zscale(1));
                    set(ui_handle.VAL_CMINBOUND,'String',obj.panel(panel_idx).zbound(1));
                    set(ui_handle.SLIDER_MAXC,'Value',obj.panel(panel_idx).zscale(2));
                    set(ui_handle.SLIDER_MAXC,'Min',obj.panel(panel_idx).zbound(1));
                    set(ui_handle.SLIDER_MAXC,'Max',obj.panel(panel_idx).zbound(2));
                    set(ui_handle.VAL_MAXC,'String',obj.panel(panel_idx).zscale(2));
                    set(ui_handle.VAL_CMAXBOUND,'String',obj.panel(panel_idx).zbound(2));
                    set(ui_handle.TOGGLE_LOGC,'Value',obj.panel(panel_idx).zscale(3));
                    
                    
                    % hold toggle control
                    set(ui_handle.TOGGLE_HOLD,'Value',obj.panel(panel_idx).hold);
                    if obj.panel(panel_idx).hold
                        iconimg=imread(cat(2,obj.rootpath.icon_path,'holdon_icon.png'));
                    else
                        iconimg=imread(cat(2,obj.rootpath.icon_path,'holdoff_icon.png'));
                    end
                    set(ui_handle.TOGGLE_HOLD,'CData',iconimg);
                    
                    % norm toggle control
                    set(ui_handle.TOGGLE_NORM,'Value',obj.panel(panel_idx).norm);
                    if obj.panel(panel_idx).norm
                        iconimg=imread(cat(2,obj.rootpath.icon_path,'normon_icon.png'));
                    else
                        iconimg=imread(cat(2,obj.rootpath.icon_path,'normoff_icon.png'));
                    end
                    set(ui_handle.TOGGLE_NORM,'CData',iconimg);
                    
                    % colormap menu
                    colormapidx=find(strcmp(obj.COLOR_MAP_LIST,obj.panel(panel_idx).colormap));
                    set(ui_handle.MENU_COLORMAP,'Value',colormapidx);
                    
                    status=true;
                else
                    % couldn't find the correct type of handle structure
                    message=sprintf('Need valid panel handle\n');
                end
            else
                % no panel control open no need to update
                message=sprintf('Graphic Control Panel has not been opened\n');
            end
        case 'set'
            % set parameters
            for arg_idx=1:2:nargin-2
                field=varargin{arg_idx};% get field names
                val=varargin{arg_idx+1};% get field values
                if ~isnan(val)
                    % valid values
                    switch field
                        case 'xlim'
                            if obj.panel(panel_idx).xscale(4)
                                % scaled fixed do nothing
                                
                            else
                                if sum(isinf(val))==0
                                    val=sort(val);
                                    set(panel_handle,'XLim',val);
                                    obj.panel(panel_idx).xscale(1:2)=val;
                                    % update minimum bound
                                    obj.panel(panel_idx).xbound(1)=min(val(1),obj.panel(panel_idx).xbound(1));
                                    % update maximum bound
                                    obj.panel(panel_idx).xbound(2)=max(val(2),obj.panel(panel_idx).xbound(2));
                                end
                            end
                            status=true;
                        case 'ylim'
                            if obj.panel(panel_idx).yscale(4)
                                % scaled fixed do nothing
                                
                            else
                                if sum(isinf(val))==0
                                    val=sort(val);
                                    set(panel_handle,'YLim',val);
                                    obj.panel(panel_idx).yscale(1:2)=val;
                                    % update minimum bound
                                    obj.panel(panel_idx).ybound(1)=min(val(1),obj.panel(panel_idx).ybound(1));
                                    % update maximum bound
                                    obj.panel(panel_idx).ybound(2)=max(val(2),obj.panel(panel_idx).ybound(2));
                                end
                            end
                        case 'zlim'
                            if obj.panel(panel_idx).zscale(4)
                                % scaled fixed do nothing
                                
                            else
                                if sum(isinf(val))==0
                                    val=sort(val);
                                    set(panel_handle,'CLim',val);
                                    obj.panel(panel_idx).zscale(1:2)=val;
                                    % update minimum bound
                                    obj.panel(panel_idx).zbound(1)=min(val(1),obj.panel(panel_idx).zbound(1));
                                    % update maximum bound
                                    obj.panel(panel_idx).zbound(2)=max(val(2),obj.panel(panel_idx).zbound(2));
                                end
                            end
                        case 'xmin'
                            if obj.panel(panel_idx).xscale(4)
                                % scaled fixed do nothing
                                
                            else
                                % change scale settings
                                current_val=get(panel_handle,'XLim');
                                new_val=sort([val current_val(2)]);
                                if diff(new_val)==0
                                    % make sure scale works
                                    new_val(2)=new_val(2)+1e-6;
                                end
                                if ~isinf(new_val)
                                    set(panel_handle,'XLim',new_val);
                                    obj.panel(panel_idx).xscale(1:2)=new_val;
                                end
                                % update minimum bound
                                obj.panel(panel_idx).xbound(1)=min(new_val(1),obj.panel(panel_idx).xbound(1));
                            end
                            status=true;
                        case 'xmax'
                            if obj.panel(panel_idx).xscale(4)
                                % scaled fixed do nothing
                                
                            else
                                % change scale settings
                                current_val=get(panel_handle,'XLim');
                                new_val=sort([current_val(1) val]);
                                if diff(new_val)==0
                                    % make sure scale works
                                    new_val(2)=new_val(2)+1e-6;
                                end
                                if ~isinf(new_val)
                                    set(panel_handle,'XLim',new_val);
                                    obj.panel(panel_idx).xscale(1:2)=new_val;
                                end
                                % update maximum bound
                                obj.panel(panel_idx).xbound(2)=max(new_val(2),obj.panel(panel_idx).xbound(2));
                            end
                            status=true;
                        case 'xminbound'
                            % update minimum bound
                            if ~isinf(val)
                                obj.panel(panel_idx).xbound(1)=val;
                                % update xmin scale
                                obj.panel(panel_idx).xscale(1)=max(val,obj.panel(panel_idx).xscale(1));
                                status=true;
                            end
                        case 'xmaxbound'
                            % update maximum bound
                            if ~isinf(val)
                                obj.panel(panel_idx).xbound(2)=val;
                                % update xmin scale
                                obj.panel(panel_idx).xscale(2)=min(val,obj.panel(panel_idx).xscale(2));
                                status=true;
                            end
                        case 'ymin'
                            if obj.panel(panel_idx).yscale(4)
                                % scaled fixed do nothing
                                
                            else
                                % change scale settings
                                current_val=get(panel_handle,'YLim');
                                new_val=sort([val current_val(2)]);
                                if diff(new_val)==0
                                    % make sure scale works
                                    new_val(2)=new_val(2)+1e-6;
                                end
                                if ~isinf(new_val)
                                    set(panel_handle,'YLim',new_val);
                                    obj.panel(panel_idx).yscale(1:2)=new_val;
                                    % update minimum bound
                                    obj.panel(panel_idx).ybound(1)=min(new_val(1),obj.panel(panel_idx).ybound(1));
                                end
                            end
                            status=true;
                        case 'ymax'
                            if obj.panel(panel_idx).yscale(4)
                                % scaled fixed do nothing
                                
                            else
                                % change scale settings
                                current_val=get(panel_handle,'YLim');
                                new_val=sort([current_val(1) val]);
                                if diff(new_val)==0
                                    % make sure scale works
                                    new_val(2)=new_val(2)+1e-6;
                                end
                                if ~isinf(new_val)
                                    set(panel_handle,'YLim',new_val);
                                    obj.panel(panel_idx).yscale(1:2)=new_val;
                                    % update minimum bound
                                    obj.panel(panel_idx).ybound(2)=max(new_val(2),obj.panel(panel_idx).ybound(2));
                                end
                            end
                            status=true;
                        case 'yminbound'
                            % update minimum bound
                            if ~isinf(val)
                                obj.panel(panel_idx).ybound(1)=val;
                                % update ymin scale
                                obj.panel(panel_idx).yscale(1)=max(val,obj.panel(panel_idx).yscale(1));
                                status=true;
                            end
                        case 'ymaxbound'
                            % update maximum bound
                            if ~isinf(val)
                                obj.panel(panel_idx).ybound(2)=val;
                                % update ymax scale
                                obj.panel(panel_idx).yscale(2)=min(val,obj.panel(panel_idx).yscale(2));
                                status=true;
                            end
                        case 'zmin'
                            if obj.panel(panel_idx).zscale(4)
                                % scaled fixed do nothing
                                
                            else
                                % change scale settings
                                current_val=get(panel_handle,'CLim');
                                new_val=sort([val current_val(2)]);
                                if diff(new_val)==0
                                    % make sure scale works
                                    new_val(2)=new_val(2)+1e-6;
                                end
                                if ~isinf(new_val)
                                    set(panel_handle,'CLim',new_val);
                                    obj.panel(panel_idx).zscale(1:2)=new_val;
                                    % update minimum bound
                                    obj.panel(panel_idx).zbound(1)=min(new_val(1),obj.panel(panel_idx).zbound(1));
                                end
                            end
                            status=true;
                        case 'zmax'
                            if obj.panel(panel_idx).zscale(4)
                                % scaled fixed do nothing
                                
                            else
                                % change scale settings
                                current_val=get(panel_handle,'CLim');
                                new_val=sort([current_val(1) val]);
                                if diff(new_val)==0
                                    % make sure scale works
                                    new_val(2)=new_val(2)+1e-6;
                                end
                                if ~isinf(new_val)
                                    set(panel_handle,'CLim',new_val);
                                    obj.panel(panel_idx).zscale(1:2)=new_val;
                                    % update maximum bound
                                    obj.panel(panel_idx).zbound(2)=max(new_val(2),obj.panel(panel_idx).zbound(2));
                                end
                            end
                            status=true;
                        case 'zminbound'
                            % update minimum bound
                            if ~isinf(val)
                                obj.panel(panel_idx).zbound(1)=val;
                                % update ymin scale
                                obj.panel(panel_idx).zscale(1)=max(val,obj.panel(panel_idx).zscale(1));
                                status=true;
                            end
                        case 'zmaxbound'
                            % update maximum bound
                            if ~isinf(val)
                                obj.panel(panel_idx).zbound(2)=val;
                                % update ymin scale
                                obj.panel(panel_idx).zscale(2)=min(val,obj.panel(panel_idx).zscale(2));
                                status=true;
                            end
                        case 'xlog'
                            if val
                                set(panel_handle,'XScale','log');
                            else
                                set(panel_handle,'XScale','linear');
                            end
                            obj.panel(panel_idx).xscale(3)=val;
                            status=true;
                        case 'ylog'
                            if val
                                set(panel_handle,'YScale','log');
                            else
                                set(panel_handle,'YScale','linear');
                            end
                            obj.panel(panel_idx).yscale(3)=val;
                            status=true;
                        case 'zlog'
                            surfplot=findobj(panel_handle,'Type','surf');
                            if ~isempty(surfplot)
                                if val
                                    if size(get(surfplot,'CData'),3)>1
                                        beta=obj.panel(panel_idx).zscale(2);
                                        set(surfplot,'CData',brighten(get(surfplot,'CData'),beta));
                                    else
                                        set(surfplot,'ZData',log(get(surfplot,'ZData')));
                                    end
                                else
                                    if size(get(surfplot,'CData'),3)>1
                                        beta=obj.panel(panel_idx).zscale(2);
                                        set(surfplot,'CData',brighten(get(surfplot,'CData'),-beta));
                                    else
                                        set(surfplot,'ZData',exp(get(surfplot,'ZData')));
                                    end
                                end
                            end
                            obj.panel(panel_idx).zscale(3)=val;
                            status=true;
                        case 'xfix'
                            if val
                                set(panel_handle,'XLimMode','manual');
                            else
                                set(panel_handle,'XLimMode','auto');
                            end
                            obj.panel(panel_idx).xscale(4)=val;
                            status=true;
                        case 'yfix'
                            if val
                                set(panel_handle,'YLimMode','manual');
                            else
                                set(panel_handle,'YLimMode','auto');
                            end
                            obj.panel(panel_idx).yscale(4)=val;
                            status=true;
                        case 'zfix'
                            if val
                                set(panel_handle,'ZLimMode','manual');
                            else
                                set(panel_handle,'ZLimMode','auto');
                            end
                            obj.panel(panel_idx).zscale(4)=val;
                            status=true;
                        case 'cfix'
                            if val
                                set(panel_handle,'ZLimMode','manual');
                            else
                                set(panel_handle,'ZLimMode','auto');
                            end
                            obj.panel(panel_idx).cscale(4)=val;
                            status=true;
                        case 'T_seq'
                            if val
                                obj.panel(panel_idx).T_seq=true;
                            else
                                obj.panel(panel_idx).T_seq=false;
                            end
                            status=true;
                        case 'Z_seq'
                            if val
                                obj.panel(panel_idx).Z_seq=true;
                            else
                                obj.panel(panel_idx).Z_seq=false;
                            end
                            status=true;
                        case 'hControl'
                            
                        case 'colormap'
                            obj.panel(panel_idx).colormap=obj.COLOR_MAP_LIST{val};
                            colormap(obj.panel(panel_idx).handle,obj.panel(panel_idx).colormap);
                            status=true;
                        otherwise
                            message=sprintf('%sInvalid field to change\n',message);
                    end
                else
                    message=sprintf('%sInvalid value to change\n',message);
                end
            end
        otherwise
            message=sprintf('%s action unknown\n',action);
    end
else
    % panel handle somehow is missing
    message='Panel currently does not exist';
end

% display error dialogue if something went wrong
if status==false
    % display error message
    errordlg(message,'Errors','modal');
end