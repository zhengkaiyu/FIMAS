function varargout = GUI_GRAPH_CONTROL(varargin)
% GUI_GRAPH_CONTROL M-file for GUI_GRAPH_CONTROL.fig

% Edit the above text to modify the response to help GUI_GRAPH_CONTROL

% Last Modified by GUIDE v2.5 09-Dec-2014 16:38:41

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @GUI_GRAPH_CONTROL_OpeningFcn, ...
    'gui_OutputFcn',  @GUI_GRAPH_CONTROL_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before GUI_GRAPH_CONTROL is made visible.
function GUI_GRAPH_CONTROL_OpeningFcn(hObject, ~, handles, varargin)
% Choose default command line output for GUI_GRAPH_CONTROL
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

%initialise
global SETTING;
set(handles.MENU_PANEL,'String',{SETTING.panel.name});
set(handles.MENU_PANEL,'Value',SETTING.current_panel);
SETTING.panel_control_active=true;
SETTING.panel_control_handle=handles;
SETTING.update_panel_control('display');
iconimg=imread(cat(2,SETTING.rootpath.icon_path,'export_icon.jpg'));
set(handles.BUTTON_EXPORT,'CData',iconimg);
iconimg=imread(cat(2,SETTING.rootpath.icon_path,'clear_icon.png'));
set(handles.BUTTON_CLEAR,'CData',iconimg);
% change main window icon
javaFrame = get(handles.GC_PANEL,'JavaFrame');
javaFrame.setFigureIcon(javax.swing.ImageIcon(cat(2,SETTING.rootpath.icon_path,'main_icon.png')));

% --- Outputs from this function are returned to the command line.
function varargout = GUI_GRAPH_CONTROL_OutputFcn(~, ~, handles)
% Get default command line output from handles structure
varargout{1} = handles.output;
%======================================================================
%#ok<*DEFNU>
% --- Executes on selection change in MENU_PANEL.
function MENU_PANEL_Callback(hObject, ~, ~)
global SETTING;
panel_idx=get(hObject,'Value');
SETTING.change_panel(panel_idx);

%----------x-axis------------------
function SLIDER_MINX_Callback(hObject, ~, handles)
global SETTING;
val=get(hObject,'Value');
SETTING.update_panel_control('set','xmin',val);
set(handles.VAL_MINX,'String',val);

function SLIDER_MAXX_Callback(hObject, ~, handles)
global SETTING;
val=get(hObject,'Value');
SETTING.update_panel_control('set','xmax',val);
set(handles.VAL_MAXX,'String',val);

function VAL_MINX_Callback(hObject, ~, handles)
global SETTING;
val=str2double(get(hObject,'String'));
[valid,~]=SETTING.update_panel_control('set','xmin',val);
if valid
    set(handles.SLIDER_MINX,'Value',val);
else
    set(hObject,'Value',get(handles.SLIDER_MINX,'Value'));
end

function VAL_MAXX_Callback(hObject, ~, handles)
global SETTING;
val=str2double(get(hObject,'String'));
[valid,~]=SETTING.update_panel_control('set','xmax',val);
if valid
    set(handles.SLIDER_MAXX,'Value',val);
else
    set(hObject,'Value',get(handles.SLIDER_MAXX,'Value'));
end

function VAL_XMINBOUND_Callback(hObject, ~, handles)
global SETTING;
val=str2double(get(hObject,'String'));
[valid,~]=SETTING.update_panel_control('set','xminbound',val);
if valid
    set(handles.SLIDER_MINX,'Min',val);
    set(handles.SLIDER_MAXX,'Min',val);
else
    set(hObject,'Value',get(handles.SLIDER_MINX,'Min'));
end

function VAL_XMAXBOUND_Callback(hObject, ~, ~)
global SETTING;
val=str2double(get(hObject,'String'));
[valid,~]=SETTING.update_panel_control('set','xmaxbound',val);
if valid
    set(handles.SLIDER_MINX,'Max',val);
    set(handles.SLIDER_MAXX,'Max',val);
else
    set(hObject,'Value',get(handles.SLIDER_MINX,'Max'));
end

function TOGGLE_LOGX_Callback(hObject, ~, handles)
global SETTING;
val=get(hObject,'Value');
SETTING.update_panel_control('set','xlog',val);

% --- Executes on button press in TOGGLE_FIXXSCALE.
function TOGGLE_FIXXSCALE_Callback(hObject, ~, ~)
global SETTING;
val=get(hObject,'Value');
if val
    set(hObject,'String','Fix');
else
    set(hObject,'String','Auto');
end
SETTING.update_panel_control('set','xfix',val);
%----------y-axis------------------
function SLIDER_MINY_Callback(hObject, ~, handles)
global SETTING;
val=get(hObject,'Value');
SETTING.update_panel_control('set','ymin',val);
set(handles.VAL_MINY,'String',val);

function SLIDER_MAXY_Callback(hObject, ~, handles)
global SETTING;
val=get(hObject,'Value');
SETTING.update_panel_control('set','ymax',val);
set(handles.VAL_MAXY,'String',val);

function VAL_MINY_Callback(hObject, ~, handles)
global SETTING;
val=str2double(get(hObject,'String'));
[valid,~]=SETTING.update_panel_control('set','ymin',val);
if valid
    set(handles.SLIDER_MINY,'Value',val);
else
    set(hObject,'Value',get(handles.SLIDER_MINY,'Value'));
end

function VAL_MAXY_Callback(hObject, ~, handles)
global SETTING;
val=str2double(get(hObject,'String'));
[valid,~]=SETTING.update_panel_control('set','ymax',val);
if valid
    set(handles.SLIDER_MAXY,'Value',val);
else
    set(hObject,'Value',get(handles.SLIDER_MAXY,'Value'));
end

function VAL_YMINBOUND_Callback(hObject, ~, handles)
global SETTING;
val=str2double(get(hObject,'String'));
[valid,~]=SETTING.update_panel_control('set','yminbound',val);
if valid
    set(handles.SLIDER_MINY,'Min',val);
    set(handles.SLIDER_MAXY,'Min',val);
else
    set(hObject,'Value',get(handles.SLIDER_MINY,'Min'));
end

function VAL_YMAXBOUND_Callback(hObject, ~, handles)
global SETTING;
val=str2double(get(hObject,'String'));
[valid,~]=SETTING.update_panel_control('set','ymaxbound',val);
if valid
    set(handles.SLIDER_MINY,'Max',val);
    set(handles.SLIDER_MAXY,'Max',val);
else
    set(hObject,'Value',get(handles.SLIDER_MINY,'Max'));
end

function TOGGLE_LOGY_Callback(hObject, ~, ~)
global SETTING;
val=get(hObject,'Value');
SETTING.update_panel_control('set','ylog',val);

function TOGGLE_FIXYSCALE_Callback(hObject, ~, ~)
global SETTING;
val=get(hObject,'Value');
if val
    set(hObject,'String','Fix');
else
    set(hObject,'String','Auto');
end
SETTING.update_panel_control('set','yfix',val);

%----------z/c-axis------------------
function SLIDER_MINC_Callback(hObject, ~, handles)
global SETTING;
val=get(hObject,'Value');
SETTING.update_panel_control('set','zmin',val);
set(handles.VAL_MINC,'String',val);

function SLIDER_MAXC_Callback(hObject, ~, handles)
global SETTING;
val=get(hObject,'Value');
SETTING.update_panel_control('set','zmax',val);
set(handles.VAL_MAXC,'String',val);

function VAL_MINC_Callback(hObject, ~, handles)
global SETTING;
val=str2double(get(hObject,'String'));
[valid,~]=SETTING.update_panel_control('set','zmin',val);
if valid
    set(handles.SLIDER_MINC,'Value',val);
else
    set(hObject,'Value',get(handles.SLIDER_MIN,'Value'));
end

function VAL_MAXC_Callback(hObject, ~, handles)
global SETTING;
val=str2double(get(hObject,'String'));
[valid,~]=SETTING.update_panel_control('set','zmax',val);
if valid
    set(handles.SLIDER_MAXC,'Value',val);
else
    set(hObject,'Value',get(handles.SLIDER_MAXC,'Value'));
end

function VAL_CMINBOUND_Callback(hObject, ~, handles)
global SETTING;
val=str2double(get(hObject,'String'));
[valid,~]=SETTING.update_panel_control('set','zminbound',val);
if valid
    set(handles.SLIDER_MINC,'Min',val);
    set(handles.SLIDER_MAXC,'Min',val);
else
    set(hObject,'Value',get(handles.SLIDER_MINC,'Min'));
end

function VAL_CMAXBOUND_Callback(hObject, ~, handles)
global SETTING;
val=str2double(get(hObject,'String'));
[valid,~]=SETTING.update_panel_control('set','zmaxbound',val);
if valid
    set(handles.SLIDER_MINC,'Max',val);
    set(handles.SLIDER_MAXC,'Max',val);
else
    set(hObject,'Value',get(handles.SLIDER_MINC,'Max'));
end

function TOGGLE_LOGC_Callback(hObject, ~, ~)
global SETTING;
val=get(hObject,'Value');
SETTING.update_panel_control('set','zlog',val);

% --- Executes on button press in TOGGLE_FIXCSCALE.
function TOGGLE_FIXCSCALE_Callback(hObject, ~, ~)
global SETTING;
val=get(hObject,'Value');
if val
    set(hObject,'String','Fix');
else
    set(hObject,'String','Auto');
end
SETTING.update_panel_control('set','zfix',val);

%----------buttons------------------
function TOGGLE_HOLD_Callback(hObject, ~, ~)
global SETTING;
val=get(hObject,'Value');
if val
    iconimg=imread(cat(2,SETTING.rootpath.icon_path,'holdon_icon.png'));
else
    iconimg=imread(cat(2,SETTING.rootpath.icon_path,'holdoff_icon.png'));
end
set(hObject,'CData',iconimg);
SETTING.update_panel_control('hold',val);

function TOGGLE_NORM_Callback(hObject, ~, ~)
global SETTING;
val=get(hObject,'Value');
if val
    iconimg=imread(cat(2,SETTING.rootpath.icon_path,'normon_icon.png'));
else
    iconimg=imread(cat(2,SETTING.rootpath.icon_path,'normoff_icon.png'));
end
set(hObject,'CData',iconimg);
SETTING.update_panel_control('norm',val);


function BUTTON_CLEAR_Callback(~, ~, handles)
global SETTING;
SETTING.update_panel_control('clear',handles);

function BUTTON_EXPORT_Callback(~, ~, ~)
global SETTING;
SETTING.export_panel;

%===========================================================
% --- Executes when user attempts to close GC_PANEL.
function GC_PANEL_CloseRequestFcn(hObject, ~, ~)
global SETTING;
SETTING.panel_control_active=false;
SETTING.panel_control_handle=[];
delete(hObject);
%===========================================================
