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
    % Initialize logging
    bfInitLogging();
    
    % Get the channel filler
    r = bfGetReader(filename, stitchFiles);
    
    % Test plane size
    planeSize = javaMethod('getPlaneSize', 'loci.formats.FormatTools', r);
    
    if planeSize/(1024)^3 >= 2,
        error(['Image plane too large. Only 2GB of data can be extracted '...
            'at one time. You can workaround the problem by opening '...
            'the plane in tiles.']);
    end
    
    numSeries = r.getSeriesCount();
    result = cell(numSeries, 2);
    
    globalMetadata = r.getGlobalMetadata();
    
    
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
        seriesMetadata = r.getSeriesMetadata();
        javaMethod('merge', 'loci.formats.MetadataTools', ...
            globalMetadata, seriesMetadata, 'Global ');
        field_array=seriesMetadata.keySet.toArray;
        val_array=seriesMetadata.values.toArray;
        for f_idx = 1:seriesMetadata.size
            f_name=cat(2,'f_',regexprep(field_array(f_idx),'\W',''));
            info.(f_name)=val_array(f_idx);
        end
        
        % extract xml data set
        xmlmetadatastore=r.getMetadataStore;
        xmlmetadata=char(xmlmetadatastore.dumpXML);
        %{
        [sm,sstart,send]=regexp(xmlmetadata,'<MetadataOnly/>','match');
        [~,~,~,~,temp]=regexp(xmlmetadata(1:sstart(1)-1),'[<|\s]([ a-zA-Z_0-9]*)="([ \.:a-zA-Z_0-9]*)"','match');
        %before <MetadataOnly/>
        for f_idx=1:numel(temp)
            f_name=cat(2,'xml_',regexprep(temp{f_idx}{1},'\W',''));
            info.(f_name)=temp{f_idx}{2};
        end
        %after <MetadataOnly/>
        [~,~,~,~,temp]=regexp(xmlmetadata(send(end)+1:end),'[<|\s]([ a-zA-Z_0-9]*)="([ \.:a-zA-Z_0-9]*)"','match');
        for f_idx=1:numel(temp)
            f_name=cat(2,'xml_',regexprep(temp{f_idx}{1},'\W',''));
            info.(f_name)=temp{f_idx}{2};
        end
        %<MetadataOnly/> section to get real timeing information
        %}
        [~,~,~,~,temp]=regexp(xmlmetadata,'[<|\s]([ a-zA-Z_0-9]*)="([ \.:a-zA-Z_0-9]*)"','match');
        pseudo_frame_idx=0;
        for f_idx=1:numel(temp)
            f_name=temp{f_idx}{1};
            switch f_name
                case {'Plane DeltaT'}
                    f_name=regexprep(f_name,'\s','_');
                    pseudo_frame_idx=pseudo_frame_idx+1;
                    if pseudo_frame_idx==1
                        scaninfo.(f_name)(1)=str2double(temp{f_idx}{2});
                    else
                        scaninfo.(f_name)(end+1)=str2double(temp{f_idx}{2});
                    end
                case {'DeltaTUnit','PositionZUnit'}
                    if pseudo_frame_idx==1
                        scaninfo.(f_name){1}=char(temp{f_idx}{2});
                    else
                        scaninfo.(f_name){end+1}=temp{f_idx}{2};
                    end
                case {'PositionZ','TheC','TheT','TheZ'}
                    if pseudo_frame_idx==1
                        scaninfo.(f_name)(1)=str2double(temp{f_idx}{2});
                    else
                        scaninfo.(f_name)(end+1)=str2double(temp{f_idx}{2});
                    end
                otherwise
                    f_name=cat(2,'xmlmeta_',regexprep(f_name,'\s','_'));
                    info.(f_name)=temp{f_idx}{2};
            end
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
                Z_start=str2double(info.f_GlobalAxis3ParametersCommonStartPosition);
                Z_end=str2double(info.f_GlobalAxis3ParametersCommonEndPosition);
                dZ=(Z_end-Z_start)/(sizeZ-1);
                obj.data(data_end_pos).datainfo.dZ=dZ;
                obj.data(data_end_pos).datainfo.Z=Z_start:dZ:Z_end;
            end
            %X-axis
            if sizeX>1
                X_start=str2double(info.f_GlobalAxis0ParametersCommonStartPosition);
                X_end=str2double(info.f_GlobalAxis0ParametersCommonEndPosition);
                dX=(X_end-X_start)/(sizeX-1);
                obj.data(data_end_pos).datainfo.dX=dX;
                obj.data(data_end_pos).datainfo.X=X_start:dX:X_end;
            end
            %Y-axis
            if sizeY>1
                Y_start=str2double(info.f_GlobalAxis1ParametersCommonStartPosition);
                Y_end=str2double(info.f_GlobalAxis1ParametersCommonEndPosition);
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
                [~,tidx]=unique(scaninfo.TheT);
                if sizeT==numel(tidx)
                    obj.data(data_end_pos).datainfo.dT=str2double(info.xmlmeta_TimeIncrement);
                    obj.data(data_end_pos).datainfo.T=scaninfo.Plane_DeltaT(tidx);
                else
                    T_start=str2double(info.f_GlobalAxis4ParametersCommonStartPosition);
                    T_end=str2double(info.f_GlobalAxis4ParametersCommonEndPosition);
                    dT=(T_end-T_start)/(sizeT-1);
                    obj.data(data_end_pos).datainfo.dT=dT;
                    obj.data(data_end_pos).datainfo.T=T_start:dT:T_end;
                end
                
            end
            
            %core meta infos
            obj.data(data_end_pos).datainfo.t_aquasition=str2double(info.f_GlobalTimePerSeries)/(1000*1000);%in seconds
            obj.data(data_end_pos).datainfo.digital_zoom=str2double(info.f_GlobalAcquisitionParametersCommonZoomValue);
            obj.data(data_end_pos).datainfo.optical_zoom=str2double(info.f_GlobalMagnification);
            
            obj.data(data_end_pos).datainfo.data_idx=obj.current_data;
            obj.data(data_end_pos).datainfo.data_dim=[1,sizeX,sizeY,sizeZ,sizeT];
            
            obj.data(data_end_pos).datatype=obj.get_datatype;
            obj.data(data_end_pos).datainfo.last_change=datestr(now);
            
            obj.data(data_end_pos).dataname=cat(2,info.f_GlobalFileInfoDataName,'_S',num2str(s),'_C',num2str(channel_idx));
            if isfield(info,'f_FileInfoUserComment')
                %if there are comments
                obj.data(data_end_pos).datainfo.note=info.f_GlobalFileInfoUserComment;
            end
        end
    end
    r.close();%close file
    message=sprintf('%g series from %g channels\n',numSeries,sizeC);
    status=true;
catch exception%error handle
    message=sprintf('%s\n',exception.message);
end