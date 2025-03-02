function f_xy = gauss2dsimplefunc(p,x,y)
% p = nx4 vector of which
% center = n x 2 vector of n [x,y] centers
% sigma = n x 1 vector of n sigma values for respective centers
% I = n x 1 vector of total intensity values (default volumn normalised)
% x,y dependent variables

% establish grid
[xr,yr]=meshgrid(x,y);
gridsize=size(xr);

% nice vector form
sigma=p(:,3);
amplitude=p(:,4);
nobj=numel(sigma);

% calculate value
gaussval = arrayfun(@(A,xc,yc,s)A*exp(-((xr-xc).^2+(yr-yc).^2)./(2*s^2)),amplitude,p(:,1),p(:,2),sigma,'UniformOutput',false);
f_xy = sum(reshape(cell2mat(gaussval'),[gridsize(1),gridsize(2),nobj]),3)';