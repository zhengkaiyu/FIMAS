function test2
%===============================
clc;
figure(100);clf;
options=struct('Display','off',...
    'MaxFunctionEvaluations',1e12,...
    'MaxIterations',1e12,...
    'OptimalityTolerance',1e-12,...
    'StepTolerance',1e-12,...
    'ConstraintTolerance',1e-12);
%===============================
%{
satlevel=512;
xres=19;yres=19;
imgx=linspace(-0.5,0.5,xres);imgx=imgx(:);
imgy=linspace(-0.5,0.5,yres);imgy=imgy(:);
dx=(max(imgx)-min(imgx))/xres;
dy=(max(imgy)-min(imgy))/yres;
pnoiselevel=100;%mu=20
gnoiselevel=0.5;%50%
%===============================
realn=2;
realparam=[rand(realn,1)*(dx*xres)/2-(dx*xres)/4,...
    rand(realn,1)*(dy*yres)/2-(dy*yres)/4,...
    rand(realn,1)*0+3.5*dx,...
    rand(realn,1)*0+40];
realparam=sortrows(realparam,[1,2,4]);
pnoise=pnoiselevel*poissrnd(1,xres,yres);
gnoise=1+gnoiselevel*randn(xres,yres);
orgimg=gauss2dfunc(realparam,imgx,imgy).*gnoise+pnoise;
orgimg(orgimg>=satlevel)=satlevel;
%}
estn=3;
temp=findall(0,'Name','FIMAS');
rawdata=temp.Children(end).Children;
orgimg=rawdata.ZData;
xres=size(orgimg,1);
yres=size(orgimg,2);
imgx=rawdata.YData;imgx=imgx(:);
imgy=rawdata.XData;imgy=imgy(:);
dx=(max(imgx)-min(imgx))/xres;
dy=(max(imgy)-min(imgy))/yres;

bglev=nanmedian(orgimg(:));
pnoise=nanstd(orgimg(orgimg<=bglev));
gnoise=nanstd(orgimg(:));
satlevel=(nanmax(orgimg(:))+pnoise+gnoise)*1.1;
snl=log(nanmean(orgimg(:))/bglev);
fprintf('bg=%g\tpois=%g\tgauss=%g\tsat=%g\tsnl=%g\n',bglev,pnoise,gnoise,satlevel,snl);
orgimg(isnan(orgimg))=bglev;
%===============================
figure(100);
subplot(2,3,3);
%imagesc(imgy,imgx,orgimg,[0,max(orgimg(:))]);colormap('gray');
mesh(imgy,imgx,orgimg,'EdgeColor','none','FaceColor','interp');colormap('jet');view([0 -90]);
hold on;
%scatter(realparam(:,2),realparam(:,1),50,'k','filled');
title('original image');xlabel('y');ylabel('x');
%===============================

if snl<1
    tempimg=imgaussfilt(orgimg,1,'FilterSize',3,'Padding',bglev,'FilterDomain','spatial');
else
    tempimg=imgaussfilt(orgimg,1,'FilterSize',3,'Padding',bglev,'FilterDomain','spatial');
end
tempimg=tempimg-bglev;
subplot(2,3,1);
%imagesc(imgy,imgx,tempimg,[0,max(tempimg(:))]);
mesh(imgy,imgx,tempimg,'EdgeColor','none','FaceColor','interp');colormap('jet');view([0 -90]);
hold on;
%scatter(realparam(:,2),realparam(:,1),50,'k','filled');
title('filtered image');xlabel('y');ylabel('x');
%===============================
% estimate position in x axis
xprofile=nanmax(tempimg,[],2);
xprofile=xprofile(:);
[maxval,loc]=findpeaks(xprofile,'NPeaks',estn,'SortStr','descend');
if isempty(loc)
    [maxval,loc]=max(xprofile);
    peakpos=imgx(loc);
end
if numel(loc)<estn
    peakpos=[imgx(loc);(rand(estn-numel(loc),1)-0.5)*xres*dx+mean(imgx)];
else
    peakpos=imgx(loc);
end
xestimates=[peakpos,repmat([dx,satlevel/estn],estn,1)];
lb=repmat([min(imgx),dx/2,pnoise/estn],estn,1);
ub=repmat([max(imgx),5*dx,satlevel/estn],estn,1);
[xestimates,~,xexitflag] = fmincon(@chi2gaussfunc,xestimates,[],[],[],[],lb,ub,@mycon,options,imgx,xprofile,satlevel);
subplot(2,3,2);plot(xprofile,imgx,'bo');hold on;
for fidx=1:estn
    plot(gaussfunc(xestimates(fidx,:),imgx),imgx,'r-');
end
plot(gaussfunc(xestimates,imgx),imgx,'b--');
view([0 -90]);
title('x profile');ylabel('x');

% estimate position in y axis
yprofile=nanmax(tempimg,[],1);
yprofile=yprofile(:);
%{
for nloc=1:estn
    interval{nloc}=find(imgx<=(xestimates(nloc,1)+dx)&imgx>=(xestimates(nloc,1)-dx));
    [maxval(nloc),loc]=max(max(tempimg(interval{nloc},:),[],1));
    yestimates(nloc,:)=[imgy(loc),xestimates(nloc,2:3)];
    if nloc>1&&~isempty(find((yestimates(nloc,1)>(yestimates(1:nloc-1,1)-2*dy))&(yestimates(nloc,1)<(yestimates(1:nloc-1,1)+2*dy))))
       % too close to previous ones
       yestimates(nloc,1)=yestimates(nloc-1,1)+(rand(1,1)-0.5)*(yres)*dy;
    end
end
interval=cellfun(@(x)x(:)',interval,'UniformOutput',false);
interval=[interval{:}];
localyprofile=max(tempimg(min(interval):max(interval),:),[],1);
localyprofile=localyprofile(:);
ymin=max(yestimates(:,1)-dy,-1);ymax=min(yestimates(:,1)+dy,1);
lb=[ymin,repmat([dy/2,pnoise/estn],estn,1)];
ub=[ymax,repmat([5*dy,satlevel/estn],estn,1)];
%}
%{
[maxval,loc]=findpeaks(yprofile,'NPeaks',estn,'SortStr','descend');
if isempty(loc)
    [maxval,loc]=max(yprofile);
    peakpos=imgx(loc);
end
if numel(loc)<estn
    peakpos=[imgy(loc);(rand(estn-numel(loc),1)-0.5)*yres*dy+mean(imgy)];
else
    peakpos=imgy(loc);
end
%}
yestimates=[peakpos,repmat([dy,satlevel/estn],estn,1)];
lb=repmat([min(imgy),dy/2,pnoise/estn],estn,1);
ub=repmat([max(imgy),5*dy,satlevel/estn],estn,1);
[yestimates,~,yexitflag] = fmincon(@chi2gaussfunc,yestimates,[],[],[],[],lb,ub,@mycon,options,imgy,yprofile,satlevel);
subplot(2,3,4);
plot(imgy,yprofile,'bo');hold on;
%plot(imgy,localyprofile,'bo');hold on;
for fidx=1:estn
    plot(imgy,gaussfunc(yestimates(fidx,:),imgy),'r-');
end
plot(imgy,gaussfunc(yestimates,imgy),'b--');
title('y profile');xlabel('y');
%===============================
%{
[~,sigorder]=sortrows(xestimates,[3,2],'descend');
xestimates=xestimates(sigorder,:);
[~,sigorder]=sortrows(yestimates,[3,2],'descend');
yestimates=yestimates(sigorder,:);
%}

% 2d gauss fit
bglev=median(orgimg(:));
estimates=[xestimates(:,1),yestimates(:,1),min([xestimates(:,2),yestimates(:,2)],[],2),max([xestimates(:,3),yestimates(:,3)],[],2)];
%tempimg(tempimg<=bglev)=0;
xmin=max(xestimates(:,1)-5*dx,-0.5);xmax=min(xestimates(:,1)+5*dx,0.5);
ymin=max(yestimates(:,1)-5*dy,-0.5);ymax=min(yestimates(:,1)+5*dy,0.5);
%xmin=repmat(min(imgx),estn,1);xmax=repmat(max(imgx),estn,1);
%ymin=repmat(min(imgy),estn,1);ymax=repmat(max(imgy),estn,1);
%lb=repmat([min(imgx)-0.2,min(imgy)-0.2,0.01,bglev],n,1);
%ub=repmat([max(imgx)+0.2,max(imgy)+0.2,1,satlevel],n,1);
lb=[xmin,ymin,min([xestimates(:,2),yestimates(:,2)],[],2)*0.5,min([xestimates(:,3),yestimates(:,3)],[],2)*0.5];
ub=[xmax,ymax,max([xestimates(:,2),yestimates(:,2)],[],2)*1.3,max([xestimates(:,3),yestimates(:,3)],[],2)*1.5];
%lb=[xmin-0.15,ymin-0.15,estimates(:,3)*0.5,estimates(:,4)*0.5];
%ub=[xmax+0.15,ymax+0.15,estimates(:,3)*3,repmat(satlevel/estn,estn,1)];
[estimates,~,exitflag] = fmincon(@chi2gauss2dfunc,estimates,[],[],[],[],lb,ub,@mycon,optimset(options),imgx,imgy,orgimg-bglev,satlevel);

%[estimates,~,exitflag] = fmincon(@chi2gauss2dfunc,estimates,[],[],[],[],lb,ub,@mycon,optimset(options),imgx,imgy,tempimg,satlevel);

[~,sigorder]=sortrows(estimates,[4,3],'descend');
estimates=estimates(sigorder,:);
%===============================
% draw fitted image and real and estimated localisation
subplot(2,3,5);
fitimg=gauss2dfunc(estimates,imgx,imgy);
%imagesc(imgy,imgx,fitimg,[0,max(orgimg(:))]);
mesh(imgy,imgx,fitimg,'EdgeColor','none','FaceColor','interp');colormap('jet');view([0 -90]);
hold on;
scatter(estimates(:,2),estimates(:,1),80,'d','k');
scatter(yestimates(:,1),xestimates(:,1),80,'o','k');
%scatter(realparam(:,2),realparam(:,1),30,'k','filled');
title('fitted ');xlabel('y');ylabel('x');

% draw residual between fitted and original image
resimg=(fitimg-orgimg);
homo=graycoprops((sum(graycomatrix(resimg,'Offset',...
    cell2mat(arrayfun(@(x)x*[0 1;-1 1;-1 0;-1 -1;0 -1;1 -1;1 0;1 1],[1,2,3],'UniformOutput',false)'),...
    'Symmetric',true,'NumLevels',200),3)), 'Homogeneity');
subplot(2,3,6);
%imagesc(imgy,imgx,resimg,[-bglev,bglev]);
mesh(imgy,imgx,resimg,'EdgeColor','none','FaceColor','interp');colormap('jet');view([0 -90]);
title('residual (fit-org)/(org+1)');xlabel('y');ylabel('x');

% print out error values
fprintf('x=%g,y=%g,2d=%g\n----------\n',xexitflag,yexitflag,exitflag);
fprintf('x=%0.3f\ty=%0.3f\ts=%0.2f\tI=%0.2f\n----------\n',estimates');
estimates=sortrows(estimates,[1,2,4]);
esterr=((estimates))';
%{
esterr(1,:)=esterr(1,:)/dx*100;
esterr(2,:)=esterr(2,:)/dy*100;
esterr(3,:)=esterr(3,:)/realparam(:,3)'*100;
esterr(4,:)=esterr(4,:)/realparam(:,4)'*100;
%}
fprintf('dxpos = %0.1f%% of dx\tdypos = %0.1f%% of dy\tdvar = %0.1f%%\tdI = %0.1f%%\n----------\n',esterr);
fprintf('dx=%gnm\tdy=%gnm\nhomogeneity of residual = %g\n----------\n',dx*1000,dy*1000,homo.Homogeneity);

figure(101);
subplot(2,1,1);plot(imgy,mean(resimg,1));
subplot(2,1,2);plot(imgx,mean(resimg,2));
return;

function [c,ceq] = mycon(x,varargin)
if size(x,1)>1
    c = abs(diff(x(:,end-1:end),1))-0.05*mean(x(:,end-1:end),1); % distance between sigma and I must be smaller than 10% of mean ceq = [];
else
    c=[];
end
ceq=[];