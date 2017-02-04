function [ status, message ] = roi_select( obj, roi_idx )
%change roi colour to indicate current

%% function complete
status=false;message='';
current_data=obj.current_data;
for m=1:numel(obj.data(current_data).current_roi)
    if obj.data(current_data).current_roi(m)>1
        %ignore template whoes index is 1
        %change colour of the current one to blue
        setColor(obj.data(current_data).roi(obj.data(current_data).current_roi(m)).handle,'b');
    end
end

%calculate index inside the roi from where_from image
where_from=obj.data(current_data).datainfo.panel;
if ishandle(where_from)
    surface=findobj(where_from,'Type','Surface');
else
    surface=[];
end

if ~isempty(surface)
    px_lim=get(surface,'YData');%map axis is inverted
    py_lim=get(surface,'XData');
    
    % change current roi to selected
    obj.data(current_data).current_roi=roi_idx;
    p_roi_idx=[];
    for m=1:numel(roi_idx)
        if roi_idx(m)>1
            %i.e. not the 'ALL' template
            setColor(obj.data(current_data).roi(roi_idx(m)).handle,'w');
            xys=getPosition(obj.data(current_data).roi(roi_idx(m)).handle);
            obj.data(current_data).roi(roi_idx(m)).coord=xys;
            
            %get boundary coordinate and find inpoly points
            switch obj.data(current_data).roi(roi_idx(m)).type
                case 'imrect'
                    %rect
                    [pixel_x,pixel_y]=meshgrid(py_lim,px_lim);%map axis is inverted
                    xys=[[xys(1),xys(2)];...
                        [xys(1),xys(2)+xys(4)];...
                        [xys(1)+xys(3),xys(2)+xys(4)];...
                        [xys(1)+xys(3),xys(2)];...
                        [xys(1),xys(2)]];%construct polygon from rectangle coordinate
                    roi=inpolygon(pixel_x,pixel_y,xys(:,1),xys(:,2));
                    p_roi_idx=find(roi==1);
                    roilength=sum(sqrt(sum(diff([xys;xys(1,:)],1,1).^2,2)));
                case 'impoly'
                    %polygon
                    [pixel_x,pixel_y]=meshgrid(py_lim,px_lim);%map axis is inverted
                    roi=inpolygon(pixel_x,pixel_y,xys(:,1),xys(:,2));
                    p_roi_idx=find(roi==1);
                    % length for two points impoly
                    roilength=sum(sqrt(sum(diff([xys;xys(1,:)],1,1).^2,2)));
                case 'impolyline'
                    xys=fliplr(xys);%map axis is inverted
                    % distance for two points impoly
                    roilength=sum(sqrt(sum(diff(xys,1,1).^2,2)));
                    %{
                    %get original image
                    org_img=get(surface,'ZData');
                    hw=1;%um
                    % get dx, dy, l to transformation coordinate
                    dx=(diff(xys(:,1)));
                    dy=(diff(xys(:,2)));
                    len=sqrt(sum(diff(xys,1,1).^2,2));
                    numseg=numel(len);
                    delx=hw*dy./len;
                    dely=hw*dx./len;
                    
                    dist=0;lineprofile=[];
                    for ptidx=1:1:numseg
                        loc_imgy=[xys(ptidx,1)-dely(ptidx),xys(ptidx+1,1)+dely(ptidx)];
                        loc_imgx=[xys(ptidx,2)-delx(ptidx),xys(ptidx+1,2)+delx(ptidx)];
                        xpos=find(px_lim>=min(loc_imgx)&px_lim<=max(loc_imgx));
                        ypos=find(py_lim>=min(loc_imgy)&py_lim<=max(loc_imgy));
                        xoffset=abs(hw*dy(ptidx)./dx(ptidx));
                        yoffset=abs(dy(ptidx)*diff(loc_imgy)./len(ptidx)-hw);
                        % crop local image
                        loc_img=org_img(ypos,xpos);
                        % perform local rotation
                        tform=affine2d([dx(ptidx)/len(ptidx) -dy(ptidx)/len(ptidx) 0; dy(ptidx)/len(ptidx) dx(ptidx)/len(ptidx) 0;0 0 1]);
                        rotimg=imwarp(loc_img,tform,'FillValues',nan);
                        
                        xoff=ceil(xoffset/(2*xoffset+len)*size(rotimg,2));
                        yoff=ceil(yoffset/(2*(yoffset+hw))*size(rotimg,1));
                        %crop rotated image
                        rotimg=rotimg(yoff:end-yoff,xoff:end-xoff);
                        lp=nanmean(rotimg,1);
                        dist=[dist,linspace(dist(end),dist(end)+len(ptidx),numel(lp))];
                        lineprofile=[lineprofile,lp];
                    end
                    figure(3572);plot(dist(2:end),lineprofile);
                    %}
                    p_roi_idx=[];
                case 'impoint'
                    %point
                    xys=fliplr(xys(1,:));%map axis is inverted
                    xpos=find(xys(1,1)<=px_lim,1,'first');
                    ypos=find(xys(1,2)<=py_lim,1,'first');
                    if isempty(obj.data(obj.current_data).datainfo.bin_dim)
                        xbin=1;ybin=1;
                    else
                        xbin=obj.data(obj.current_data).datainfo.bin_dim(2);
                        dim_idx=strfind(char(obj.DIM_TAG)',get(get(where_from,'XLabel'),'String'));
                        if isempty(dim_idx)
                            ybin=1;
                        else
                            ybin=obj.data(obj.current_data).datainfo.bin_dim(dim_idx);
                        end
                    end
                    p_roi_idx=repmat(xpos-xbin:1:xpos+xbin,2*ybin+1,1)'+(repmat(ypos-ybin:1:ypos+ybin,2*xbin+1,1)-1)*length(px_lim);
                    p_roi_idx=p_roi_idx(:);
                    p_roi_idx(p_roi_idx<1)=[];
                    p_roi_idx(p_roi_idx>length(px_lim)*length(py_lim))=[];
                    roilength=[];
            end
        else
            % all pixels
            p_roi_idx=1:length(px_lim)*length(py_lim);
            roilength=[];
        end
        obj.data(current_data).roi(roi_idx(m)).idx=p_roi_idx;%assign indices
        status=true;
        message=sprintf('%s\n%s of length %g contains %g pixels',message,obj.data(current_data).roi(roi_idx(m)).name,roilength,numel(p_roi_idx));
    end
end