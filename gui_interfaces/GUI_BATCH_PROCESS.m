function varargout = GUI_BATCH_PROCESS(varargin)
% GUI_BATCH_PROCESS MATLAB code for GUI_BATCH_PROCESS.fig
%      GUI_BATCH_PROCESS, by itself, creates a new GUI_BATCH_PROCESS or raises the existing
%      singleton*.
%
%      H = GUI_BATCH_PROCESS returns the handle to a new GUI_BATCH_PROCESS or the handle to
%      the existing singleton*.
%
%      GUI_BATCH_PROCESS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GUI_BATCH_PROCESS.M with the given input arguments.
%
%      GUI_BATCH_PROCESS('Property','Value',...) creates a new GUI_BATCH_PROCESS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before GUI_BATCH_PROCESS_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to GUI_BATCH_PROCESS_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help GUI_BATCH_PROCESS

% Last Modified by GUIDE v2.5 01-May-2019 16:07:15

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @GUI_BATCH_PROCESS_OpeningFcn, ...
    'gui_OutputFcn',  @GUI_BATCH_PROCESS_OutputFcn, ...
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


% --- Executes just before GUI_BATCH_PROCESS is made visible.
function GUI_BATCH_PROCESS_OpeningFcn(hObject, ~, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI_BATCH_PROCESS (see VARARGIN)

% Choose default command line output for GUI_BATCH_PROCESS
handles.output = hObject;
% Update handles structure
guidata(hObject, handles);
global BATCHPROC SETTING;
BATCHPROC=struct('operation','wait for it',...
    'parameters',[]);
field=varargin(1:2:end);
val=varargin(2:2:end);
for fidx=1:numel(field)
    switch field{fidx}
        case 'hDATA'
            % Data handle
            datahandle=val{fidx};
        case 'selDATA'
            % selected data index
            handles.LIST_SELDATA.Value=val{fidx};
        case 'operator'
            handles.LIST_OPERATOR.String=val{fidx};
    end
end
handles.LIST_SELDATA.String={datahandle.data.dataname};
handles.LIST_OPERATOR.Value=1;
handles.LIST_BATCHPROCESS.String={BATCHPROC.operation};
handles.GUI_BATCH_PROCESS.UserData=datahandle;
iconimg=imread(cat(2,SETTING.rootpath.icon_path,'file_open.png'));
set(handles.BUTTON_OPEN,'CData',iconimg);
iconimg=imread(cat(2,SETTING.rootpath.icon_path,'file_save.png'));
set(handles.BUTTON_SAVE,'CData',iconimg);

% --- Outputs from this function are returned to the command line.
function varargout = GUI_BATCH_PROCESS_OutputFcn(~, ~, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

%--------------------------------------------------------------------------
%#ok<*DEFNU>
function BUTTON_OPEN_Callback(~, ~, handles)
% Open saved batch processing file (bpf)
global BATCHPROC SETTING;
% ask for file to open
[filename,pathname]=uigetfile('*.bpf','Select the batch process file',SETTING.rootpath.saved_data);
if ischar(pathname)
    % load file
    temp=load(cat(2,pathname,filename),'-mat');
    BATCHPROC=temp.BATCHPROC;
    % update LIST_BATCHPROCESS
    handles.LIST_BATCHPROCESS.String={BATCHPROC.operation};
    SETTING.rootpath.saved_data=pathname;
end

function BUTTON_SAVE_Callback(~, ~, ~)
% Save current settings to batch processing file (bpf)
global BATCHPROC SETTING; %#ok<NUSED>
[filename, pathname] = uiputfile({'*.bpf','Batch Process Files'},'Save as',SETTING.rootpath.saved_data);
if ischar(pathname)
    % save to file
    save(cat(2,pathname,filename),'BATCHPROC','-mat');
    SETTING.rootpath.saved_data=pathname;
end
% --------------------------------------------------------------------
% --- Executes on selection change in LIST_OPERATOR.
function LIST_OPERATOR_Callback(hObject, ~, handles)
% display operator help message
funcname=hObject.String{hObject.Value};
opnote=help(funcname);
handles.TEXT_FUNCINFO.String=opnote;

function BUTTON_ADDOP_Callback(~, ~, handles)
% Add selected operation from list_operator to list_batchprocess
global BATCHPROC;
selop=handles.LIST_OPERATOR.Value;
current_pos=handles.LIST_BATCHPROCESS.Value;
if current_pos==numel(BATCHPROC)
    BATCHPROC(end+1).operation=handles.LIST_OPERATOR.String{selop};
else
    temp=BATCHPROC(current_pos+1:end);
    BATCHPROC(current_pos+1).operation=handles.LIST_OPERATOR.String{selop};
    BATCHPROC(current_pos+1).parameters='';
    BATCHPROC(current_pos+2:end+1)=temp;
end
handles.LIST_BATCHPROCESS.String={BATCHPROC.operation};
handles.LIST_BATCHPROCESS.Value=handles.LIST_BATCHPROCESS.Value+1;

function BUTTON_DELOP_Callback(~, ~, handles)
% remove selected operation from list_batchprocess
global BATCHPROC;
selop=handles.LIST_BATCHPROCESS.Value;
if selop>1
    handles.LIST_BATCHPROCESS.String(selop)=[];
    BATCHPROC(selop)=[];
    handles.LIST_BATCHPROCESS.Value=min(handles.LIST_BATCHPROCESS.Value,numel(BATCHPROC));
    handles.LIST_BATCHPROCESS.String={BATCHPROC.operation};
end

function BUTTON_MOVEUP_Callback(~, ~, handles)
% move selected operations from list_batchprocess up the order tree
global BATCHPROC;
selop=handles.LIST_BATCHPROCESS.Value;
if selop>2
    % swap operations
    temp=BATCHPROC(selop-1);
    BATCHPROC(selop-1)=BATCHPROC(selop);
    BATCHPROC(selop)=temp;
    handles.LIST_BATCHPROCESS.String={BATCHPROC.operation};
    handles.LIST_BATCHPROCESS.Value=selop-1;
end

function BUTTON_MOVEDOWN_Callback(~, ~, handles)
% move selected operations from list_batchprocess down the order tree
global BATCHPROC;
selop=handles.LIST_BATCHPROCESS.Value;
if selop>1
    % if not the last one
    if selop<numel(BATCHPROC)
        % swap function strings
        temp=BATCHPROC(selop+1);
        BATCHPROC(selop+1)=BATCHPROC(selop);
        BATCHPROC(selop)=temp;
        handles.LIST_BATCHPROCESS.String={BATCHPROC.operation};
        handles.LIST_BATCHPROCESS.Value=selop+1;
    end
end

function LIST_BATCHPROCESS_Callback(hObject, ~, handles)
% load current process into parameter table
global BATCHPROC;
selop=hObject.Value;
if selop>1
    funcinfo=help(BATCHPROC(selop).operation);
    handles.TEXT_FUNCINFO.String=funcinfo;
    if isempty(BATCHPROC(selop).parameters)
        % find parameters definition line
        temp=regexp(funcinfo,'Parameter=struct(\S*);','match');
        % make it into BATCHPROC
        temp=regexprep(temp{1},'Parameter=','BATCHPROC(selop).parameters=');
        % evaluate
        eval(temp);
    end
    % Update parameter table
    handles.TABLE_PARAM.Data=[fieldnames(BATCHPROC(selop).parameters),struct2cell(BATCHPROC(selop).parameters)];
end

function TABLE_PARAM_CellEditCallback(hObject, eventdata, handles)
% update selected batch process operator parameters
global BATCHPROC;
selop=handles.LIST_BATCHPROCESS.Value;
if selop>1
    fidx=eventdata.Indices(1);
    fname=hObject.Data(fidx,1);
    BATCHPROC(selop).parameters.(fname{1})=eventdata.NewData;
end
%--------------------------------------------------------------------------
function BUTTON_PROCESS_Callback(~, ~, handles)
% acutally apply the whole batch process and wait for result
global BATCHPROC;
% get hDATA handle
datahandle=handles.GUI_BATCH_PROCESS.UserData;
% get selected index
seldata=num2str(handles.LIST_SELDATA.Value);
%---
% go through all the operations, ignoring the first one
for opidx=2:numel(BATCHPROC)
    % get function name
    funcname=BATCHPROC(opidx).operation;
    % get function argument
    funcarg=BATCHPROC(opidx).parameters;
    % see if we specified data or not
    switch funcarg.selected_data
        case '1'
            % default take previous generated data
        otherwise
            % otherwise use specified
            seldata=funcarg.selected_data;
    end
    % make cellarray of field,val pairs
    tempname=[fieldnames(funcarg),struct2cell(funcarg)]';
    tempname=sprintf('''%s'',',tempname{:});
    paramarg=sprintf('{%s}',tempname(1:end-1));
    % evaluate
    [~,success,message]=evalc(sprintf('%s(%s,[%s],false,%s)',funcname,'datahandle',seldata,paramarg));
    % find if we have new seldata index from message
    tempname=regexp(message,'(?<=Data )(([0-9])* to ([0-9])*)','match');
    newseldata=unique(cellfun(@(x)str2double(x{2}),regexp(tempname,' to ','split')));
    
    %[ success, message ]=datahandle.data_delete(seldata);
    seldata=num2str(newseldata);
end
% update data list
handles.LIST_SELDATA.String={datahandle.data.dataname};
handles.LIST_SELDATA.Value=newseldata;
%---

%--------------------------------------------------------------------------
function GUI_BATCH_PROCESS_CloseRequestFcn(hObject, ~, ~)
% close GUI and return control to MAIN_GUI
delete(hObject);
%--------------------------------------------------------------------------