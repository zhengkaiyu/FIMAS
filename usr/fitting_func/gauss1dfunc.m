function f = gauss1dfunc( p, x )
% parameters p (mx3) vector mu,sigma,A of m gaussians
% x and f are nx1 vector
centers=p(:,1);
sigma=p(:,2);
amplitude = p(:,3);
gaussval = arrayfun(@(A,c,s)A*exp(-0.5*((x-c)/s).^2),amplitude,centers,sigma,'UniformOutput',false);
f = sum(cell2mat(gaussval'),2);
end