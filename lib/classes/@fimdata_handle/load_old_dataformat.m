function [ status, message ] = load_old_dataformat( obj, filename )
%LOAD_OLD_DATAFORMAT Summary of this function goes here
%   Detailed explanation goes here
% file for adding exported fimas files (edf)
temp=load(filename,'-mat');
% copy over all items inside the exported fim files
num_data=numel(temp.DATA.data);
for d_idx=2:1:num_data
    obj.data_add(temp.DATA.data(d_idx).dataname,[]);
    current_data=obj.current_data;
    obj.data(current_data).dataval=temp.DATA.data(d_idx).dataval;
    obj.data(current_data).metainfo=temp.DATA.data(d_idx).auxinfo;
    obj.data(current_data).current_roi=temp.DATA.data(d_idx).current_roi;
    % copy datainfo
    obj.data(current_data).datainfo.data_idx=current_data;
    offset=current_data-temp.DATA.data(d_idx).datainfo.data_idx;
    obj.data(current_data).datainfo.parent_data_idx=temp.DATA.data(d_idx).datainfo.parent_data+offset;
    op_func=temp.DATA.data(d_idx).datainfo.operator;
    if ~isempty(op_func)
        obj.data(current_data).datainfo.operator=regexprep(op_func,'f_','op_');
    end
    obj.data(current_data).datainfo.note=temp.DATA.data(d_idx).datainfo.note;
    fileinfo=dir(filename);
    obj.data(current_data).datainfo.last_change=fileinfo.date;
    obj.data(current_data).datainfo.T_acquisition=temp.DATA.data(d_idx).datainfo.t_aquasition;
    obj.data(current_data).datainfo.dt=temp.DATA.data(d_idx).datainfo.dt;
    obj.data(current_data).datainfo.dX=temp.DATA.data(d_idx).datainfo.dx;
    obj.data(current_data).datainfo.dY=temp.DATA.data(d_idx).datainfo.dy;
    datasize=size(temp.DATA.data(d_idx).dataval);
    switch numel(datasize)
        case 3
            obj.data(current_data).datainfo.data_dim=[datasize,1,1];
        case 2
            obj.data(current_data).datainfo.data_dim=[1,datasize,1,1];
        case 1
            obj.data(current_data).datainfo.data_dim=[datasize,1,1,1,1];
    end
    obj.data(current_data).datainfo.bin_dim=[temp.DATA.data(d_idx).datainfo.bin_t,...
        temp.DATA.data(d_idx).datainfo.bin_x,...
        temp.DATA.data(d_idx).datainfo.bin_y,1,1];
    obj.data(current_data).datainfo.t_display_bound=[temp.DATA.data(d_idx).datainfo.disp_lb,...
        temp.DATA.data(d_idx).datainfo.disp_ub,...
        temp.DATA.data(d_idx).datainfo.disp_levels];
    obj.data(current_data).datainfo.optical_zoom=temp.DATA.data(d_idx).datainfo.op_zoom;
    obj.data(current_data).datainfo.digital_zoom=temp.DATA.data(d_idx).datainfo.dig_zoom;
    obj.data(current_data).datainfo.mag_factor=temp.DATA.data(d_idx).datainfo.mag;
    obj.data(current_data).datainfo.scale_func=temp.DATA.data(d_idx).datainfo.scale_func;
    obj.data(current_data).datainfo.t=temp.DATA.data(d_idx).datainfo.t;
    obj.data(current_data).datainfo.X=temp.DATA.data(d_idx).datainfo.x;
    obj.data(current_data).datainfo.Y=temp.DATA.data(d_idx).datainfo.y;
    % update datatype
    obj.data(current_data).datatype=obj.get_datatype;
    nroi=numel(temp.DATA.data(d_idx).ROI);
    if nroi>1
        for r_idx=2:nroi
            obj.data(current_data).roi(r_idx).name=temp.DATA.data(d_idx).ROI(r_idx).name;
            obj.data(current_data).roi(r_idx).coord=temp.DATA.data(d_idx).ROI(r_idx).coord.getPosition;
            obj.data(current_data).roi(r_idx).idx=temp.DATA.data(d_idx).ROI(r_idx).idx;
            obj.data(current_data).roi(r_idx).type='impoly';
        end
        obj.roi_add('redraw');
    end
end
%return information and success status
message=sprintf('%g of fluorescent data added from %s\n',num_data,filename);
status=true;
end