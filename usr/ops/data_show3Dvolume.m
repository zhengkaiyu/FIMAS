function [ status, message ] = data_show3Dvolume( obj, selected_data, askforparam, defaultparam ) )
%data_show3Dvolume plot slice through 3D data to illustrate
%   function check for existing auxillary input channel from femtonics data
%   file .mes, user then select the channel to be plotted in an external
%   figure window and export the trace by press F3 key in the figure.

%% function incomplete
% assume worst
status=false;message='';
try
    % check data dimention is 3D
    r1=obj.data(selected_data).datainfo.X;
    r1_step=max(ceil(numel(r1)/50),2);
    r2=obj.data(selected_data).datainfo.Y;
    r2_step=max(ceil(numel(r2)/50),2);
    r3=obj.data(selected_data).datainfo.Z;
    r3_step=max(ceil(numel(r3)/20),2);
    % ask for slice intervals
    
    set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
    set(0,'DefaultUicontrolForegroundColor','k');
    s=inputdlg('intervals for x,y,z slice (e.g. [5,5,2]):','slice interval',1,{num2str([r1_step,r2_step,r3_step])});
    set(0,'DefaultUicontrolBackgroundColor','k');
    set(0,'DefaultUicontrolForegroundColor','w');
    if isempty(s)
        %cancelled
        message=sprintf('%s\n %s 3D volume plot cancelled\n',message,obj.data(selected_data).dataname);
    else
        slice_int=str2num(s{1});
        % ---- Calculation ----
        
        val=squeeze(obj.data(selected_data).dataval);
        [x,y,z]=meshgrid(r2,r1,r3);
        figure('Name',sprintf('3D volume plot for dataitem %s',obj.data(selected_data).dataname),...
            'NumberTitle','off',...
            'MenuBar','none',...
            'ToolBar','figure',...
            'Keypressfcn',@export_panel,...
            'Renderer','opengl');
        colormap('gray');
        h=slice(x,y,z,val,r2(1:slice_int(1):end),r1(1:slice_int(2):end),r3(1:slice_int(3):end),'cubic');
        alpha('color');
        set(h,'EdgeColor','none','FaceColor','interp','FaceAlpha','interp','Alphadatamapping','scaled');
        view([90,-40,30]);
        axis equal;
        xlabel('y');ylabel('x');zlabel('z');
        status=true;
    end
catch exception
    message=exception.message;
end

function export_panel(handle,eventkey)
global SETTING;
switch eventkey.Key
    case {'f3'}
        SETTING.export_panel(findobj(handle,'Type','Axes'));
end
