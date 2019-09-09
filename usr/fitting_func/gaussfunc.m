function f = gaussfunc( p, x )
% parameters p (mx3) vector mu,sigma,A
% x is nx1 vector 
% f is nx1 vector
%f = ((p(1)/((4*pi*p(2)).^1.5))*exp(-((x-p(3)).^2)/(4*p(2))));
sigma=p(:,2);
amplitude = p(:,3)./(sigma * sqrt(2*pi));
gaussval = arrayfun(@(A,c,s)A*exp(-0.5*((x-c)/s).^2),amplitude,p(:,1),sigma,'UniformOutput',false);
f = sum(cell2mat(gaussval'),2);
end