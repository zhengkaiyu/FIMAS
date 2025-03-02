function [r, val, maxc] = calculate_rprofile(data, datainfo, parameter, roi)
% CALCULATE_RPROFILE Calculate radial profile around specified center
% Inputs:
%   data      : 2D/3D data matrix
%   datainfo  : Struct with X/Y coordinates and data dimensions
%   parameter : Struct with val_lb, val_ub, dr
%   roi       : Region of interest specification
% Outputs:
%   r         : Radial bin centers
%   val       : Average values per bin
%   maxc      : [Max value, Center coordinates]

% Combine NaN masking in single operation
data(data < parameter.val_lb | data > parameter.val_ub) = NaN;

% Extract grid coordinates
x_val = datainfo.X(:)'; % Ensure row vectors
y_val = datainfo.Y(:)';


switch roi.name
    case 'ALL'
        roi_idx=1:1:numel(x_val)*numel(y_val);
        %take center of the map
        %maxcol=round(length(y_val)/2);
        %maxrow=round(length(x_val)/2);
        % auto find maximum
        [maxval,maxidx]=nanmax(data(:));
        [maxrow,maxcol]=ind2sub([size(data)],maxidx);
        vertices=[y_val(maxcol),x_val(maxrow)];
    case 'CENTER'
        roi_idx=1:1:numel(x_val)*numel(y_val);
        %take center of the map
        vertices=roi.coord;
        maxcol=find(x_val>=vertices(1,1),1);
        maxrow=find(y_val>=vertices(1,2),1);
    otherwise
        roi_idx=roi.idx;
        vertices=roi.coord;
        maxcol=find(x_val>=vertices(1,1),1);
        maxrow=find(y_val>=vertices(1,2),1);
end

center=vertices(1,:);%
center=fliplr(center);%
maxc=[data(maxrow,maxcol),center];
[x_in_ind,y_in_ind,z_in_ind]=ind2sub(datainfo.data_dim(2:4),roi_idx);
length(x_in_ind)
x_trans_ind=x_val(x_in_ind)-center(1);
y_trans_ind=y_val(y_in_ind)-center(2);

[~,r]=cart2pol(y_trans_ind,x_trans_ind);

dr=parameter.dr;%*diff(datainfo.X(1:2));
new_r=min(r):dr:max(r);

[n,bin]=histc(r,new_r);
max_m=length(new_r);
re=zeros(1,max_m);
for m=1:max_m
    if n(m)>0
        %only calculate if there are members here
        in_idx=(bin==m);
        a_idx=sub2ind(size(data),x_in_ind(in_idx),y_in_ind(in_idx));
        re(m)=nanmean(data(a_idx));
    end
end
r=new_r;
val=re;
%plot(where_to,new_r,re,'Color','w','LineStyle','-','Marker','o','MarkerSize',6,'MarkerFaceColor','r');
%axis(where_to,'tight');
end