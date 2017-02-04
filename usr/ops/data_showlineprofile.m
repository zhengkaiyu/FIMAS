function [ status, message ] = data_showlineprofile( obj, selected_data )
%DATA_SHOWLINEPROFILE plot line profile of selected impolyline


%% function check
% assume worst
status=false;message='';
try
    current_data=obj.current_data;
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

