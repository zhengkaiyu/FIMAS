function [ status, message ] = data_showlineprofile( obj, selected_data, askforparam, defaultparam )
%DATA_SHOWLINEPROFILE plot line profile of selected impolyline
%(function check)
%--------------------------------------------------------------------------
%   Plot line profile of selected ROIs of selected data
%   Profile line will be plotted in new figure window and traces can be
%   exported using F3 shortcut key on the figure window
%   need for XYT or XYZ data
%--------------------------------------------------------------------------
%   HEADER END

%% function check
% assume worst
status=false;message='';
try
    current_roi=obj.data(selected_data).current_roi;
    impolyline_idx=find(cellfun(@(x)~isempty(x),regexp({obj.data(selected_data).roi(current_roi).type},'impoly')));
    
    if isempty(impolyline_idx)
        message=sprintf('data %g has no impolyline\n',selected_data);
    else
        impolyline_idx=current_roi(impolyline_idx);
        surface=findobj(obj.data(selected_data).roi(impolyline_idx(1)).panel,'type','Surface');
        if isempty(surface)
            message=sprintf('data %g has no surface plot\n',selected_data);
        else
            %ask for halfwidth
            set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
            set(0,'DefaultUicontrolForegroundColor','k');
            options.WindowStyle='modal';
            answer = inputdlg('Line halfwidth in image length unit (um usually):','Line Half Width',1,{'0.5'},options);
            set(0,'DefaultUicontrolBackgroundColor','k');
            set(0,'DefaultUicontrolForegroundColor','w');
            hw=str2double(answer);%um
            %get original image
            org_img=get(surface,'ZData');
            px_lim=get(surface,'XData');
            py_lim=get(surface,'YData');
            for m=1:numel(impolyline_idx)
                %get line positions
                xys=getPosition(obj.data(selected_data).roi(impolyline_idx(m)).handle);
                % get dx, dy, l to transformation coordinate
                dx=(diff(xys(:,1)));
                dy=(diff(xys(:,2)));
                len=sqrt(sum(diff(xys,1,1).^2,2));% lengths of line segments
                alpha=atand(dy./dx);
                numseg=numel(len);%number of line segments in the impolyline
                delx=abs(hw*sind(alpha));%x extent depending on hw
                dely=abs(hw*cosd(alpha));%y extent depending on hw
                dist{m}=0;lineprofile{m}=[];
                for ptidx=1:1:numseg
                    loc_imgx=[min(xys(ptidx:ptidx+1,1))-delx(ptidx),max(xys(ptidx:ptidx+1,1))+delx(ptidx)];
                    loc_imgy=[min(xys(ptidx:ptidx+1,2))-dely(ptidx),max(xys(ptidx:ptidx+1,2))+dely(ptidx)];
                    if diff(loc_imgx)==0
                        %horizontal line
                        xpos=find(px_lim>=loc_imgx(1)-hw&px_lim<=loc_imgx(2)+hw);
                    else
                        xpos=find(px_lim>=loc_imgx(1)&px_lim<=loc_imgx(2));
                    end
                    if diff(loc_imgy)==0
                        % vertical line
                        ypos=find(py_lim>=loc_imgy(1)-hw&py_lim<=loc_imgy(2)+hw);
                    else
                        ypos=find(py_lim>=loc_imgy(1)&py_lim<=loc_imgy(2));
                    end
                    
                    xoffset=abs(2*delx(ptidx)*cosd(alpha(ptidx)));
                    %yoffset=abs(dy(ptidx)*diff(loc_imgy)./len(ptidx)-hw);
                    yoffset=abs(dy(ptidx)*cosd(ptidx));
                    % crop local image
                    loc_img=org_img(ypos,xpos);%map axis is inverted
                    % perform local rotation
                    tform = affine2d([cosd(alpha(ptidx)) -sind(alpha(ptidx)) 0; sind(alpha(ptidx)) cosd(alpha(ptidx)) 0; 0 0 1]);
                    rotimg=imwarp(loc_img,tform,'FillValues',nan,'Interp','cubic');
                    
                    figure(2351+m);colormap('gray');
                    subplot(numseg,5,(ptidx-1)*5+1);
                    imagesc(px_lim,py_lim,org_img/max(org_img(:)));hold all;plot(xys(ptidx:ptidx+1,1),xys(ptidx:ptidx+1,2),'w','LineWidth',ceil(hw*2));hold off;axis('image');
                    subplot(numseg,5,(ptidx-1)*5+2);imagesc(loc_img/max(loc_img(:)));axis('image');
                    subplot(numseg,5,(ptidx-1)*5+3);imagesc(rotimg/max(rotimg(:)));axis('image');
                    xoff=floor(xoffset/(2*xoffset+len(ptidx))*size(rotimg,2));
                    if isnan(xoff)
                        %in case vertical
                        xoff=0;
                    end
                    yoff=floor(yoffset/(2*(yoffset+hw))*size(rotimg,1));
                    %crop rotated image
                    rotimg=rotimg(yoff+1:end-yoff,xoff+1:end-xoff);%map axis is inverted
                    subplot(numseg,5,(ptidx-1)*5+4);imagesc(rotimg/max(rotimg(:)));axis('image');
                    lp=nanmean(rotimg,1);
                    dist_lp=linspace(0,len(ptidx),numel(lp));
                    dist{m}=[dist{m},dist{m}(end)+dist_lp];
                    lineprofile{m}=[lineprofile{m},lp];
                    subplot(numseg,5,(ptidx-1)*5+5);plot(dist_lp,lp);
                end
            end
            button = questdlg('What to do with Line profile data?','Line profile data','Plot','Save','Plot&Save','Plot');
            switch button
                case {'Save','Plot&Save'}
                    savedata=true;
                case 'Plot'
                    savedata=false;
            end
            figure('Name',sprintf('Line profiles from data item %s',obj.data(selected_data).dataname),...
                'NumberTitle','off',...
                'MenuBar','none',...
                'ToolBar','figure',...
                'Keypressfcn',@export_panel);
            parent_data=selected_data;
            for m=1:numel(impolyline_idx)
                % plot data
                plot(dist{m}(2:end),lineprofile{m},'LineWidth',2);hold all;
                if savedata
                    % new data
                    % add new data
                    obj.data_add(sprintf('%s|%s','data_showlineprofile',obj.data(selected_data).dataname),[],[]);
                    % get new data index
                    new_data=obj.current_data;
                    % copy over datainfo
                    obj.data(new_data).datainfo=obj.data(parent_data).datainfo;
                    % set data index
                    obj.data(new_data).datainfo.data_idx=new_data;
                    % set parent data index
                    obj.data(new_data).datainfo.parent_data_idx=parent_data;
                    % set X
                    obj.data(new_data).datainfo.X=dist{m}(2:end);
                    obj.data(new_data).datainfo.dX=dist{m}(2)-dist{m}(1);
                    % set val
                    obj.data(new_data).dataval=lineprofile{m};
                    % update info
                    obj.data(new_data).datainfo.data_dim=[1,numel(lineprofile{m}),1,1,1];
                    obj.data(new_data).datatype=obj.get_datatype(new_data);
                    obj.data(new_data).datainfo.last_change=datestr(now);
                end
            end
            hold off;
            legend(gca,'show',{obj.data(selected_data).roi(impolyline_idx).name});
            status=true;
            message=sprintf('%s Lineprofile of width %g from %s plotted\n',message,2*hw,obj.data(selected_data).dataname);
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