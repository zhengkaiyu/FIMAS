function varargout = GUI_EQUATION_EDITOR(varargin)
% GUI_EQUATION_EDITOR M-file for GUI_EQUATION_EDITOR.fig

% Last Modified by GUIDE v2.5 03-Dec-2014 16:56:17

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @GUI_EQUATION_EDITOR_OpeningFcn, ...
    'gui_OutputFcn',  @GUI_EQUATION_EDITOR_OutputFcn, ...
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

% --- Executes just before GUI_EQUATION_EDITOR is made visible.
function GUI_EQUATION_EDITOR_OpeningFcn(hObject, eventdata, handles, varargin)
% Choose default command line output for GUI_EQUATION_EDITOR
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

global hDATA;
colformat={'char',{hDATA.data.dataname}};
func_str=hDATA.data(hDATA.current_data).datainfo.op_func;
func_comp=regexp(func_str,'[(|,|)]','split');
if strmatch(func_comp(1),'@')
    % correct function start
    varname=func_comp(2:end-1)';
    func_str=func_comp{end};
end
input_list=colformat{2}(hDATA.data(hDATA.current_data).datainfo.input_list);
if isempty(input_list)
    input_list=colformat{2}(1:numel(varname));
end
set(handles.TABLE_VARIABLE,'ColumnFormat',colformat);
set(handles.TABLE_VARIABLE,'Data',[varname,input_list(:)]);
set(handles.EDIT_EQUATION,'String',func_str);

% --- Outputs from this function are returned to the command line.
function varargout = GUI_EQUATION_EDITOR_OutputFcn(hObject, eventdata, handles)
% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in BUTTON_OK.
function BUTTON_OK_Callback(~, ~, handles)
global hDATA;
func_str=get(handles.EDIT_EQUATION,'String');
table_data=get(handles.TABLE_VARIABLE,'Data');
for var_idx=1:size(table_data,2)
    input_list(var_idx)=find(cellfun(@(x)~isempty(x),(strfind({hDATA.data.dataname},table_data{var_idx,2})))); %#ok<AGROW>
end
varname=table_data(:,1);
hDATA.data(hDATA.current_data).datainfo.op_func=sprintf('@(%s%s)%s',sprintf('%s,',varname{1:end-1}),varname{end},func_str);
hDATA.data(hDATA.current_data).datainfo.input_list=input_list;

% --- Executes when user attempts to close GUI_EQUATION_EDITOR.
function GUI_EQUATION_EDITOR_CloseRequestFcn(hObject, eventdata, handles)
delete(hObject);
