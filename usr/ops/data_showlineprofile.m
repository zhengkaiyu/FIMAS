function [ status, message ] = data_showlineprofile( obj, selected_data )
%DATA_SHOWLINEPROFILE plot line profile of selected impolyline


%% function check
% assume worst
status=false;message='';
try
    current_data=obj.current_data;
    current_roi=obj.data(current_data).current_roi;
    impolyline_idx=find(cellfun(@(x)~isempty(x),regexp({obj.data(current_data).roi(current_roi).type},'impolyline')));
    
    if isempty(impolyline_idx)
        message=sprintf('data %g has no impolyline\n',current_data);
    else
        impolyline_idx=current_roi(impolyline_idx);
        surface=findobj(obj.data(current_data).roi(impolyline_idx(1)).panel,'type','Surface');
        if isempty(surface)
            message=sprintf('data %g has no surface plot\n',current_data);
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
            px_lim=get(surface,'YData');%map axis is inverted
            py_lim=get(surface,'XData');
            for m=1:numel(impolyline_idx)
                %get line positions
                xys=getPosition(obj.data(current_data).roi(impolyline_idx(m)).handle);
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
                    if diff(loc_imgx)==0
                        %horizontal line
                        xpos=find(px_lim>=min(loc_imgx)-hw&px_lim<=max(loc_imgx)+hw);
                    else
                        xpos=find(px_lim>=min(loc_imgx)&px_lim<=max(loc_imgx));
                    end
                    if diff(loc_imgy)==0
                        % vertical line
                        ypos=find(py_lim>=min(loc_imgy)-hw&py_lim<=max(loc_imgy)+hw);
                    else
                        ypos=find(py_lim>=min(loc_imgy)&py_lim<=max(loc_imgy));
                    end
                    xoffset=abs(hw*dy(ptidx)./dx(ptidx));
                    yoffset=abs(dy(ptidx)*diff(loc_imgy)./len(ptidx)-hw);
                    % crop local image
                    loc_img=org_img(xpos,ypos);
                    % perform local rotation
                    tform=affine2d([dx(ptidx)/len(ptidx) -dy(ptidx)/len(ptidx) 0; dy(ptidx)/len(ptidx) dx(ptidx)/len(ptidx) 0;0 0 1]);
                    rotimg=imwarp(loc_img,tform,'FillValues',nan);
                    
                    figure(2351+m);
                    subplot(numseg,5,(ptidx-1)*5+1);
                    imagesc(py_lim,px_lim,org_img/255);hold all;plot(xys(ptidx:ptidx+1,1),xys(ptidx:ptidx+1,2),'w','LineWidth',ceil(hw*2));hold off;axis('image');
                    subplot(numseg,5,(ptidx-1)*5+2);imagesc(loc_img/255);axis('image');
                    subplot(numseg,5,(ptidx-1)*5+3);imagesc(rotimg/255);axis('image');
                    xoff=ceil(xoffset/(2*xoffset+len(ptidx))*size(rotimg,2));
                    if isnan(xoff)
                        %in case vertical
                        xoff=0;
                    end
                    yoff=ceil(yoffset/(2*(yoffset+hw))*size(rotimg,1));
                    %crop rotated image
                    rotimg=rotimg(yoff+1:end-yoff,xoff+1:end-xoff);
                    subplot(numseg,5,(ptidx-1)*5+4);imagesc(rotimg/255);axis('image');
                    lp=nanmean(rotimg,1);
                    dist_lp=linspace(0,len(ptidx),numel(lp));
                    dist=[dist,dist(end)+dist_lp];
                    lineprofile=[lineprofile,lp];
                    subplot(numseg,5,(ptidx-1)*5+5);plot(dist_lp,lp);
                end
                figure(3572);plot(dist(2:end),lineprofile);hold all;
            end
            legend('show',{obj.data(current_data).roi(impolyline_idx).name});
            status=true;
        end
    end
catch exception
    message=exception.message;
end
