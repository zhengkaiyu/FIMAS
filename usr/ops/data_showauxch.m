function [ status, message ] = data_showauxch( obj, selected_data )
%DATA_SHOWAUXCH plot auxillary channel from femtonics data file
%   function check for existing auxillary input channel from femtonics data
%   file .mes, user then select the channel to be plotted in an external
%   figure window and export the trace by press F3 key in the figure.

%% function complete
% assume worst
status=false;message='';
try
    %find existing AUXi channels
    fnames=fieldnames(obj.data(selected_data).metainfo);
    temp=regexp(fnames,'AUXi\w*','match');
    ch_present=fnames(cellfun(@(x)~isempty(x),temp));
    if isempty(ch_present)
        %ask for channel
        message=sprintf('%s\n %s has no auxillary channel\n',message,obj.data(selected_data).dataname);
    else
        set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
        set(0,'DefaultUicontrolForegroundColor','k');
        [s,~] = listdlg('PromptString','Select Auxillary Channel:',...
            'SelectionMode','single',...
            'ListString',ch_present,...
            'OkString','Select',...
            'InitialValue',2);
        set(0,'DefaultUicontrolBackgroundColor','k');
        set(0,'DefaultUicontrolForegroundColor','w');
        if isempty(s)
            %cancelled
            message=sprintf('%s\n %s cancelled\n',message,obj.data(selected_data).dataname);
        else
            channel=ch_present{s};
            if isempty(obj.data(selected_data).metainfo.(channel))
                message=sprintf('%s\n %s has no auxillary data\n',message,obj.data(selected_data).dataname);
            else
                % ---- Calculation ----
                x=obj.data(selected_data).metainfo.(channel).x;
                y=obj.data(selected_data).metainfo.(channel).y;
                xunit=obj.data(selected_data).metainfo.(channel).xunit;
                yunit=obj.data(selected_data).metainfo.(channel).yunit;
                npts=numel(y);
                t=linspace(x(1),x(2)*npts,npts);
                figure('Name',sprintf('%s from data item %s',channel,obj.data(selected_data).dataname),...
                    'NumberTitle','off',...
                    'MenuBar','none',...
                    'ToolBar','figure',...
                    'Keypressfcn',@export_panel);
                plot(t,y,'k-','LineWidth',2);
                xlabel(gca,sprintf('%s (%s)',obj.data(selected_data).metainfo.(channel).xname,xunit));
                ylabel(gca,sprintf('%s (%s)',obj.data(selected_data).metainfo.(channel).yname,yunit));
                title(gca,sprintf('%s from data item %s',channel,obj.data(selected_data).dataname),'Interpreter','none','FontSize',10);
                % ask if want to save this to a new data item
                options.Interpreter = 'tex';
                % Include the desired Default answer
                options.Default = 'Save';
                options.WindowStyle='modal';
                button=questdlg('Do you want the line plot data saved as a new dataitem?>','Auxilary Channel Data','Save','Cancel',options);
                switch button
                    case {'Cancel',''}
                        % if user cancelled action
                        message=sprintf('%s\n','exporting trace cancelled');
                    case 'Save'
                        parent_data=obj.current_data;
                        % add new data
                        obj.data_add(cat(2,'Auxch|',obj.data(parent_data).dataname),[],[]);
                        % get new data index
                        current_data=obj.current_data;
                        % pass on metadata info
                        obj.data(current_data).metainfo=obj.data(parent_data).metainfo;
                        % pass on datainfo
                        obj.data(current_data).datainfo=obj.data(parent_data).datainfo;
                        % set data index
                        obj.data(current_data).datainfo.data_idx=current_data;
                        % set parent data index
                        obj.data(current_data).datainfo.parent_data_idx=parent_data;
                        obj.data(current_data).datainfo.operator='data_showauxch';
                        obj.data(current_data).datainfo.aux_channel=channel;
                        obj.data(current_data).datainfo.T=t;
                        obj.data(current_data).dataval(1,1,1,1,:)=y;
                        obj.data(current_data).datainfo.data_dim=[1,1,1,1,numel(y)];
                        obj.data(current_data).datatype=obj.get_datatype(current_data);
                        obj.data(current_data).datainfo.last_change=datestr(now);
                        %return focus to parent data
                        obj.current_data=parent_data;
                end
                status=true;
            end
        end
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
