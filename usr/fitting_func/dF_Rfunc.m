function result = dF_Rfunc( data, fluo_idx, ref_idx, T_baseline, fluo_bg_idx, ref_bg_idx )
%DF_RFUNC deltaF/R calculation for 5D data of the format CXYZT
%   

datasize=size(data);
data=reshape(data,[datasize(1),prod(datasize(2:4)),datasize(5)]);
fluo=squeeze(mean(data(fluo_idx,:,:),1));
ref=squeeze(mean(data(ref_idx,:,:),1));
clear data;
% f0 has no T dimension, so repmat for - operation
f0=repmat(mean(fluo(:,T_baseline),2),[1,datasize(5)]);

fbg=mean(mean(fluo(fluo_bg_idx,T_baseline),2),3);
rbg=mean(mean(ref(ref_bg_idx,T_baseline),2),3);

result=(fluo-f0-2*fbg)./(ref-rbg);
result(isnan(result))=0;
result=reshape(result,[1,datasize(2:5)]);
end

