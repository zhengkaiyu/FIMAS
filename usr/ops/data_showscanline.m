function [ status, message ] = data_showscanline( obj, selected_data, askforparam, defaultparam )
%DATA_showscanline plot line scan trace onto background image for femtonics
%data

%% function complete
% assume worst
status=false;message='';
try
    where_to=obj.data(selected_data).datainfo.panel;
    if isfield(obj.data(selected_data).datainfo,'ScanLine')
        % check for type
        switch obj.data(selected_data).datainfo.ScanLine.Type
            case 'composite'
                [sl_names,sl_idx,sl_order]=unique({obj.data(selected_data).datainfo.ScanLine.ODDarray.name});
                time=obj.data(selected_data).datainfo.ScanLine.Data2*(1/obj.data(selected_data).datainfo.ScanLine.Param1);
                for sl_n=1:numel(sl_idx)
                    % loop through unique scanlines in the composite
                    sl_data=obj.data(selected_data).datainfo.ScanLine.ODDarray(sl_idx(sl_n)).Data2(1:2,:);
                    if numel(find(sl_data~=0))==0
                        % not test line try real line
                        sl_data=obj.data(selected_data).datainfo.ScanLine.ODDarray(sl_idx(sl_n)).Data1(1:2,:);
                    end
                    [npix,length,radius,area]=draw_sl(sl_data,sl_names{sl_idx(sl_n)},where_to);
                    message=sprintf('%s\n Scan Line %s (red dot start)\n ( N = %g, L = %0.2fum, r = %0.2fum, A = %0.2fum^2 ) added to %s plot\n',...
                        message,sl_names{sl_idx(sl_n)},npix,length,radius,area,obj.data(selected_data).dataname);
                end
                % plot time course
                sl_order=reshape(repmat(sl_order,1,2)',numel(sl_order)*2,1);
                time=reshape([time;time-1e-9],numel(time)*2,1);
                time(2)=[];time(end+1)=time(end)+1e-9;
                figure(2);h=gca;
                plot(time,sl_order,'LineWidth',2);
                h.Title.String='Scan Line Time Course';
                h.XLabel.String='Time (s)';
                h.YLabel.String='Scan Line Name';
                h.YTickLabel=sl_names;
                h.YTick=sortrows(sl_idx);% create monotonically increasing vector
                textinfo=cellfun(@(x,y)sprintf('%s %0.2Gs',x,y),sl_names(sl_order(1:2:end-2)),num2cell(diff(time(1:2:end)))','UniformOutput',false);
                text(0.001,1.1,textinfo,'VerticalAlignment','bottom');
                status=true;
            case 'square'
                % ---- Calculation ----
                sl_data=obj.data(selected_data).datainfo.ScanLine.Data2(1:2,:);
                sl_name=obj.data(selected_data).datainfo.ScanLine.name;
                if numel(find(sl_data~=0))==0
                    % not test line try real line
                    sl_data=obj.data(selected_data).datainfo.ScanLine.Data1(1:2,:);
                end
                [npix,length,radius,area]=draw_sl(sl_data,sl_name,where_to);
                message=sprintf('%s\n Scan Line (red dot start)\n ( N = %g, L = %0.2fum, r = %0.2fum, A = %0.2fum^2 ) added to %s plot\n',...
                    message,npix,length,radius,area,obj.data(selected_data).dataname);
                status=true;
            otherwise
                message=sprintf('%s\n %s has unknown scan line type %s\n',message,obj.data(selected_data).dataname,obj.data(selected_data).datainfo.ScanLine.Type);
        end
    else
        message=sprintf('%s\n %s has no scan line\n',message,obj.data(selected_data).dataname);
    end
catch exception
    message=exception.message;
end
end
function [npts,length,radius,area]=draw_sl(sl_data,sl_name,where_to)
% downsample
npts=size(sl_data,2);
coord=downsample(sl_data',floor(size(sl_data,2)/npts));
radius=sqrt(sum((coord(end,:)-coord(1,:)).^2));
area=pi*radius^2;
length=sum(sqrt(sum(diff(coord,1,1).^2,2)));
if isempty(sl_name)
    sl_name='hsl';
end
hsl=findobj(where_to,'Tag',sl_name);
if isempty(hsl)
    set(where_to,'NextPlot','add');
    hsl=plot(where_to,coord(:,2),coord(:,1),'Color','y','LineStyle','-','LineWidth',1);
    set(hsl,'Tag',sl_name);
else
    set(hsl,'XData',coord(:,2),'YData',coord(:,1));
end
hsls=findobj(where_to,'Tag',cat(2,sl_name,'s'));
if isempty(hsls)
    hsls=plot(where_to,coord(1,2),coord(1,1),'Marker','o','MarkerFaceColor','r');
    set(hsls,'Tag',cat(2,sl_name,'s'));
    set(where_to,'NextPlot','replace');
else
    set(hsls,'XData',coord(1,2),'YData',coord(1,1));
end
end