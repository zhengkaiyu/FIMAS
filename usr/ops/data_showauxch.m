function [ status, message ] = data_showauxch( obj, selected_data, askforparam, defaultparam )
% DATA_SHOWAUXCH plot auxillary input channel from femtonics data file
%--------------------------------------------------------------------------
%   1. Function check for existing auxillary input channel from femtonics data file .mes.
%
%   2. User then select the channel to be plotted in an external figure window and export the trace by press F3 key in the figure.
%
%   3. In batch mode, data are automatically saved as new dataitem
%
%---Batch process----------------------------------------------------------
%   Parameter=struct('selected_data','1','channel','AnI1Cal','savetrace','true','displaytrace','false');
%   selected_data=data index, 1 means previous generated data
%   channel=AnI1Cal; default selection of femtonics AUXi%i AnI%iCal
%	savetrace=true|false; save aux channel data to new dataitem
%	displaytrace=true|false; display aux channel data to new figure window
%--------------------------------------------------------------------------
%   HEADER END

%% function complete
% assume worst
status=false;
% for batch process must return 'Data parentidx to childidx *' for each
% successful calculation
message='';
try
    % initialise counter
    data_idx=1;
    % number of data to process
    ndata=numel(selected_data);
    % loop through individual data
    while data_idx<=ndata
        % get the current data index
        current_data=selected_data(data_idx);
        % ---- Parameter Assignment ----
        % if it is not automated, we need manual parameter input/adjustment
        if askforparam
            %find existing AUXi channels
            fnames=fieldnames(obj.data(current_data).metainfo);
            temp=regexp(fnames,'(AUXi|AnI)\d+','match');
            ch_present=fnames(cellfun(@(x)~isempty(x),temp));
            if isempty(ch_present)
                %ask for channel
                message=sprintf('%s\n %s has no auxillary channel\n',message,obj.data(current_data).dataname);
                channel=[];
            else
                [s,~] = listdlg('PromptString','Select Auxillary Channel:',...
                    'SelectionMode','single',...
                    'ListString',ch_present,...
                    'OkString','Select',...
                    'InitialValue',2);
                if isempty(s)
                    % cancel clicked don't do anything to this data item
                    channel=[];
                else
                    channel=ch_present{s};
                    % ask if want to save this to a new data item
                    options.Interpreter = 'tex';
                    % Include the desired Default answer
                    options.Default = 'Save';
                    options.WindowStyle='modal';
                    button=questdlg('Do you want the line plot data saved as a new dataitem?>','Auxilary Channel Data','Save','Plot',options);
                    switch button
                        case 'Save'
                            savetrace=true;
                            displaytrace=true;
                        case 'Plot'
                            savetrace=false;
                            displaytrace=true;
                    end
                    % for multiple data ask for apply to all option
                    if numel(selected_data)>1
                        askforparam=askapplyall('apply');
                    end
                end
            end
        else
            % user decided to apply same settings to rest or use default
            % assign parameters
            fname=defaultparam(1:2:end);
            fval=defaultparam(2:2:end);
            for fidx=1:numel(fname)
                switch fname{fidx}
                    case 'channel'
                        channel=sprintf('%s',fval{fidx});
                    case 'savetrace'
                        savetrace=eval(fval{fidx});
                    case 'displaytrace'
                        displaytrace=eval(fval{fidx});
                end
            end
            % only use waitbar for user attention if we are in
            % automated mode
            if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
                % Report current estimate in the waitbar's message field
                done=data_idx/ndata;
                waitbar(done,waitbar_handle,sprintf('%3.1f%%',100*done));
            else
                % create waitbar if it doesn't exist
                waitbar_handle = waitbar(0,'Please wait...','Progress Bar','Calculating...',...
                    'CreateCancelBtn',...
                    'setappdata(gcbf,''canceling'',1)',...
                    'WindowStyle','normal',...
                    'Color',[0.2,0.2,0.2]);
                setappdata(waitbar_handle,'canceling',0);
            end
        end
        
        % ---- Data Calculation ----
        if isempty(channel)
            % decided to cancel action
            if numel(selected_data)>1
                askforparam=askapplyall('cancel');
                if askforparam==false
                    % quit if in automated mode
                    message=sprintf('%s\nAction cancelled!',message);
                    return;
                end
            else
                message=sprintf('%sAction cancelled!',message);
            end
        else
            if isempty(obj.data(current_data).metainfo.(channel))
                message=sprintf('%s\n %s has no data in %s\n',message,obj.data(current_data).dataname,channel);
            else
                % ---- Calculation ----
                x=obj.data(current_data).metainfo.(channel).x;
                y=obj.data(current_data).metainfo.(channel).y;
                xunit=obj.data(current_data).metainfo.(channel).xunit;
                yunit=obj.data(current_data).metainfo.(channel).yunit;
                npts=numel(y);
                t=linspace(x(1),x(2)*npts,npts);
                if displaytrace
                    figure('Name',sprintf('%s from data item %s',channel,obj.data(current_data).dataname),...
                        'NumberTitle','off',...
                        'MenuBar','none',...
                        'ToolBar','figure',...
                        'Keypressfcn',@export_panel);
                    plot(t,y,'k-','LineWidth',2);
                    xlabel(gca,sprintf('%s (%s)',obj.data(current_data).metainfo.(channel).xname,xunit));
                    ylabel(gca,sprintf('%s (%s)',obj.data(current_data).metainfo.(channel).yname,yunit));
                    title(gca,sprintf('%s from data item %s',channel,obj.data(current_data).dataname),'Interpreter','none','FontSize',10);
                end
                if savetrace
                    parent_data=current_data;
                    % add new data
                    obj.data_add(cat(2,'Auxch|',obj.data(parent_data).dataname),[],[]);
                    % get new data index
                    current_savedata=obj.current_data;
                    % pass on metadata info
                    obj.data(current_savedata).metainfo=obj.data(parent_data).metainfo;
                    % pass on datainfo
                    obj.data(current_savedata).datainfo=obj.data(parent_data).datainfo;
                    % set data index
                    obj.data(current_savedata).datainfo.data_idx=current_savedata;
                    % set parent data index
                    obj.data(current_savedata).datainfo.parent_data_idx=parent_data;
                    obj.data(current_savedata).datainfo.operator='data_showauxch';
                    obj.data(current_savedata).datainfo.aux_channel=channel;
                    obj.data(current_savedata).datainfo.T=t;
                    obj.data(current_savedata).dataval(1,1,1,1,:)=y;
                    obj.data(current_savedata).datainfo.data_dim=[1,1,1,1,numel(y)];
                    obj.data(current_savedata).datatype=obj.get_datatype(current_savedata);
                    obj.data(current_savedata).datainfo.last_change=datestr(now);
                    message=sprintf('%s\nData %s to %s aux channel %s saved',message,num2str(parent_data),num2str(current_savedata),channel);
                else
                    % if user dont' want to save action
                    message=sprintf('%s\nData %s to %s aux channel %s plotted',message,num2str(current_data),num2str(current_data),channel);
                end
                status=true;
            end
        end
        % increment data index
        data_idx=data_idx+1;
    end
    % close waitbar if exist
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
catch exception
    % error handle
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
    message=sprintf('%s\n%s',message,exception.message);
end

function export_panel(handle,eventkey)
global SETTING;
switch eventkey.Key
    case {'f3'}
        SETTING.export_panel(findobj(handle,'Type','Axes'));
end
