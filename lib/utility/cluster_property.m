function [clusterProp] = cluster_property(clusterpts,boundary)

clusterProp.centroid=[nan,nan];
clusterProp.spread=nan;
clusterProp.density=nan;
clusterProp.hullarea=nan;
clusterProp.numpts=nan;
clusterProp.hullPts=[];

if ~isempty(clusterpts)
    clusterpts=clusterpts(clusterpts(:,1)>=boundary(1,1)&clusterpts(:,1)<=boundary(2,1),:);
    clusterpts=clusterpts(clusterpts(:,2)>=boundary(1,2)&clusterpts(:,2)<=boundary(2,2),:);
    clusterProp.centroid=mean(clusterpts,1);
    clusterProp.spread=std(clusterpts,0,1);
    if size(clusterpts,1)>=3
        hullIndices=convhull(clusterpts(:,1),clusterpts(:,2));
        hullPts=clusterpts(hullIndices, :);
        hullArea=polyarea(hullPts(:,1),hullPts(:,2));
    else
        hullArea=0;
        hullPts=clusterpts;
    end
    clusterProp.density=size(clusterpts,1)/hullArea;
    clusterProp.hullarea=hullArea;
    clusterProp.numpts=size(clusterpts,1);
    clusterProp.hullPts=hullPts;
end