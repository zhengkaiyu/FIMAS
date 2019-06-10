function [ status, message ] = load_femtonic_mes_file( obj, filename )
%LOAD_FEMTONIC_MES_FILE open femtonics mes file format
%   each channel is assigned in dt space

%% function complete
status=false;message='start loading femtonic mes file';
try
    % load mes file from matlab format
    raw_data=load(filename,'-mat');
    % get variable names
    dataname=fieldnames(raw_data);
    % find data variables, Data field temp_data.Df*
    isdata=find(cellfun(@(x)~isempty(regexp(x,'(Df|DF)\d*', 'once')),dataname));
    struct_data=cellfun(@(x)raw_data.(x),dataname(isdata),'UniformOutput',false);
    dataname=dataname(isdata);
    % get measurement time and comment for each data item
    timestr=cell2mat(cellfun(@(x)datevec(x(1).MeasurementDate,'yyyy.mm.dd. HH:MM:SS,FFF'),struct_data,'UniformOutput',false));
    commentstr=cellfun(@(x)char(x(1).Comment),struct_data,'UniformOutput',false);
    % sort data by measurement time
    [~,measure_order]=sortrows(timestr,[1 2 3 4 5 6]);
    timestr=datestr(timestr(measure_order,:),'yyyy-mm-dd|HH:MM:SS');
    datalist=[char(dataname(measure_order)),repmat('|',numel(measure_order),1),timestr,repmat('|',numel(measure_order),1),char(commentstr(measure_order))];
    % ask user to select data to import
    set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
    set(0,'DefaultUicontrolForegroundColor','k');
    [selected,answer]=listdlg('Name','Select Data Item','PromptString','Which data items?','OKString','Load','ListString',datalist,'ListSize',[400,500],'InitialValue',1:1:numel(measure_order));
    set(0,'DefaultUicontrolBackgroundColor','k');
    set(0,'DefaultUicontrolForegroundColor','w');
    if answer
        % ok pressed
        % short filename for all data items
        [~,name,~]=fileparts(filename);
        % update selected to real index in case measurement time sorting
        selected=measure_order(selected)';
        % get name of selected data
        seldata=dataname(selected);
        % number of selected data
        ndata=numel(seldata);
        % load structured data first then work out actual data for them
        for dataidx=1:ndata
            % make progress bar
            if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
                % Report current estimate in the waitbar's message field
                done=dataidx/ndata;
                waitbar(done,waitbar_handle,sprintf('%3.1f%%',100*done));
            else
                % create waitbar if it doesn't exist
                waitbar_handle = waitbar(0,'Please wait...','Progress Bar','Calculating...',...
                    'CreateCancelBtn',...
                    'setappdata(gcbf,''canceling'',1)',...
                    'WindowStyle','normal',...
                    'Color',[0.2,0.2,0.2]);
                setappdata(waitbar_handle,'canceling',0);
            end
            % go through selected dataset
            dataitem=struct_data{selected(dataidx)};
            % find subset of types
            subsetidx=find(cellfun(@(x)~isempty(x),{dataitem.Type}));
            % determine how many types are in the struct data
            imgtypes=unique({dataitem(subsetidx).Type});
            if numel(imgtypes)>1 % multiple type of images
                % add end cap
                subsetidx=[subsetidx,numel(dataitem)+1];
            else
                % add end cap
                subsetidx=[1,numel(dataitem)+1];
            end
            scanline=[];
            % loop through each subset
            for scanidx=1:numel(subsetidx)-1
                % get subset scan index
                imgidx=subsetidx(scanidx):1:subsetidx(scanidx+1)-1;
                % get channel ids
                Channels=unique({dataitem(imgidx).Channel},'stable');
                % channel name list
                datainfo.ch_name=cell2mat((cellfun(@(x)sprintf('%s|',x),Channels,'UniformOutput',false)));
                datainfo.ch_name=datainfo.ch_name(1:end-1);
                % number of channels
                nCh=numel(Channels);
                % get image file ref
                ifname={dataitem(imgidx).IMAGE};
                % number of images
                nimg=numel(ifname);
                % load raw images
                tempdata=cell(nimg,1);
                for tempidx=1:nimg
                    tempdata{tempidx}=double(raw_data.(ifname{tempidx}));
                end
                % Ch info
                datainfo.t=1:1:nCh;
                datainfo.dt=1;
                % get metainfo from first image in the subset
                metainfo=getmetainfo(dataitem(imgidx(1)));
                % go through each image
                switch metainfo.Type
                    case 'Cam'% camera XY image
                        % add new data object
                        obj.data_add(sprintf('%s#%s%s',seldata{dataidx},'_cam_',name),[],[]);
                        % get current data position
                        data_end_pos=obj.current_data;
                        % X info
                        datainfo.X=linspace(metainfo.WidthOrigin,metainfo.WidthOrigin+(metainfo.Width-1)*metainfo.WidthStep,metainfo.Width);
                        datainfo.dX=metainfo.WidthStep;
                        % Y info
                        datainfo.Y=linspace(metainfo.HeightOrigin,metainfo.HeightOrigin+(metainfo.Height-1)*metainfo.HeightStep,metainfo.Height);
                        datainfo.dY=metainfo.HeightStep;
                        % Z info
                        datainfo.Z=metainfo.Zlevel;
                        datainfo.dZ=1;
                        % T info
                        datainfo.T=0;
                        datainfo.dT=1;
                        % get image ref (should be just one)
                        obj.data(data_end_pos).dataval(1,:,:,1,1)=cell2mat(raw_data);
                        % work out dimension size
                        datainfo.data_dim=[1,metainfo.Width,metainfo.Height,1,1];
                        % no scanline info needed
                        datainfo.scanline=[];
                        status=true;
                    case 'XY'%images
                        switch metainfo.Context
                            case 'Background'% background XY image for linescans with scanline
                                % add new data object
                                obj.data_add(sprintf('%s#%s%s',seldata{dataidx},'_bg_',name),[],[]);
                                % get current data position
                                data_end_pos=obj.current_data;
                                % X info
                                datainfo.X=linspace(metainfo.WidthOrigin,metainfo.WidthOrigin+(metainfo.Width-1)*metainfo.WidthStep,metainfo.Width);
                                datainfo.dX=metainfo.WidthStep;
                                % Y info
                                datainfo.Y=linspace(metainfo.HeightOrigin,metainfo.HeightOrigin+(metainfo.Height-1)*metainfo.HeightStep,metainfo.Height);
                                datainfo.dY=metainfo.HeightStep;
                                % Z info
                                datainfo.Z=metainfo.Zlevel;
                                datainfo.dZ=1;
                                % T info
                                datainfo.T=0;
                                datainfo.dT=1;
                                % add data permute to move channel to front
                                obj.data(data_end_pos).dataval(:,:,:,1,1)=double(permute(reshape(cell2mat(tempdata),[metainfo.Width,numel(Channels),metainfo.Height]),[2,1,3]));
                                % work out dimension size
                                datainfo.data_dim=[nCh,metainfo.Width,metainfo.Height,1,1];
                                % datinfo.scanline from its parent
                                % should've been carried forward
                                
                                status=true;
                            case {'ZStack','Zstack'}% Zstack images XYZ
                                % add new data object
                                obj.data_add(sprintf('%s#%s%s',seldata{dataidx},'_zstack_',name),[],[]);
                                % get current data position
                                data_end_pos=obj.current_data;
                                % X info
                                datainfo.X=linspace(metainfo.WidthOrigin,metainfo.WidthOrigin+(metainfo.Width-1)*metainfo.WidthStep,metainfo.Width);
                                datainfo.dX=metainfo.WidthStep;
                                % Y info
                                datainfo.Y=linspace(metainfo.HeightOrigin,metainfo.HeightOrigin+(metainfo.Height-1)*metainfo.HeightStep,metainfo.Height);
                                datainfo.dY=metainfo.HeightStep;
                                if isfield(metainfo,'info_Posinfo')
                                    % Z info
                                    datainfo.Z=linspace(metainfo.info_Posinfo.zstart,metainfo.info_Posinfo.zstop,metainfo.info_Posinfo.znum);
                                    datainfo.dZ=metainfo.info_Posinfo.zstep;
                                else
                                    % Z info
                                    datainfo.Z=metainfo.Rect3D.xyz(3);
                                    datainfo.dZ=1;
                                end
                                % T info
                                datainfo.T=0;
                                datainfo.dT=1;
                                nZSlice=nimg/nCh;
                                if isfield(metainfo,'info_Posinfo')
                                    if metainfo.info_Posinfo.znum~=nZSlice
                                        message=sprintf('%s\nZ slice number inconsistencies.',message);
                                    else
                                        nZSlice=metainfo.info_Posinfo.znum;
                                    end
                                else
                                    message=sprintf('%s\nZ Slice number missing.',message);
                                    datainfo.Z=datainfo.Z(1:nZSlice);
                                end
                                % add data permute to move channel to front
                                obj.data(data_end_pos).dataval(:,:,:,:,1)=permute(reshape(cell2mat(tempdata),[metainfo.Width,numel(Channels),nZSlice,metainfo.Height]),[2,1,4,3]);
                                % work out dimension size
                                datainfo.data_dim=[nCh,metainfo.Width,metainfo.Height,nZSlice,1];
                                % no scanline info needed
                                datainfo.scanline=[];
                                status=true;
                            case 'Photo'% single XY image captured
                                % add new data object
                                obj.data_add(sprintf('%s#%s%s',seldata{dataidx},'_photo_',name),[],[]);
                                % get current data position
                                data_end_pos=obj.current_data;
                                % X info
                                datainfo.X=linspace(metainfo.WidthOrigin,metainfo.WidthOrigin+(metainfo.Width-1)*metainfo.WidthStep,metainfo.Width);
                                datainfo.dX=metainfo.WidthStep;
                                % Y info
                                datainfo.Y=linspace(metainfo.HeightOrigin,metainfo.HeightOrigin+(metainfo.Height-1)*metainfo.HeightStep,metainfo.Height);
                                datainfo.dY=metainfo.HeightStep;
                                % Z info
                                datainfo.Z=metainfo.Zlevel;
                                datainfo.dZ=1;
                                % T info
                                datainfo.T=0;
                                datainfo.dT=1;
                                % add data permute to move channel to front
                                obj.data(data_end_pos).dataval(:,:,:,1,1)=permute(reshape(cell2mat(tempdata),[metainfo.Width,numel(Channels),metainfo.Height]),[2,1,3]);
                                % work out dimension size
                                datainfo.data_dim=[nCh,metainfo.Width,metainfo.Height,1,1];
                                % no scanline info needed
                                datainfo.scanline=[];
                                status=true;
                            otherwise
                                return;
                        end
                    case 'Line2'%line scans into XT
                        % add new data object
                        obj.data_add(sprintf('%s#%s%s',seldata{dataidx},'_line2_',name),[],[]);
                        % get current data position
                        data_end_pos=obj.current_data;
                        % X info
                        datainfo.X=linspace(metainfo.WidthOrigin,metainfo.WidthOrigin+(metainfo.Width-1)*metainfo.WidthStep,metainfo.Width);
                        datainfo.dX=metainfo.WidthStep;
                        % Y info
                        datainfo.Y=0;
                        datainfo.dY=1;
                        % Z info
                        datainfo.Z=metainfo.Zlevel;
                        datainfo.dZ=1;
                        % T info
                        datainfo.T=linspace(metainfo.HeightOrigin,metainfo.HeightOrigin+(metainfo.Height-1)*metainfo.HeightStep,metainfo.Height);
                        datainfo.dT=metainfo.HeightStep;
                        % add data permute to move channel to front
                        obj.data(data_end_pos).dataval(:,:,1,1,:)=double(permute(reshape(cell2mat(tempdata),[metainfo.Width,numel(Channels),metainfo.Height]),[2,1,3]));
                        % work out dimension size
                        datainfo.data_dim=[nCh,metainfo.Width,1,1,metainfo.Height];
                        % assign scanline info for background image to capture
                        datainfo.scanline=metainfo.ScanLine;
                        status=true;
                    case 'FF'%folded frame XYT
                        % add new data object
                        obj.data_add(sprintf('%s#%s%s',seldata{dataidx},'_FF_',name),[],[]);
                        % get current data position
                        data_end_pos=obj.current_data;
                        % X info
                        datainfo.X=linspace(metainfo.WidthOrigin,metainfo.WidthOrigin+(metainfo.Width-1)*metainfo.WidthStep,metainfo.Width);
                        datainfo.dX=metainfo.WidthStep;
                        % Y info
                        nLines=metainfo.FoldedFrameInfo.numFrameLines;
                        datainfo.dY=metainfo.FoldedFrameInfo.TransverseStep;
                        datainfo.Y=linspace(0,datainfo.dY*(nLines-1),nLines);
                        % Z info
                        datainfo.Z=metainfo.Zlevel;
                        datainfo.dZ=1;
                        % T info
                        nFrames=metainfo.FoldedFrameInfo.numFrames;
                        tstart=metainfo.FoldedFrameInfo.firstFrameStartTime;
                        datainfo.dT=metainfo.FoldedFrameInfo.frameTimeLength;%ms
                        datainfo.T=linspace(tstart,tstart+datainfo.dT*(nFrames-1),nFrames);
                        framecropstart=metainfo.FoldedFrameInfo.firstFramePos;
                        framecropend=framecropstart+nLines*nFrames-1;
                        % get data
                        tempdata=cellfun(@(x)x(:,framecropstart:framecropend),tempdata,'UniformOutput',false);
                        % add data
                        obj.data(data_end_pos).dataval(:,:,:,1,:)=permute(reshape(cell2mat(tempdata),[metainfo.Width,nCh,nLines,nFrames]),[2,1,3,4]);
                        % work out dimension size
                        datainfo.data_dim=[nCh,metainfo.Width,nLines,1,nFrames];
                        % assign scanline info for background image to capture
                        datainfo.scanline=metainfo.ScanLine;
                        status=true;
                    otherwise
                        message=sprintf('%s\nUnable t process image type %s yet',message,metainfo.Type);
                end
                % copy over metainfo
                obj.data(data_end_pos).metainfo=metainfo;
                % copy over datainfo
                obj.data(data_end_pos).datainfo.dt=datainfo.dt;
                obj.data(data_end_pos).datainfo.dX=datainfo.dX;
                obj.data(data_end_pos).datainfo.dY=datainfo.dY;
                obj.data(data_end_pos).datainfo.dZ=datainfo.dZ;
                obj.data(data_end_pos).datainfo.dT=datainfo.dT;
                obj.data(data_end_pos).datainfo.t=datainfo.t;
                obj.data(data_end_pos).datainfo.X=datainfo.X;
                obj.data(data_end_pos).datainfo.Y=datainfo.Y;
                obj.data(data_end_pos).datainfo.Z=datainfo.Z;
                obj.data(data_end_pos).datainfo.T=datainfo.T;
                % default bin size
                obj.data(data_end_pos).datainfo.bin_dim=[1,1,1,1,1];
                obj.data(data_end_pos).datainfo.data_dim=datainfo.data_dim;
                obj.data(data_end_pos).datainfo.parameter_space=datainfo.ch_name;
                obj.data(data_end_pos).datainfo.note=metainfo.Comment;
                obj.data(data_end_pos).datatype=obj.get_datatype;
                obj.data(data_end_pos).datainfo.ScanLine=datainfo.scanline;
                obj.data(data_end_pos).datainfo.last_change=datestr(datevec(metainfo.MeasurementDate,'yyyy.mm.dd. HH:MM:SS,FFF'),'dd-mmm-yyyy HH:MM:SS');
            end
            
        end
    else
        message=sprintf('%s\ndata load from %s cancelled',message,filename);
    end % close waitbar if exist
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
catch exception
    % error handle
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
    message=sprintf('%s\n%s',message,exception.message);
end
end
%========================================================================
function info=getmetainfo(item)
fname=fieldnames(item);
for fidx=1:numel(fname)
    switch fname{fidx}
        case {'info_Linfo','info_Protocol','info_PointsEx','ScanLine','viewline2refs'}
            if ~isempty(item.(fname{fidx}))
                subfname=fieldnames(item.(fname{fidx}));
                val=cellfun(@(x)item.(fname{fidx}).(x),subfname,'UniformOutput',false);
                for subfidx=1:numel(subfname)
                    info.(fname{fidx}).(subfname{subfidx})=val{subfidx};
                end
            else
                info.(fname{fidx})=[];
            end
        otherwise
            if isstruct(item.(fname{fidx}))
                % structured data
                switch fname{fidx}
                    case {'AUXi0','AUXi1','AUXi2'}
                        % create separate channels
                        if ~isempty(item.(fname{fidx}))
                            subfname=fieldnames(item.(fname{fidx}));
                            val=cellfun(@(x)item.(fname{fidx}).(x),subfname,'UniformOutput',false);
                            for subfidx=1:numel(subfname)
                                info.(fname{fidx}).(subfname{subfidx})=val{subfidx};
                            end
                        else
                            info.(fname{fidx})=[];
                        end
                    otherwise
                        if ~isempty(item.(fname{fidx}))
                            subfname=fieldnames(item.(fname{fidx}));
                            val=cellfun(@(x)item.(fname{fidx}).(x),subfname,'UniformOutput',false);
                            for subfidx=1:numel(subfname)
                                info.(fname{fidx}).(subfname{subfidx})=val{subfidx};
                            end
                        else
                            info.(fname{fidx})=[];
                        end
                end
            else
                % numerical or string data
                info.(fname{fidx})=item.(fname{fidx});
            end
    end
end
end