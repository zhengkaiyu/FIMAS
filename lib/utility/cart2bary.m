function [ bary_coord ] = cart2bary( cart_coord, TR )
%CART2BARY Convert cartesian coordinate to barycentric coordinate
%   cart_coord = cartesian coordinate in 2D (nx2 vector of n points)
%   TR = Triangular points forming a triangle (3x2 vector of the vertices)

% check TR is 3x2

% check cart_coord is nx2

% convert
%method 1
tic;
%r
x=cart_coord(1,:);
y=cart_coord(2,:);
%r1,r2,r3
x1=TR(1,1);y1=TR(2,1);
x2=TR(1,2);y2=TR(2,2);
x3=TR(1,3);y3=TR(2,3);
%det(T)
det_T=(y2-y3)*(x1-x3)+(x3-x2)*(y1-y3);
%L1,L2,L3
L1=((y2-y3)*(x-x3)+(x3-x2).*(y-y3))/det_T;
L2=((y3-y1)*(x-x3)+(x1-x3).*(y-y3))/det_T;
L3=1-L1-L2;
%L
bary_coord=[L1;L2;L3];
toc

%method2
%{
tic;
bary_coord=zeros(3,size(cart_coord,1));
R=[TR';1,1,1];
for coord_idx=1:1:size(cart_coord,1)
    bary_coord(:,coord_idx)=R\[cart_coord(coord_idx,:)';1];
end
bary_coord=bary_coord';
toc
%}
end

