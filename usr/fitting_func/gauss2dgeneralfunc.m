function f_xy = gauss2dgeneralfunc(p,x,y)
% p = nx6 vector of which
% center = n x 2 vector of n [x,y] centers
% sigma = n x 2 vector of n sigma values for respective centers
% I = n x 1 vector of total intensity values
% x,y dependent variables

% establish grid
[xr,yr]=meshgrid(x,y);
gridsize=size(xr);

% nice vector form
I=p(:,5);
nobj=numel(I);
center=p(:,1:2);
sigma=p(:,3:4);
theta = p(:,6);

% calculate value
gaussval = arrayfun(@(A,d,xc,yc,sx,sy)...
    A*exp(-0.5*(...
    (((cosd(d)^2/sx^2)+(sind(d)^2/sy^2))*(xr-xc).^2) + ...
    (((-sind(2*d)/sx^2)+(sind(2*d)/sy^2))*(xr-xc).*(yr-yc)) + ...
    (((sind(d)^2/sx^2)+(cosd(d)^2/sy^2))*(yr-yc).^2))),...
    I,theta,center(:,1),center(:,2),sigma(:,1),sigma(:,2),'UniformOutput',false);
f_xy = sum(reshape(cell2mat(gaussval'),[gridsize(1),gridsize(2),nobj]),3)';