function test
global hDATA;
warning off;
temp=hDATA.data(7);

datasize=temp.datainfo.data_dim;
npix=prod(datasize(2:4));
tempdata=reshape(temp.dataval,[npix,datasize(5)]);
weighted_count=zeros(npix,1);
for pixidx=1:npix
   temp=tempdata(pixidx,:);
   [pval,ploc]=findpeaks(temp,...
       'minpeakheight',0.2,...
       'minpeakdistance',10,...
       'threshold',0.001);
   %weighted_count(pixidx)=mean(ones(1,numel(ploc)).*pval);
   %figure(1);plot(tempdata(pixidx,:),'k');hold on;plot(temp,'r');plot(ploc,pval,'ro');hold off;
   weighted_count(pixidx)=numel(ploc);
end
    
result=reshape(weighted_count,[datasize(2),datasize(3)]);

figure(3);
mesh(result,'EdgeColor','interp','FaceColor','interp');
view([0,90]);