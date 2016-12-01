function [ status, message ] = load_olympus_oib_file( obj, filename )
%LOAD_OLYMPUS_OIB_FILE open olympus oib file format
% Open olympus oib microscopy images using Bio-Formats.

%% function complete
% assume worst
status=false;
try
    % initialise Open Microscopy Library
    autoloadBioFormats = 1;
    stitchFiles = 0;
    % load the Bio-Formats library into the MATLAB environment
    bfstatus = bfCheckJavaPath(autoloadBioFormats);
    assert(bfstatus, ['Missing Bio-Formats library. Either add loci_tools.jar '...
        'to the static Java path or add it to the Matlab path.']);
    % initialize logging
    loci.common.DebugTools.enableLogging('INFO');
    % Get the channel filler
    r = bfGetReader(filename, stitchFiles);
    %-----
    % Test plane size
    planeSize = loci.formats.FormatTools.getPlaneSize(r);
    
    if planeSize/(1024)^3 >= 2,
        error(['Image plane too large. Only 2GB of data can be extracted '...
            'at one time. You can workaround the problem by opening '...
            'the plane in tiles.']);
    end
    
    numSeries = r.getSeriesCount(); %number of series
    
    for s = 1:numSeries
        fprintf('Reading series #%d\n', s);
        r.setSeries(s - 1);
        pixelType = r.getPixelType();
        bpp = loci.formats.FormatTools.getBytesPerPixel(pixelType);
        bppMax = power(2, bpp * 8); %#ok<NASGU>
        
        numImages = r.getImageCount();%number slices
        sizeX = r.getSizeX();%x size
        sizeY = r.getSizeY();%y size
        sizeZ = r.getSizeZ();%z-stack size
        sizeC = r.getSizeC();%channel size
        sizeT = r.getSizeT();%time series size

        %preallocate
        imageList = cell( sizeC, 1 );
        imageList = cellfun(@(x)zeros(1,sizeX,sizeY,sizeZ,sizeT),imageList,'UniformOutput',false);
        
        for i = 1:numImages
            if mod(i, 10) == 0
                fprintf('frame#%g\n',i);
            end
            arr = bfGetPlane(r, i);%raw data value
            
            % save image plane and label into the list
            zct = r.getZCTCoords(i - 1);
            imageList{zct(2)+1}(1,:,:,zct(1)+1,zct(3)+1)=arr';
        end
        
        % extract metadata table for this series
        metadata=r.getMetadata();
        field_array=metadata.keySet.toArray;
        val_array=metadata.values.toArray;
        for f_idx = 1:metadata.size
            f_name=cat(2,'f_',regexprep(field_array(f_idx),'\W',''));
            info.(f_name)=val_array(f_idx);
        end
        
        % save images and metadata into our master series list
        for channel_idx=1:sizeC%loop through channels
            data_end_pos=numel(obj.data);
            obj.data(data_end_pos+1)=obj.data(1);%add new data
            data_end_pos=data_end_pos+1;
            obj.current_data=data_end_pos;
            
            %assing data metainfo
            obj.data(data_end_pos).metainfo=info;
            %assign data
            obj.data(data_end_pos).dataval=imageList{channel_idx};%Z is put into t
            
            %Z-axis
            if sizeZ>1
                Z_start=str2double(info.f_Axis3ParametersCommonStartPosition);
                Z_end=str2double(info.f_Axis3ParametersCommonEndPosition);
                dZ=(Z_end-Z_start)/(sizeZ-1);
                obj.data(data_end_pos).datainfo.dZ=dZ;
                obj.data(data_end_pos).datainfo.Z=Z_start:dZ:Z_end;
            end
            %X-axis
            if sizeX>1
                X_start=str2double(info.f_Axis0ParametersCommonStartPosition);
                X_end=str2double(info.f_Axis0ParametersCommonEndPosition);
                dX=(X_end-X_start)/(sizeX-1);
                obj.data(data_end_pos).datainfo.dX=dX;
                obj.data(data_end_pos).datainfo.X=X_start:dX:X_end;
            end
            %Y-axis
            if sizeY>1
                Y_start=str2double(info.f_Axis1ParametersCommonStartPosition);
                Y_end=str2double(info.f_Axis1ParametersCommonEndPosition);
                dY=(Y_end-Y_start)/(sizeY-1);
                if dY==0
                    Y_start=1;
                    Y_end=sizeY;
                    dY=(Y_end-Y_start)/(sizeY-1);
                end
                obj.data(data_end_pos).datainfo.dY=dY;
                obj.data(data_end_pos).datainfo.Y=Y_start:dY:Y_end;
            end
            %T-axis
            if sizeT>1
                T_start=str2double(info.f_Axis4ParametersCommonStartPosition);
                T_end=str2double(info.f_Axis4ParametersCommonEndPosition);
                dT=(T_end-T_start)/(sizeT-1);
                obj.data(data_end_pos).datainfo.dT=dT;
                obj.data(data_end_pos).datainfo.T=T_start:dT:T_end;
            end
            
            %core meta infos
            obj.data(data_end_pos).datainfo.t_aquasition=str2double(info.f_TimePerSeries)/(1000*1000);%in seconds
            obj.data(data_end_pos).datainfo.digital_zoom=info.f_AcquisitionParametersCommonZoomValue;
            obj.data(data_end_pos).datainfo.optical_zoom=info.f_Magnification;
            
            obj.data(data_end_pos).datainfo.data_idx=obj.current_data;
            obj.data(data_end_pos).datainfo.data_dim=[1,sizeX,sizeY,sizeZ,sizeT];
            
            obj.data(data_end_pos).datatype=obj.get_datatype;
            obj.data(data_end_pos).datainfo.last_change=datestr(now);
            
            obj.data(data_end_pos).dataname=cat(2,info.f_FileInfoDataName,'_S',num2str(s),'_C',num2str(channel_idx));
            if isfield(info,'f_FileInfoUserComment')
                %if there are comments
                obj.data(data_end_pos).datainfo.note=info.f_FileInfoUserComment;
            end
        end     
    end
    r.close();%close file
    message=sprintf('%g series from %g channels\n',numSeries,sizeC);
    status=true;
catch exception%error handle
    message=sprintf('%s\n',exception.message);
end