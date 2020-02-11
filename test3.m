% get scatter data nx2 matrix
global hDATA;

maxnmodel=3;
options = statset('MaxIter',1e4,'TolFun',1e-6,'Display','final');

psfwd=0.45; %500nm
psfsig = [psfwd,psfwd]/2.35;

sigdataidx=6;
posdataidx=7;
bglev=500;
%siginterval=[0,644;0,359;360,409;410,456;457,506;507,644];
%siginterval=[200,864;200,360;368,467;468,567;568,667;668,767;768,867];
siginterval=[200,360;368,378;468,478;568,578;668,678;768,778];
ninterval=size(siginterval,1);
figure(sigdataidx);clf;
for partidx=1:ninterval
    
    tdata=hDATA.data(sigdataidx).datainfo.T;
    timeidx=find(tdata>=siginterval(partidx,1)&tdata<=siginterval(partidx,2));
    
    xposdata=squeeze(hDATA.data(posdataidx).dataval(:,:,:,:,timeidx));
    xbound=[min(xposdata(:)),max(xposdata(:))];
    yposdata=squeeze(hDATA.data(posdataidx+1).dataval(:,:,:,:,timeidx));
    ybound=[min(yposdata(:)),max(yposdata(:))];
    posdata=[xposdata(:),yposdata(:)];
    
    sigdata=squeeze(hDATA.data(sigdataidx).dataval(:,:,:,:,timeidx))';
    sigdata=sigdata(:);
    
    threshold=quantile(sigdata,[0.1,0.9]);

    threshold=max(threshold(1)+std(sigdata)*1,threshold(2))
    threshold=max(threshold,bglev);
    responseidx=find(sigdata>threshold);
    rawdata=posdata(responseidx,1:2);
    
    data=[];
    % generate psf
    for ptdataidx=1:size(rawdata,1)
        data=[data;rawdata(1,:)];
        psfmu = rawdata(ptdataidx,:);
        psfgm = gmdistribution(psfmu,psfsig);    
        genpts=random(psfgm,round(0.1*(sigdata(responseidx(ptdataidx))-bglev)));
        data=[data;genpts];
    end
    
    % fit model
    for nmodel=1:maxnmodel
        GMModels{nmodel,partidx}=fitgmdist(data,nmodel,'ProbabilityTolerance',1e-9,'Replicates',1,'SharedCovariance',false,'Options',options);
    end
    
    for nmodel=1:maxnmodel
        fprintf('\n GM Mean for %i Component(s)\n',nmodel);
        meanpos=GMModels{nmodel,partidx}.mu';
        fprintf(' x=%1.3g y=%1.3g\n',meanpos);
        
        subplot(maxnmodel,ninterval,(nmodel-1)*ninterval+partidx);cla;
        h1=scatter(data(:,1),data(:,2),1,'r','filled');
        h = gca;
        hold on;
        
        h2=scatter(meanpos(1,:),meanpos(2,:),30,'ks','filled');
        fcontour(@(x1,x2)pdf(GMModels{nmodel,partidx},[x1 x2]),[h.XLim h.YLim]);
        title(sprintf('GM Model - %i Component(s)',nmodel));
        xlabel('x pos');ylabel('y pos');
        axis('equal');
        xlim(h,xbound);ylim(h,ybound);
        hold off;
    end
end

return;