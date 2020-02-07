function [ status, message ] = load_tiff_file( obj, filename )
%LOAD_TIFF_FILE load tiff formated images
%   mainly for exported images from LSM


%% function complete

% only limited ability to read tiff
% need new tiff read from object
status=false;
try
    info=imfinfo(filename,'TIFF');%get tiff file metainfo if exist
    
    if ~isempty(info)%data is valid
        
        data_end_pos=numel(obj.data);%get current number of data
        
        obj.data(data_end_pos+1)=obj.data(1);%add new data with template
        
        data_end_pos=data_end_pos+1;%increment to new end position
        
        obj.current_data=data_end_pos;%update current data index
        
        obj.data(data_end_pos).datainfo.data_idx=data_end_pos;%data index
        
        n_frame=numel(info);%number of frames in the tiff file
        
        info=info(1);%use the info of the first frame
        
        obj.data(data_end_pos).dataval=zeros(1,info.Width,info.Height,1,n_frame);%create data holder
        
        %create XYT data
        for img_idx=1:1:n_frame
            [img,~]=imread(filename,'TIFF','Index',img_idx);    %read individual frames
            switch ndims(img)
                case 3
                    obj.data(data_end_pos).dataval(1,:,:,:,img_idx)=double(rgb2gray(img))';  %copy over values into T slots
                case 2
                    obj.data(data_end_pos).dataval(1,:,:,:,img_idx)=double(img)';  %copy over values into T slots
            end
        end
        
        [pathname,filename,~]=fileparts(filename);%get filename
        obj.data(data_end_pos).dataname=filename;%copy over filename
        
        %pass on file information
        obj.data(data_end_pos).metainfo=info;
        if isempty(info.XResolution)
            info.XResolution=1;%default to one pixel
        end
        if isempty(info.YResolution)
            info.YResolution=1;%default to one pixel
        end
        
        obj.data(data_end_pos).datainfo.dt=1;
        obj.data(data_end_pos).datainfo.dX=info.XResolution;
        obj.data(data_end_pos).datainfo.dY=info.YResolution;
        obj.data(data_end_pos).datainfo.dZ=1;
        obj.data(data_end_pos).datainfo.dT=1;
        obj.data(data_end_pos).datainfo.X=linspace(0,info.XResolution*(info.Width-1),info.Width);
        obj.data(data_end_pos).datainfo.Y=linspace(0,info.YResolution*(info.Height-1),info.Height);
        obj.data(data_end_pos).datainfo.T=linspace(0,obj.data(data_end_pos).datainfo.dT*(n_frame-1),n_frame);
        
        if isfield(info,'Comment')
            obj.data(data_end_pos).datainfo.note=info.Comment;
        end
        
        obj.data(data_end_pos).datainfo.data_dim=[1,info.Width,info.Height,1,n_frame];
        obj.data(data_end_pos).datainfo.display_dim=boolean([0,1,1,0,n_frame>1]);
        obj.data(data_end_pos).datatype=obj.get_datatype;
        obj.data(data_end_pos).datainfo.last_change=datestr(now);
        message=sprintf('%s loaded\n',cat(2,pathname,filesep,filename));
        status = true;
    else
        message=sprintf('no data loaded\n');
    end
catch exception%error handle
    message=sprintf('%s\n',exception.message);
end
