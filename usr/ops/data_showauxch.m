function [ status, message ] = data_showauxch( obj, selected_data )
%DATA_SHOWAUXCH plot auxillary channel from femtonics data file


%% function check
% assume worst
status=false;message='';
try
    current_data=obj.current_data;
    %where_to=obj.data(current_data).datainfo.panel;
    if isfield(obj.data(current_data).metainfo,'AUXi1')
        % ---- Calculation ----
        x=obj.data(current_data).metainfo.AUXi1.x;
        y=obj.data(current_data).metainfo.AUXi1.y;
        xunit=obj.data(current_data).metainfo.AUXi1.xunit;
        switch xunit
            case 'ms'
                scale=1/1000;
            case 's'
                scale=1;
                
        end
        % downsample
        y=downsample(y,10);
        npts=numel(y);
        t=linspace(x(1),x(2)*npts,npts)*scale;
        figure(1000);plot(t,y,'k-','LineWidth',2);
        status=true;
    else
        message=sprintf('%s\n %s has no auxillary data\n',message,obj.data(current_data).dataname);
    end
    
catch exception
    message=exception.message;
end

