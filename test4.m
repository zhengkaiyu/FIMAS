function [result,result_err]=test4(idx)
clc;
global hDATA;

options=struct('Display','off',...
    'MaxFunctionEvaluations',1e12,...
    'MaxIterations',1e12,...
    'OptimalityTolerance',1e-12,...
    'StepTolerance',1e-12,...
    'ConstraintTolerance',1e-12);

estn=1;     % estimated number of gaussian centers
bglev=1;    % background intensity
intscale=10;% scaling from intensity to random points

% data index definition
sigdataidx=idx;  % signal data index

% time interval definition
signalstart=[200;366;466;566;666;766];  % first interval must be background
%signalstart=[300;416;516;616;716;816];  % first interval must be background
bgdt=20;   % duration for the background
APdt=[20;20;20;20;20];
signalinterval=[signalstart,signalstart+[bgdt;APdt]];  % time intervals
ninterval=size(signalinterval,1);   % nubmer of intervals

% total time interval
tdata=hDATA.data(sigdataidx).datainfo.T;
% x and y interval
imgx=hDATA.data(sigdataidx).datainfo.X;imgx=imgx(:);
xbound=[imgx(1),imgx(end)];
dx=hDATA.data(sigdataidx).datainfo.dX;
imgy=hDATA.data(sigdataidx).datainfo.Y;imgy=imgy(:);
ybound=[imgy(1),imgy(end)];
dy=hDATA.data(sigdataidx).datainfo.dY;
[x,y]=meshgrid(imgy,imgx);
xres=numel(imgx);yres=numel(imgy);
%--------------------------------------------------------------------------
% initialise data holder
signaldata=squeeze(hDATA.data(sigdataidx).dataval);
result=nan(size(signalinterval,1),4*estn+1);
result_err=nan(size(signalinterval,1),4*estn);

figure(sigdataidx);clf;
nplotrow=5;nplotcol=ninterval;
%{
% reconstruct image through each time frame
for tidx=1:hDATA.data(sigdataidx).datainfo.data_dim(5)
    % get signal data slice
    sigdata=squeeze(hDATA.data(sigdataidx).dataval(:,:,:,:,tidx))';
    % get x and y position from scx and scy
    xposdata=squeeze(hDATA.data(posdataidx).dataval(:,:,:,:,tidx))';
    yposdata=squeeze(hDATA.data(posdataidx+1).dataval(:,:,:,:,tidx))';
    % empty position data storage
    data=cell(numel(xposdata),1);
    % generate psf
    for ptdataidx=1:numel(xposdata)
        % get mean position of psf
        psfmu = [xposdata(ptdataidx),yposdata(ptdataidx)];
        % make psf guasssian pdf
        psfgm = gmdistribution(psfmu,psfsig);
        % generate randome points
        genpts=random(psfgm,round(max(1,intscale*(sigdata(ptdataidx)-bglev))));
        % append points to list
        data{ptdataidx}=genpts;
    end
    % make intensity distribution from point list data
    data=cell2mat(data);
    [Nphoton,Xedges,Yedges] = histcounts2(data(:,1),data(:,2),Xedges,Yedges);
%{
    [Ndwell,Xedges,Yedges] = histcounts2(xposdata,yposdata,Xedges,Yedges);
    temp=Nphoton./Ndwell;
    temp(isnan(temp)|isinf(temp))=0;
%}
    % assign to filterdata storage
    filterdata(:,:,tidx)=Nphoton;
end
%}
%--------------------------------------------------------------------------
% fitting gaussian through intervals time lapsed through interval (APs)
for partidx=1:size(signalinterval,1)
    % find time interval
    fail=false;
    timeidx=(tdata>=signalinterval(partidx,1)&tdata<=signalinterval(partidx,2));
    % find corresponding images
    tempimg=squeeze(mean(signaldata(:,:,timeidx),3));
    if partidx==1
        % background image
        bgimg=tempimg;
        pnoiseimg=squeeze(std(signaldata(:,:,timeidx),0,3));
        titletext='background';
    else
        bgtimeidx=(tdata>=signalinterval(partidx,1)-bgdt&tdata<signalinterval(partidx,1));
        bgimg=squeeze(mean(signaldata(:,:,bgtimeidx),3));
        % subtract background image
        tempimg=tempimg-bgimg;
        titletext=sprintf('int%i|%g',partidx,signalinterval(partidx,1));
    end
    % get maximum intensity
    satlevel=max(tempimg(:));
    % get estimated minimum intensity
    pnoise=std(tempimg(:));
    
    % plot raw images in the first row
    subplot(nplotrow,nplotcol,partidx);
    mesh(x,y,tempimg,'FaceColor','interp','EdgeColor','none');
    xlim(gca,ybound);ylim(gca,xbound);
    axis('square');view([0 -90]);
    title(titletext);
    %------
    % estimate position in x axis
    % get xprofile
    xprofile=nanmean(tempimg,2);xprofile=xprofile(:);
    % plot xprofile
    subplot(nplotrow,nplotcol,nplotcol*1+partidx);
    plot(imgx,xprofile,'bo');hold on;
    title('x profile');
    % try and find peak position firsts
    if median(xprofile)>0
        [maxval,loc]=findpeaks(xprofile,'NPeaks',estn,'SortStr','descend');
        if isempty(loc)
            % if peak not found, use maximum
            [maxval,loc]=max(xprofile);
        end
        % if number of peak is less than wanted
        if numel(loc)<estn
            peakpos=[imgx(loc);(rand(estn-numel(loc),1)-0.5)*xres*dx+mean(imgx)];
        else
            peakpos=imgx(loc);
        end
        % make educated guess
        xinitestimates=[peakpos,repmat([dx,satlevel/estn],estn,1)];
        % set lower bound (center,sigma,amplitude)
        lb=repmat([xbound(1),dx,pnoise/estn],estn,1);
        % set upper bound (center,sigma,amplitude)
        ub=repmat([xbound(2),diff(xbound),satlevel/estn],estn,1);
        % try to fit 1D gaussian
        [xestimates,~,xexitflag,output] = fmincon(@chi2gaussfunc,xinitestimates,[],[],[],[],lb,ub,@mygausscon,options,imgx,xprofile,satlevel);
        if xexitflag>0
            for fidx=1:estn
                plot(imgx,gaussfunc(xestimates(fidx,:),imgx),'r--','Linewidth',3);
            end
            plot(imgx,gaussfunc(xestimates,imgx),'b-','Linewidth',3);
            ylim([0,max(maxval)]);
        else
            xestimates=xinitestimates;
            fprintf('%s\n',output.message);
        end
    else
        fail=true;
    end
    %------
    % estimate position in y axis
    % get y profile
    yprofile=nanmean(tempimg,1);yprofile=yprofile(:);
    % plot y profile
    subplot(nplotrow,nplotcol,nplotcol*2+partidx);
    plot(imgy,yprofile,'bo');hold on;
    title('y profile');
    if median(yprofile)>0
        % try and find peak position firsts
        [maxval,loc]=findpeaks(yprofile,'NPeaks',estn,'SortStr','descend');
        if isempty(loc)
            % if peak not found, use maximum
            [maxval,loc]=max(yprofile);
        end
        % if number of peak is less than wanted
        if numel(loc)<estn
            peakpos=[imgy(loc);(rand(estn-numel(loc),1)-0.5)*yres*dy+mean(imgy)];
        else
            peakpos=imgy(loc);
        end
        % make educated guess
        yinitestimates=[peakpos,repmat([dy,satlevel/estn],estn,1)];
        % set lower bound (center,sigma,amplitude)
        lb=repmat([ybound(1),dy,pnoise/estn],estn,1);
        % set upper bound (center,sigma,amplitude)
        ub=repmat([ybound(2),diff(ybound),satlevel/estn],estn,1);
        % try to fit 1D gaussian
        [yestimates,~,yexitflag,output] = fmincon(@chi2gaussfunc,yinitestimates,[],[],[],[],lb,ub,@mygausscon,options,imgy,yprofile,satlevel);
        if yexitflag>0
            for fidx=1:estn
                plot(imgy,gaussfunc(yestimates(fidx,:),imgy),'r--','Linewidth',3);
            end
            plot(imgy,gaussfunc(yestimates,imgy),'b-','Linewidth',3);
            ylim(sort([0,max(maxval)]));
        else
            yestimates=yinitestimates;
            fprintf('%s\n',output.message);
        end
    else
        fail=true;
    end
    if ~fail
        %--------
        % 2d gaussian estimates
        % use xesitmate and yestimate to make a educated guess
        initestimates=[xestimates(:,1),yestimates(:,1),min([xestimates(:,2),yestimates(:,2)],[],2),max([xestimates(:,3),yestimates(:,3)],[],2)];
        % allow 5dx and 5dy variation from original estimate
        xmin=xestimates(:,1)-5*dx;xmax=xestimates(:,1)+5*dx;
        ymin=yestimates(:,1)-5*dy;ymax=yestimates(:,1)+5*dy;
        % make lower and upper bound
        lb=[xmin,ymin,min([xestimates(:,2),yestimates(:,2)],[],2)*0.5,min([xestimates(:,3),yestimates(:,3)],[],2)*0.5];
        ub=[xmax,ymax,max([xestimates(:,2),yestimates(:,2)],[],2)*1.5,max([xestimates(:,3),yestimates(:,3)],[],2)*1.5];
        % conditional function minimum search for a 2D gaussian
        [estimates,fval,exitflag,output] = fmincon(@chi2gauss2dfunc,initestimates,[],[],[],[],lb,ub,@mygausscon,optimset(options),imgx,imgy,tempimg,satlevel);
        if exitflag>0
            % standard error estimates using hessian output from fminunc (acucrate)
            [estimates,fval,exitflag,output,grad,hessian]=fminunc(@chi2gauss2dfunc,estimates,optimset(options),imgx,imgy,tempimg,satlevel);
            if exitflag>0
                % calcuate standard error of the estimated parameters
                est_stderr=sqrt(abs(diag(inv(hessian))));
            else
                est_stderr=nan(numel(estimates),1);
            end
            est_relerr=100*abs(est_stderr(:)./estimates(:));
            % plot fitted image
            subplot(nplotrow,nplotcol,nplotcol*3+partidx);
            fitimg=gauss2dfunc(estimates,imgx,imgy);
            mesh(x,y,fitimg,'EdgeColor','none','FaceColor','interp');colormap('jet');view([0 -90]);
            hold on;
            % plot estimated center
            scatter(estimates(:,2),estimates(:,1),30,'d','ko','filled');
            title('fitted');
            fprintf('fitted\nx=%1.3g\ty=%1.3g\tsig=%1.3g\tI=%1.3g\n',estimates)
            xlim(gca,ybound);ylim(gca,xbound);
            axis('square');view([0 -90]);
            
            % draw residual between fitted and original image
            resimg=(fitimg-tempimg);
            subplot(nplotrow,nplotcol,nplotcol*4+partidx);
            mesh(x,y,resimg,'EdgeColor','none','FaceColor','interp');colormap('jet');view([0 -90]);
            xlim(gca,ybound);ylim(gca,xbound);
            axis('square');view([0 -90]);
            title('residual');
            fprintf('residual\nx=%1.3g%%\ty=%1.3g%%\tsig=%1.3g%%\tI=%1.3g%%\n',est_relerr)
            
            subplot(nplotrow,nplotcol,nplotcol*2+partidx);
            plot(imgy,mean(fitimg,1),'g--','Linewidth',3);
            subplot(nplotrow,nplotcol,nplotcol*1+partidx);
            plot(imgx,mean(fitimg,2),'g--','Linewidth',3);
            
            I_total=trapz(imgx,trapz(imgy,fitimg,2));
            estimates=estimates';
            result(partidx,:)=[estimates(:)',I_total];
            result_err(partidx,:)=est_stderr;
        else
            fprintf('%s\n',output.message);
        end
    end
end
disp('done');
return;

