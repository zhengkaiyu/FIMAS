function display_data( data, axeshandle, plot_type, dim, axis_label, isSeq, color_idx )
% display_data will plot input data for TCSPC_GUI programme only
% require input argument
% data: actual data
% axeshandle: where to plot data
% dim: mx1 cells of nx1 vectors for mth dimension
% dim_label: label for axis

%   Will only display data in the following form:
%       3D data with slider control
%       2D colour coded map,
%       2D scatter plot,
%       1d trace
%       0d point
%       dim t will be collapsed unless in 1D trace
global SETTING;
if ~isempty(data)
    gui=true;%to determine if we are in GUI form
    % --- Start Axis for Plotting ---
    if isempty(axeshandle)
        %in case of empty axeshandle, we plot into a new figure
        h=figure;
        axeshandle=gca(h);%create a new figure
        %since it is a new figure we assume no gui
        gui=false;
    else
        %change display panel to current
        SETTING.change_panel(axeshandle);
    end
    
    % --- Create Axis Labels ---
    if isempty(axis_label)
        %default to x and y labels
        axis_label={'x-axis','y-axis'};
    else
        if isempty(axis_label{1})
            %default 1st axis label if absent
            axis_label{1}='x-axis';
        end
        if numel(axis_label)==1||isempty(axis_label{2})
            %default 2nd axis label if absent
            axis_label{2}='a.u.';
        end
    end
    
    % --- Check Line Color mode ---
    if isempty(color_idx)
        color_idx=1;
    end
    
    % --- check draw mode ---
    tohold=SETTING.panel(SETTING.current_panel).hold;
    tonorm=SETTING.panel(SETTING.current_panel).norm;
    
    % --- deal with different plot type ---
    switch plot_type
        % ----------------------
        case 'surf' % 2D surface plot for scalar maps
            colormap(axeshandle,'gray');
            surf_plot=findobj(axeshandle,'Tag','surf');
            data=squeeze(data);
            if tonorm
                data=data./max(data(:));
            end
            if isempty(surf_plot)
                %add new plot
                set(axeshandle,'NextPlot','replace');
                surf_plot=mesh(axeshandle,dim{2},dim{1},data,'EdgeColor','interp','FaceColor','interp');
                set(surf_plot,'Tag','surf');
            else
                %update existing plot
                set(surf_plot,'XData',dim{2});
                set(surf_plot,'YData',dim{1});
                set(surf_plot,'ZData',data);
            end
            zbound=[min(data(~isinf(data))),max(data(~isinf(data)))];
            set(axeshandle,'Color',[0,0,0],...
                'XColor',[1,1,1],'YColor',[1,1,1],'ZColor',[1,1,1],...
                'YAxisLocation','right');
            xlabel(axeshandle,axis_label{2},'Color','w');
            ylabel(axeshandle,axis_label{1},'Color','w');
            view(axeshandle,[0,0,-1]);
            %set x and y limits
            xminmax=[dim{2}(1),dim{2}(end)];
            yminmax=[dim{1}(1),dim{1}(end)];
            if gui
                % update control
                SETTING.update_panel_control('set','xmin',xminmax(1),'xmax',xminmax(2),...
                    'ymin',yminmax(1),'ymax',yminmax(2),...
                    'zmin',zbound(1),'zmax',zbound(2));
                %caxis(axeshandle,'auto');
            else
                xlim(axeshandle,xminmax);ylim(axeshandle,yminmax);
                %caxis(axeshandle,'auto');
            end
            % ----------------------
        case 'mod_surf' % 2D surface map with modulated colour scalar map
            colormap(axeshandle,'jet');
            surf_plot=findobj(axeshandle,'Tag','mod_surf');
            cmap=squeeze(data{2});
            data=squeeze(data{1});
            if isempty(surf_plot)
                set(axeshandle,'NextPlot','replace');
                surf_plot=mesh(axeshandle,dim{2},dim{1},data,cmap,'EdgeColor','interp','FaceColor','interp');
                set(surf_plot,'Tag','mod_surf');
            else
                set(surf_plot,'XData',dim{2});
                set(surf_plot,'YData',dim{1});
                set(surf_plot,'ZData',data);
                set(surf_plot,'CData',cmap);
            end
            cbound=[min(data(:)),max(data(:))];
            set(axeshandle,'Color',[0,0,0],'XColor',[1,1,1],'YColor',[1,1,1],'ZColor',[1,1,1],...
                'YAxisLocation','right');
            xlabel(axeshandle,axis_label{2},'Color','w');
            ylabel(axeshandle,axis_label{1},'Color','w');
            view(axeshandle,[0,0,-1]);
            %set x and y limits
            xminmax=[dim{2}(1),dim{2}(end)];
            yminmax=[dim{1}(1),dim{1}(end)];
            if gui
                SETTING.update_panel_control('set','xmin',xminmax(1),'xmax',xminmax(2),...
                    'ymin',yminmax(1),'ymax',yminmax(2),...
                    'cmin',cbound(1),'cmax',cbound(2));
            else
                xlim(axeshandle,xminmax);
                ylim(axeshandle,yminmax);
                %caxis(axeshandle,'auto');
            end
            grid(axeshandle,'off');
            % ----------------------
        case 'scatter' % 2D scatter plot
            scatter_plot=findobj(axeshandle,'Tag','scatter');
            data=squeeze(data);
            if tonorm
                data=data./max(data(:));
            end
            if isempty(scatter_plot)||tohold%check if exist or is plot hold mode
                %plot new line
                set(axeshandle,'NextPlot','add');
                scatter_plot=plot(axeshandle,dim{1},data,'o','MarkerFaceColor','none','MarkerEdgeColor',mean(SETTING.color_order(mod(color_idx,64)+1,:),1));
                set(scatter_plot,'Tag','scatter');
            else
                %update existing
                set(scatter_plot,'XData',dim{1});
                set(scatter_plot,'YData',data);
            end
            %set color to dark mode
            set(axeshandle,'Color',[0,0,0],...
                'XColor',[1,1,1],'YColor',[1,1,1],'ZColor',[1,1,1],...
                'YAxisLocation','right');
            xlabel(axeshandle,axis_label{1},'Color','w');
            ylabel(axeshandle,axis_label{2},'Color','w');
            %set x and y limits
            xminmax=[0.99*min(dim{1}),1.01*max(dim{1})+1e-12];
            yminmax=[0.99*min(data(:)),1.01*max(data(:))+1e-12];
            if gui
                SETTING.update_panel_control('set','xmin',xminmax(1),'xmax',xminmax(2),...
                    'ymin',yminmax(1),'ymax',yminmax(2));
            else
                xlim(axeshandle,xminmax);
                ylim(axeshandle,yminmax);
            end
            % ----------------------
        case 'line' % plot line
            line_plot=findobj(axeshandle,'Tag','line');
            data=squeeze(data);
            if tonorm
                data=data./max(data(:));
            end
            if isempty(line_plot)||tohold%check if exist or is plot hold mode
                %plot new line
                set(axeshandle,'NextPlot','add');
                line_plot=plot(axeshandle,dim{1},data,'-','LineWidth',2,'Color',mean(SETTING.color_order(mod(color_idx,64)+1,:),1));
                set(line_plot,'Tag','line');
            else
                %update existing
                set(line_plot,'XData',dim{1});
                set(line_plot,'YData',data);
            end
            %set color to dark mode
            set(axeshandle,'Color',[0,0,0],...
                'XColor',[1,1,1],'YColor',[1,1,1],'ZColor',[1,1,1],...
                'YAxisLocation','right');
            xlabel(axeshandle,axis_label{1},'Color','w');
            ylabel(axeshandle,axis_label{2},'Color','w');
            %set x and y limits
            xminmax=[0.99*min(dim{1}),1.01*max(dim{1})+1e-12];
            yminmax=[0.99*min(data(:)),1.01*max(data(:))+1e-12];
            if gui
                SETTING.update_panel_control('set','xmin',xminmax(1),'xmax',xminmax(2),...
                    'ymin',yminmax(1),'ymax',yminmax(2));
            else
                xlim(axeshandle,xminmax);
                ylim(axeshandle,yminmax);
            end
            % ----------------------
        case 'hist' % histogram lineplot
            % get the current line handle
            hist_plot=findobj(axeshandle,'Tag','hist');
            data=squeeze(data);
            if tonorm
                data=data./max(data(:));
            end
            if isempty(hist_plot)||tohold%check if exist or is plot hold mode
                %plot new line
                set(axeshandle,'NextPlot','add');
                hist_plot=plot(axeshandle,dim{1},data,'-','LineWidth',2,'Color',mean(SETTING.color_order(mod(color_idx,64)+1,:),1));
                set(hist_plot,'Tag','hist');
            else
                %update existing
                set(hist_plot,'XData',dim{1});
                set(hist_plot,'YData',data);
            end
            %set color to dark mode
            set(axeshandle,'Color',[0,0,0],...
                'XColor',[1,1,1],'YColor',[1,1,1],'ZColor',[1,1,1],...
                'YAxisLocation','right');
            xlabel(axeshandle,axis_label{1},'Color','w');
            ylabel(axeshandle,axis_label{2},'Color','w');
            %set x and y limits
            xminmax=[0.99*min(dim{1}),1.01*max(dim{1})+1e-12];
            yminmax=[0.99*min(data(:)),1.01*max(data(:))+1e-12];
            if gui
                SETTING.update_panel_control('set','xmin',xminmax(1),'xmax',xminmax(2),...
                    'ymin',yminmax(1),'ymax',yminmax(2));
            else
                xlim(axeshandle,xminmax);
                ylim(axeshandle,yminmax);
            end
            % ----------------------
        case 'histmap' % 2D surface plot histogram map
            histmap_plot=findobj(axeshandle,'Tag','surf');
            data=squeeze(data);
            if tonorm
                data=data./max(data(:));
            end
            if isempty(histmap_plot)
                %add new plot
                set(axeshandle,'NextPlot','replace');
                histmap_plot=mesh(axeshandle,dim{2},dim{1},data,'EdgeColor','interp','FaceColor','interp');
                set(histmap_plot,'Tag','surf');
            else
                %update existing plot
                set(histmap_plot,'XData',dim{2});
                set(histmap_plot,'YData',dim{1});
                set(histmap_plot,'ZData',data);
            end
            zbound=[min(data(:)),max(data(:))];
            set(axeshandle,'Color',[0,0,0],...
                'XColor',[1,1,1],'YColor',[1,1,1],'ZColor',[1,1,1],...
                'YAxisLocation','right');
            xlabel(axeshandle,axis_label{2},'Color','w');
            ylabel(axeshandle,axis_label{1},'Color','w');
            view(axeshandle,[0,0,1]);
            %set x and y limits
            xminmax=[dim{2}(1),dim{2}(end)];
            yminmax=[dim{1}(1),dim{1}(end)];
            if gui
                % update control
                SETTING.update_panel_control('set','xmin',xminmax(1),'xmax',xminmax(2),...
                    'ymin',yminmax(1),'ymax',yminmax(2),...
                    'zmin',zbound(1),'zmax',zbound(2));
                caxis(axeshandle,'auto');
            else
                xlim(axeshandle,xminmax);ylim(axeshandle,yminmax);
                caxis(axeshandle,'auto');
            end
            % ----------------------
        case 'quiver' % 2D surface plot for vector maps
            quiver_plot=findobj(axeshandle,'Tag','quiver');
            if isempty(quiver_plot)
                %add new plot
                set(axeshandle,'NextPlot','add');
                quiver_plot=quiver(axeshandle,dim{2},dim{1},squeeze(data(1,:,:)),squeeze(data(2,:,:)),1,'Color','w','LineWidt',1);
                set(quiver_plot,'Tag','quiver');
            else
                %update existing plot
                set(quiver_plot,'UData',data(1,:,:));
                set(quiver_plot,'VData',data(2,:,:));
            end
            set(axeshandle,'Color',[0,0,0],'XColor',[1,1,1],'YColor',[1,1,1],'ZColor',[1,1,1],...
                'YAxisLocation','right');
            view(axeshandle,[0,0,-1]);
            xlabel(axeshandle,axis_label{2},'Color','w');
            ylabel(axeshandle,axis_label{1},'Color','w');
            if gui
                SETTING.update_panel_control('set','xmin',dim{2}(1),'xmax',dim{2}(end),...
                    'ymin',dim{1}(1),'ymax',dim{1}(end));
            else
                xlim(axeshandle,[dim{2}(1),dim{2}(end)]);
                ylim(axeshandle,[dim{1}(1),dim{1}(end)]);
                caxis(axeshandle,'auto');
            end
            % ----------------------
        case 'phasor_scatter'
            % plot semicircle
            circle_plot=findobj(axeshandle,'Tag','semicircle');
            if isempty(circle_plot)
                set(axeshandle,'NextPlot','add');
                circle_plot=plot(axeshandle,0:0.01:1,sqrt(0.5^2-([0:0.01:1]-0.5).^2),'b');
                set(circle_plot,'Tag','semicircle');
            end
            %plot scale
            scale_plot=findobj(axeshandle,'Tag','scale');
            if isempty(scale_plot)
                set(axeshandle,'NextPlot','add');
                scale_plot=plot(axeshandle,dim{1}(1,:),dim{1}(2,:),'Marker','o','MarkerFaceColor','r','LineStyle','none');
                set(scale_plot,'Tag','scale');
            end
            %plot grid
            grid_plot=findobj(axeshandle,'Tag','grid');
            if isempty(grid_plot)
                set(axeshandle,'NextPlot','add');
                xgrid=squeeze(dim{2}(1,:,:));
                ygrid=squeeze(dim{2}(2,:,:));
                grid_plot=plot(axeshandle,xgrid,ygrid,xgrid',ygrid','Marker','none','Color','r','LineStyle','-','LineWidth',1);
                set(grid_plot,'Tag','grid');
            end
            %plot data
            phasor_plot=findobj(axeshandle,'Tag','phasor_scatter');
            data=squeeze(data);
            if isempty(phasor_plot)||tohold%check if exist or is plot hold mode
                %plot new line
                set(axeshandle,'NextPlot','add');
                phasor_plot=scatter(axeshandle,data(1,:),data(2,:),'Marker','o','MarkerFaceColor',mean(SETTING.color_order(mod(color_idx,64)+1,:),1));
                set(phasor_plot,'Tag','phasor_scatter');
            else
                %update existing
                set(phasor_plot,'XData',data(1,:));
                set(phasor_plot,'YData',data(2,:));
            end
            %set color to dark mode
            set(axeshandle,'Color',[0,0,0],...
                'XColor',[1,1,1],'YColor',[1,1,1],'ZColor',[1,1,1],...
                'YAxisLocation','right');
            xlabel(axeshandle,axis_label{1},'Color','w');
            ylabel(axeshandle,axis_label{2},'Color','w');
            %set x and y limits
            xminmax=[0.99* min(min(dim{2}(1,:,:))),1.02* max(max(dim{2}(1,:,:)))+1e-12];
            yminmax=[1* min(min(dim{2}(2,:,:))),1.02* max(max(dim{2}(2,:,:)))+1e-12];
            if gui
                SETTING.update_panel_control('set','xmin',xminmax(1),'xmax',xminmax(2),...
                    'ymin',yminmax(1),'ymax',yminmax(2));
            else
                xlim(axeshandle,xminmax);
                ylim(axeshandle,yminmax);
            end
            % ----------------------
        case 'phasor_map'
            %plot data
            phasor_plot=findobj(axeshandle,'Tag','phasor_map');
            data=squeeze(data);
            if tonorm
                data=data./max(data(:));
            end
            temp=hist3([data(1,:)',data(2,:)'],{dim{2}{1},dim{2}{2}});
            temp(temp==0)=nan;
            if isempty(phasor_plot)||tohold%check if exist or is plot hold mode
                %plot new line
                set(axeshandle,'NextPlot','replace');
                phasor_plot=mesh(axeshandle,dim{2}{1},dim{2}{2},temp','EdgeColor','none','FaceColor','interp');
                set(phasor_plot,'Tag','phasor_map');
            else
                %update existing
                set(phasor_plot,'XData',dim{2}{1});
                set(phasor_plot,'YData',dim{2}{2});
                set(phasor_plot,'ZData',temp');
            end
            % plot semicircle
            circle_plot=findobj(axeshandle,'Tag','semicircle');
            if isempty(circle_plot)
                set(axeshandle,'NextPlot','add');
                circle_plot=plot(axeshandle,0:0.01:1,sqrt(0.5^2-([0:0.01:1]-0.5).^2),'w');
                set(circle_plot,'Tag','semicircle');
            end
            %plot scale
            scale_plot=findobj(axeshandle,'Tag','scale');
            if isempty(scale_plot)
                set(axeshandle,'NextPlot','add');
                scale_plot=plot(axeshandle,dim{1}(1,:),dim{1}(2,:),'Marker','o','MarkerFaceColor','r','LineStyle','none');
                set(scale_plot,'Tag','scale');
            end
            zbound=[nanmin(temp(~isinf(temp))),nanmax(temp(~isinf(temp)))];
            %set color to dark mode
            set(axeshandle,'Color',[0,0,0],...
                'XColor',[1,1,1],'YColor',[1,1,1],'ZColor',[1,1,1],...
                'YAxisLocation','right');
            view(axeshandle,[0,0,-1]);
            %set x and y limits
            xminmax=[dim{2}{1}(1),dim{2}{1}(end)];
            yminmax=[dim{2}{2}(1),dim{2}{2}(end)];
            if gui
                % update control
                SETTING.update_panel_control('set','xmin',xminmax(1),'xmax',xminmax(2),...
                    'ymin',yminmax(1),'ymax',yminmax(2),...
                    'zmin',zbound(1),'zmax',zbound(2));
                %caxis(axeshandle,'auto');
            else
                xlim(axeshandle,xminmax);ylim(axeshandle,yminmax);
                %caxis(axeshandle,'auto');
            end
            % ----------------------
        otherwise
            fprintf('unknow display type.\n');
    end
    
    % --- Pass on isTseq value ---
    SETTING.panel(SETTING.current_panel).Z_seq=isSeq(1);
    SETTING.panel(SETTING.current_panel).T_seq=isSeq(2);
else
    fprintf('empty %s data nothing to display.\n',plot_type);
end