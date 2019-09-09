function [c,ceq] = mygausscon(x,varargin)
if size(x,1)>1
    c = abs(diff(x(:,end-1:end),1))-0.05*mean(x(:,end-1:end),1); % distance between sigma and I must be smaller than 10% of mean ceq = [];
else
    c=[];
end
ceq=[];