function [ status, message ] = data_showauxch( obj, selected_data )
%DATA_SHOWAUXCH plot auxillary channel from femtonics data file


%% function check
% assume worst
status=false;message='';
try
    current_data=obj.current_data;
    %find existing AUXi channels
    fnames=fieldnames(obj.data(current_data).metainfo);
    temp=regexp(fnames,'AUXi\w*','match');
    ch_present=fnames(cellfun(@(x)~isempty(x),temp));
    if isempty(ch_present)
        %ask for channel
        message=sprintf('%s\n %s has no auxillary data\n',message,obj.data(current_data).dataname);
    else
        set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
        set(0,'DefaultUicontrolForegroundColor','k');
        options.WindowStyle='modal';
        [s,~] = listdlg('PromptString','Select Auxillary Channel:',...
            'SelectionMode','single',...
            'ListString',ch_present,...
            'OkString','Select');
        set(0,'DefaultUicontrolBackgroundColor','k');
        set(0,'DefaultUicontrolForegroundColor','w');
        if isempty(s)
            %cancelled
            message=sprintf('%s\n %s cancelled\n',message,obj.data(current_data).dataname);
        else
            channel=ch_present{s};
            if isempty(obj.data(current_data).metainfo.(channel))
                message=sprintf('%s\n %s has no auxillary data\n',message,obj.data(current_data).dataname);
            else
                % ---- Calculation ----
                x=obj.data(current_data).metainfo.(channel).x;
                y=obj.data(current_data).metainfo.(channel).y;
                xunit=obj.data(current_data).metainfo.(channel).xunit;
                yunit=obj.data(current_data).metainfo.(channel).yunit;
                npts=numel(y);
                t=linspace(x(1),x(2)*npts,npts);
                figure(1000);
                plot(t,y,'k-','LineWidth',2);
                xlabel(gca,sprintf('%s (%s)',obj.data(current_data).metainfo.(channel).xname,xunit));
                ylabel(gca,sprintf('%s (%s)',obj.data(current_data).metainfo.(channel).yname,yunit));
                title(gca,channel);
                status=true;
            end
        end
    end
catch exception
    message=exception.message;
end

