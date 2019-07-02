function [ status, message ] = load_olympus_oib_file( obj, filename )
%LOAD_OLYMPUS_OIB_FILE open olympus oib file format
% Open olympus oib microscopy images using Bio-Formats.

%% function complete
% assume worst
status=false;
message='';
try
    % initialise Open Microscopy Library
    autoloadBioFormats = 1;
    
    % load the Bio-Formats library into the MATLAB environment
    bfstatus = bfCheckJavaPath(autoloadBioFormats);
    assert(bfstatus, ['Missing Bio-Formats library. Either add loci_tools.jar '...
        'to the static Java path or add it to the Matlab path.']);
    
    % open file
    rawdata=bfopen(filename);
    % get num of series in the data
    numSeries=size(rawdata,1);
    
    % get global metadata
        metadata = rawdata{1, 2};
        metadataKeys = metadata.keySet().iterator();
        for metaidx=1:metadata.size()
            key = metadataKeys.nextElement();
            value = metadata.get(key);
            f_name=cat(2,'f_',regexprep(key,'\W',''));
            info.(f_name)=value;
        end
        % get global ome metadata
        omemetadata = rawdata{1,4};
        
    for sidx = 1:numSeries
        imgdata=[];
        % get series image data
        seriesdata=rawdata{sidx,1};
        numImages=size(seriesdata,1);
        
        % get dimension size
        for axisidx=0:1:str2double(info.f_GlobalAxisParameterCommonAxisCount)
            axisname=info.(cat(2,'f_GlobalAxis',num2str(axisidx),'ParametersCommonAxisCode'));
            axisstart=info.(cat(2,'f_GlobalAxis',num2str(axisidx),'ParametersCommonStartPosition'));
            axisend=info.(cat(2,'f_GlobalAxis',num2str(axisidx),'ParametersCommonEndPosition'));
            eval(sprintf('axissize=omemetadata.getPixelsSize%s(%g).getValue();',axisname,sidx-1));
            if axissize==1
                % single plane
                % make axis vector
                eval(sprintf('%s=%s;',axisname,axisstart));
                % get delta_axis
                eval(sprintf('d%s=0;',axisname));
                % assign axis size
                eval(sprintf('size%s=1;',axisname));
            else
                % make axis vector
                eval(sprintf('%s=linspace(%s,%s,%g);',axisname,axisstart,axisend,axissize));
                % get delta_axis
                eval(sprintf('d%s=%s(2)-%s(1);',axisname,axisname,axisname));
                % assign axis size
                eval(sprintf('size%s=%g;',axisname,axissize));
            end
        end
        
        % get actual image data
        for imgidx=1:numImages
            Cidx=cell2mat(regexp(seriesdata{imgidx,2},'(?<=(C=|C\?=))\d*(?=/)','match'));
            if isempty(Cidx)
                Cidx=':';
            end
            Zidx=cell2mat(regexp(seriesdata{imgidx,2},'(?<=(Z=|Z\?=))\d*(?=/)','match'));
            if isempty(Zidx)
                Zidx=':';
            end
            Tidx=cell2mat(regexp(seriesdata{imgidx,2},'(?<=(T=|T\?=))\d*(?=/)','match'));
            if isempty(Tidx)
                Tidx=':';
            end
            % getimage
            eval(sprintf('imgdata(%s,:,:,%s,%s)=double(seriesdata{%g,1})'';',Cidx,Zidx,Tidx,imgidx));
            
        end
        
        % channel names
        channelname = arrayfun(@(x)omemetadata.getChannelName(0,x).toCharArray()',C-1,'UniformOutput',false);
        channelname = sprintf('%s|',channelname{:});
        channelname = channelname(1:end-1);
        
        % create new data with preallocated data size
        obj.data_add(sprintf('%s_S#%g',info.f_GlobalFileInfoDataName,sidx),imgdata,[]);
        data_end_pos=numel(obj.data);
        
        % core dimension data
        obj.data(data_end_pos).datainfo.t=C;
        obj.data(data_end_pos).datainfo.X=X;
        obj.data(data_end_pos).datainfo.Y=Y;
        obj.data(data_end_pos).datainfo.Z=Z;
        obj.data(data_end_pos).datainfo.T=T;
        
        % core meta infos
        obj.data(data_end_pos).datainfo.parameter_space=channelname;
        global SETTING;
        obj.data(data_end_pos).datainfo.panel=SETTING.panel(2).handle;
        obj.data(data_end_pos).datainfo.t_aquasition=str2double(info.f_GlobalTimePerSeries)/1000;%in ms
        obj.data(data_end_pos).datainfo.digital_zoom=str2double(info.f_GlobalAcquisitionParametersCommonZoomValue);
        obj.data(data_end_pos).datainfo.optical_zoom=str2double(omemetadata.getObjectiveNominalMagnification(0,0));
        
        obj.data(data_end_pos).datatype=obj.get_datatype;
        obj.data(data_end_pos).datainfo.last_change=datestr(datevec(info.f_GlobalAcquisitionParametersCommonImageCaputreDate(2:end-1),'yyyy-mm-dd HH:MM:SS'),'dd-mmm-yyyy HH:MM:SS');
        
        if isfield(info,'f_FileInfoUserComment')
            %if there are comments
            obj.data(data_end_pos).datainfo.note=info.f_GlobalFileInfoUserComment;
        end
        % assing data metainfo
        obj.data(data_end_pos).metainfo=info;
        
        % add ROIs
        numROI=omemetadata.getROICount();
        for roiidx=0:numROI-1
            roiref=omemetadata.getROIID(roiidx);
            numshape=omemetadata.getShapeCount(roiidx);
            for shapeidx=0:numshape-1
                switch char(omemetadata.getShapeType(roiidx,shapeidx))
                    case 'Rectangle'
                       rectsize=fliplr(double([omemetadata.getRectangleWidth(roiidx,shapeidx),omemetadata.getRectangleHeight(roiidx,shapeidx)])');
                       rectorigin=fliplr(double([omemetadata.getRectangleX(roiidx,shapeidx),omemetadata.getRectangleY(roiidx,shapeidx)])')+[sizeY/2,sizeX/2];
                       position=[rectorigin-rectsize/2,rectsize].*[dY,dX,dY,dX];
                       obj.roi_add('imrect',position);
                    case 'Point'
                       position=fliplr(double([omemetadata.getPointX(roiidx,shapeidx),omemetadata.getPointY(roiidx,shapeidx)])'.*[dX,dY]);
                       obj.roi_add('impoint',position);
                    case 'Ellipse'
                       ellipsesize=fliplr(double([omemetadata.getEllipseRadiusX(roiidx,shapeidx),omemetadata.getEllipseRadiusY(roiidx,shapeidx)])');
                       ellipseorigin=fliplr(double([omemetadata.getEllipseX(roiidx,shapeidx),omemetadata.getEllipseY(roiidx,shapeidx)])');
                       position=[ellipseorigin-ellipsesize/2,ellipsesize].*[dY,dX,dY,dX];
                       obj.roi_add('imellipse',position);
                end
                current_roi=obj.data(data_end_pos).current_roi;
                obj.data(data_end_pos).roi(current_roi).name=sprintf('ROI%g_shape%g_%s',roiidx,shapeidx,char(omemetadata.getShapeType(roiidx,shapeidx)));
            end
        end
    end
    message=sprintf('%s\n%g series from %g channels',message,numSeries,sizeC);
    status=true;
catch exception%error handle
    message=sprintf('%s\n%s',message,exception.message);
end