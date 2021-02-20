function [ status, message ] = roi_select( obj, roi_idx )
%change roi colour to indicate current

%% function complete
status=false;message='';
current_data=obj.current_data;
for m=1:numel(obj.data(current_data).current_roi)
    if obj.data(current_data).current_roi(m)>1
        %ignore template whoes index is 1
        %change colour of the current one to blue
        if ~isempty(obj.data(current_data).roi(obj.data(current_data).current_roi(m)).handle)
            setColor(obj.data(current_data).roi(obj.data(current_data).current_roi(m)).handle,'b');
        end
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
            %get boundary coordinate and find inpoly points
            switch obj.data(current_data).roi(roi_idx(m)).type
                case 'imrect'
                    %rect
                    xys=getPosition(obj.data(current_data).roi(roi_idx(m)).handle);
                    major=max(xys(3:4));
                    minor=min(xys(3:4));
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
                    xys=getPosition(obj.data(current_data).roi(roi_idx(m)).handle);
                    %polygon
                    [pixel_x,pixel_y]=meshgrid(py_lim,px_lim);%map axis is inverted
                    roi=inpolygon(pixel_x,pixel_y,xys(:,1),xys(:,2));
                    p_roi_idx=find(roi==1);
                    radius=max(xys)-min(xys);
                    major=max(radius);
                    minor=min(radius);
                    % length for two points impoly
                    roilength=sum(sqrt(sum(diff([xys;xys(1,:)],1,1).^2,2)));
                case 'imellipse'
                    % elliptical
                    xys=obj.data(current_data).roi(roi_idx(m)).handle.getVertices;
                    [pixel_x,pixel_y]=meshgrid(py_lim,px_lim);%map axis is inverted
                    roi=inpolygon(pixel_x,pixel_y,xys(:,1),xys(:,2));
                    p_roi_idx=find(roi==1);
                    % length for two points impoly
                    radius=max(xys)-min(xys);
                    major=max(radius);
                    minor=min(radius);
                    roilength=sum(sqrt(sum(diff([xys;xys(1,:)],1,1).^2,2)));
                case 'impolyline'
                    xys=getPosition(obj.data(current_data).roi(roi_idx(m)).handle);
                    xys=fliplr(xys);%map axis is inverted
                    % distance for two points impoly
                    roilength=sum(sqrt(sum(diff(xys,1,1).^2,2)));
                    major=[];minor=[];
                    p_roi_idx=[];
                case 'impoint'
                    xys=getPosition(obj.data(current_data).roi(roi_idx(m)).handle);
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
                    major=[];minor=[];
                    roilength=[];
            end
            obj.data(current_data).roi(roi_idx(m)).coord=xys;
        else
            % all pixels
            p_roi_idx=1:length(px_lim)*length(py_lim);
            major=[];minor=[];
            roilength=[];
        end
        obj.data(current_data).roi(roi_idx(m)).idx=p_roi_idx;%assign indices
        status=true;
        message=sprintf('%s\n%s of major %g, minor %g, length %g, contains %g pixels.',message,obj.data(current_data).roi(roi_idx(m)).name,major,minor,roilength,numel(p_roi_idx));
    end
end