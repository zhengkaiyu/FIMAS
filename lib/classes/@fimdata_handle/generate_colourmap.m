function [ scalemap_f ] = generate_colourmap( obj, axeshandle )
%GENERATE_COLOURMAP calculate intensity scale for colourmap images
%   Calculated intensity scaling for colourmap images based on their
%   ancester data values.
%

%% function check
index=obj.current_data;
scalemap_f=[];
ancester_index=[];
%get the parent data index
parent_index=obj.data(index).datainfo.parent_data_idx;
%get the original raw data for intensity map
while ~isempty(parent_index)
    ancester_index=parent_index;
    parent_index=obj.data(parent_index).datainfo.parent_data_idx;
end

if ~isempty(ancester_index)
    if ancester_index~=index
        % current data size so that colourmap size matches
        data_size=obj.data(index).datainfo.data_dim;
        scalemap_f=zeros([data_size,3]);%RGB
        intensity_map=repmat(nansum(obj.data(ancester_index).dataval,1),[data_size(1),1,1,1,1]);% intensity excludes t dim
        intensity_scale=repmat(intensity_map./max(intensity_map(:)),[ones(size(data_size)),3]);
        % check data size
        if isempty(find((size(intensity_scale)==[data_size,3])==0, 1))
            cmap=colormap(axeshandle,jet(obj.data(index).datainfo.t_disp_bound(3)));
            lb=obj.data(index).datainfo.t_disp_bound(1);
            ub=obj.data(index).datainfo.t_disp_bound(2);
            %loop through each parameter
            for p_idx=1:size(obj.data(index).dataval,1)
                for Z_idx=1:size(obj.data(index).dataval,4)
                    for T_idx=1:size(obj.data(index).dataval,5)
                        scalemap_f(p_idx,:,:,Z_idx,T_idx,:)=(ind2rgb(squeeze(floor((obj.data(index).dataval(p_idx,:,:,Z_idx,T_idx)-lb)./(ub-lb)*length(cmap))), cmap)).*squeeze(intensity_scale(p_idx,:,:,Z_idx,T_idx,:));
                    end
                end
            end
        else
            % data size mismatch
            disp('data size mismatch');
        end
    else
        % no parent data
        disp('parent data cannot be itself');
    end
else
    % no parent data
    disp('no parent data');
end
