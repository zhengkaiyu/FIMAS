function result = dF_Ffunc( data, T_baseline, fluo_bg_idx )
%DF_RFUNC deltaF/F0 calculation for 5D data of the format CXYZT
%   

datasize=size(data);
% reshape data into tRT size
data=reshape(data,[datasize(1),prod(datasize(2:4)),datasize(5)]);
% f0 has no T dimension, so repmat for - operation
f0=repmat(mean(data(:,:,T_baseline),3),[1,1,datasize(5)]);

fbg=mean(mean(data(1,fluo_bg_idx,T_baseline),2),3);

result=(data-f0-2*fbg)./(f0-fbg);
result(isnan(result))=0;
result=reshape(result,[1,datasize(2:5)]);
end

