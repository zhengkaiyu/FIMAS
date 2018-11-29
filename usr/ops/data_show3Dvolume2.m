function [ status, message ] = data_show3Dvolume2( obj, selected_data )
%data_show3Dvolume plot slice through 3D data to illustrate
%   function check for existing auxillary input channel from femtonics data
%   file .mes, user then select the channel to be plotted in an external
%   figure window and export the trace by press F3 key in the figure.

%% function incomplete
% assume worst
status=false;message='';
try
    % check data dimention is 3D
    r1=obj.data(selected_data).datainfo.X;dr1=obj.data(selected_data).datainfo.dX;
    r2=obj.data(selected_data).datainfo.Y;dr2=obj.data(selected_data).datainfo.dY;
    r3=obj.data(selected_data).datainfo.Z;dr3=obj.data(selected_data).datainfo.dZ;
    % default answers
    bg_threshold=10;
    nn_dist=2;
    znn_dist=2;
    % ask for slice intervals
    prompt = {'Background Threshold',...   %bg_threshold
        'Nearest Neighbour Distance(XY)',...    %nn_dist
        'Nearest Neighbour Distance(Z)',...     %znn_dist
        };
    dlg_title = cat(2,'3D shape generator',obj.data(selected_data).dataname);
    num_lines = 1;
    def = cellfun(@(x)num2str(x),{bg_threshold,nn_dist,znn_dist},'UniformOutput',false);
    set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
    set(0,'DefaultUicontrolForegroundColor','k');
    s = inputdlg(prompt,dlg_title,num_lines,def);
    set(0,'DefaultUicontrolBackgroundColor','k');
    set(0,'DefaultUicontrolForegroundColor','w');
    
    if isempty(s)
        %cancelled
        message=sprintf('%s\n %s 3D volume plot cancelled\n',message,obj.data(selected_data).dataname);
    else
        bg_threshold=str2double(s{1});
        nn_dist=max(2,str2double(s{2}));
        znn_dist=max(2,str2double(s{3}));
        % ---- Calculation ----
        % ---- Convert Images to clusterdata ----
        % sub image tile to be used for localisation
        subimgsize=[2*nn_dist+1,2*nn_dist+1,2*znn_dist+1];
        % number of voxels
        nvoxel=prod(subimgsize);
        % number in each dimension
        n1=numel(r1)-nn_dist*2;
        n2=numel(r2)-nn_dist*2;
        n3=numel(r3)-znn_dist*2;
        loopsize=n1*n2*n3;
        
        xstart=1+nn_dist;xstop=numel(r1)-nn_dist;
        ystart=1+nn_dist;ystop=numel(r2)-nn_dist;
        zstart=1+znn_dist;zstop=numel(r3)-znn_dist;
        
        lb=0.01;ub=200;
        
        [i,j,k]=ind2sub(subimgsize,1:nvoxel);
        i=i(:);j=j(:);k=k(:);
        ds=[dr1,dr2,dr3];
        
        
        if loopsize<8e4
            savemem='off';
        else
            savemem='on';
        end
        
        intensity=zeros(loopsize,1);
        localpos=zeros(loopsize,3);
        localidx=1;
        binsize=200;
        tempval=squeeze(obj.data(selected_data).dataval);
        fprintf(1,'starting... %g steps\n',loopsize);
        for zpix=zstart:1:zstop
            zorg=r3(zpix-znn_dist);
            planeval=tempval(:,:,zpix-znn_dist:zpix+znn_dist);
            planeval=smooth3(planeval,'gaussian');
            [PX,PY,PZ] = gradient(planeval,dr1,dr2,dr3);
            volvec=sqrt(PX.^2+PY.^2+PZ.^2);
            
            figure(21);
            subplot(2,2,[1,2]);cla;
            hist(volvec(:),linspace(0,max(volvec(:)),binsize));
            hold on;
            line([lb,lb],[0,prod(size(volvec))/binsize],'LineWidth',3,'Color','r');
            line([ub,ub],[0,prod(size(volvec))/binsize],'LineWidth',3,'Color','r');
            xlim([0,max(volvec(:))]);
            
            rejectidx=find(volvec<lb|volvec>ub);
            
            subplot(2,2,3);imagesc(squeeze(mean(planeval,3)));
            view([0,90]);
            
            planeval(rejectidx)=0;
            
            subplot(2,2,4);imagesc(squeeze(mean(planeval,3)));
            view([0,90]);
            colormap('gray');
            %{
            planeproj=max(planeval,[],3);
            threshold=median(planeproj(:))*nvoxel;%time nvoxel for comparison with sum later
            threshold=threshold+0.368*var(planeval(:))/mean(planeval(:));
            for xpix=xstart:nn_dist:xstop
                xorg=r1(xpix-nn_dist);
                for ypix=ystart:nn_dist:ystop
                    yorg=r2(ypix-nn_dist);
                    val=tempval(xpix-nn_dist:xpix+nn_dist,ypix-nn_dist:ypix+nn_dist,zpix-znn_dist:zpix+znn_dist);
                    Itotal=sum(val(:));
                    if Itotal>threshold
                        localpos(localidx,1:3)=roicentroid([i,j,k,val(:)],Itotal,ds,[xorg,yorg,zorg]);
                        intensity(localidx)=Itotal;
                    else
                        localpos(localidx,1:3)=[nan,nan,nan];
                        intensity(localidx)=0;
                    end
                    localidx=localidx+1;
                end
            end
            %}
        end
        fprintf(1,'finished\n');
        % remove invalid points
        invalid=(intensity==0);
        localpos(invalid,:)=[];
        intensity(invalid)=[];
        
        % scatter all points
        figure('Name',sprintf('3D volume plot for dataitem %s',obj.data(selected_data).dataname),...
            'NumberTitle','off',...
            'MenuBar','none',...
            'ToolBar','figure',...
            'Keypressfcn',@export_panel,...
            'Renderer','opengl');
        plot3(localpos(:,1),localpos(:,2),localpos(:,3),...
            'LineStyle','none','Marker','o','Color','r',...
            'MarkerSize',1);
        view([90,-40,30]);
        axis equal;
        xlabel('y');ylabel('x');zlabel('z');
        
        % play with cluster analysis
        T = clusterdata(localpos,'criterion','inconsistent','depth',3,'cutoff',0.7,'distance','squaredeuclidean','linkage','single','savememory',savemem);
        figure;
        cutoff=7000;
        subplot(2,2,1);hist(T,0.5:10:max(T)+0.5);hold on;line([cutoff,cutoff],[0,100],'Color','r','LineWidth',3);axis([0,max(T),0,100]);
        subplot(2,2,2);
        shortdist=find(T<cutoff);
        plot3(localpos(shortdist,1),localpos(shortdist,2),localpos(shortdist,3),...
            'LineStyle','none','Marker','o','Color','r',...
            'MarkerSize',1);
        view([90,-40,30]);
        axis equal;
        subplot(2,2,3);
        shortdist=find(T<2*cutoff);
        plot3(localpos(shortdist,1),localpos(shortdist,2),localpos(shortdist,3),...
            'LineStyle','none','Marker','o','Color','r',...
            'MarkerSize',1);
        view([90,-40,30]);
        axis equal;
        subplot(2,2,4);
        shortdist=find(T>cutoff);
        plot3(localpos(shortdist,1),localpos(shortdist,2),localpos(shortdist,3),...
            'LineStyle','none','Marker','o','Color','r',...
            'MarkerSize',1);
        view([90,-40,30]);
        axis equal;
        
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

function coord=roicentroid(val,Itotal,dr,orig)
coord=sum(bsxfun(@times,val(:,1:3),val(:,4)),1)/Itotal.*dr+orig;