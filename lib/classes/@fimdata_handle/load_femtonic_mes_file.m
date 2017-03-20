function [ status, message ] = load_femtonic_mes_file( obj, filename )
%LOAD_FEMTONIC_MES_FILE open femtonics mes file format
%   each channel is assigned in dt space

%% function check
status=false;message='start loading femtonic mes file';
try
    % load mes file from matlab format
    raw_data=load(filename,'-mat');
    % get variable names
    data_name=fieldnames(raw_data);
    % find data variables, Data field temp_data.Df*
    isdata=find(cellfun(@(x)~isempty(x),regexp(data_name,'Df|DF')));
    temp_data=cellfun(@(x)raw_data.(x),data_name(isdata),'UniformOutput',false);
    timestr=cell2mat(cellfun(@(x)datevec(x(1).MeasurementDate,'yyyy.mm.dd. HH:MM:SS,FFF'),temp_data,'UniformOutput',false));
    commentstr=cellfun(@(x)char(x(1).Comment),temp_data,'UniformOutput',false);
    [~,measure_order]=sortrows(timestr,[1 2 3 4 5 6]);
    timestr=datestr(timestr(measure_order,:),'yyyy-mm-dd|HH:MM:SS');
    datalist=[char(data_name(isdata(measure_order))),repmat('|',numel(isdata),1),timestr,repmat('|',numel(isdata),1),char(commentstr(measure_order))];
    set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
    set(0,'DefaultUicontrolForegroundColor','k');
    [selected,answer]=listdlg('Name','Select Data Item','PromptString','Which data items?','OKString','Load','ListString',datalist,'ListSize',[400,500],'InitialValue',1:1:numel(isdata));
    set(0,'DefaultUicontrolBackgroundColor','k');
    set(0,'DefaultUicontrolForegroundColor','w');
    if answer
        % ok pressed
        % get proper index
        isdata=isdata(measure_order(selected))';
        % go through each data
        for data_idx=isdata
            % add new data object
            data_end_pos=numel(obj.data);
            obj.data(data_end_pos+1)=obj.data(1);
            data_end_pos=data_end_pos+1;
            obj.current_data=data_end_pos;
            % set data index
            obj.data(data_end_pos).datainfo.data_idx=data_end_pos;
            % go through selected dataset
            dataitem=temp_data{data_idx};
            % get metainfo from dataitem(1)
            metainfo=getmetainfo(dataitem(1));
            % copy over metainfo
            obj.data(data_end_pos).metainfo=metainfo;
            % set data name format filename_dataname_channelname
            [~,name,~]=fileparts(filename);
            obj.data(data_end_pos).dataname=cat(2,data_name{data_idx},'_',name);
            % retrieve actual images
            switch metainfo.Type
                case 'Cam'% camera image
                    Channels={metainfo.Channel};
                    % t/Ch info
                    % only has one channel
                    datainfo.t=1;
                    datainfo.dt=1;
                    % X info
                    datainfo.X=linspace(metainfo.WidthOrigin,metainfo.WidthOrigin+metainfo.Width*metainfo.WidthStep,metainfo.Width);
                    datainfo.dX=metainfo.WidthStep;
                    % Y info
                    datainfo.Y=linspace(metainfo.HeightOrigin,metainfo.HeightOrigin+metainfo.Height*metainfo.HeightStep,metainfo.Height);
                    datainfo.dY=metainfo.HeightStep;
                    % Z info
                    % no Z
                    datainfo.Z=0;
                    datainfo.dZ=0;
                    % T info
                    % single image
                    datainfo.T=0;
                    datainfo.dT=0;
                    % get image ref (should be just one)
                    ifname={dataitem.IMAGE};
                    obj.data(data_end_pos).dataval(1,:,:,1,1)=raw_data.(cell2mat(ifname));
                    datainfo.data_dim=[1,metainfo.Width,metainfo.Height,1,1];
                    % work out dimension size
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
                    obj.data(data_end_pos).datainfo.bin_dim=[1,1,1,1,1];
                    obj.data(data_end_pos).datainfo.data_dim=datainfo.data_dim;
                    ch_name=cell2mat((cellfun(@(x)sprintf('%s|',x),Channels,'UniformOutput',false)));
                    obj.data(data_end_pos).datainfo.parameter_space=ch_name(1:end-1);
                    %obj.data(data_end_pos).datainfo.T_acquisition=info.
                    obj.data(data_end_pos).datainfo.note=metainfo.Comment;
                    obj.data(data_end_pos).datatype=obj.get_datatype;
                    obj.data(data_end_pos).datainfo.last_change=datestr(now);
                    status=true;
                case 'XY'%images
                    switch metainfo.Context
                        case 'Zstack'
                            if isfield(metainfo,'info_Posinfo')
                                Channels=metainfo.info_Posinfo.channel;
                                % Z info
                                datainfo.Z=metainfo.info_Posinfo.zstart:metainfo.info_Posinfo.zstep:metainfo.info_Posinfo.zstop;
                                datainfo.dZ=metainfo.info_Posinfo.zstep;
                            else
                                Channels={dataitem.Channel};
                                % Z info
                                datainfo.Z=metainfo.Rect3D.xyz(3);
                                datainfo.dZ=0;
                            end
                            nCh=numel(Channels);
                            % t/Ch info
                            datainfo.t=1:1:nCh;
                            datainfo.dt=1;
                            % X info
                            datainfo.X=linspace(metainfo.WidthOrigin,metainfo.WidthOrigin+metainfo.Width*metainfo.WidthStep,metainfo.Width);
                            datainfo.dX=metainfo.WidthStep;
                            % Y info
                            datainfo.Y=linspace(metainfo.HeightOrigin,metainfo.HeightOrigin+metainfo.Height*metainfo.HeightStep,metainfo.Height);
                            datainfo.dY=metainfo.HeightStep;
                            
                            % T info
                            datainfo.T=0;
                            datainfo.dT=0;
                            ifname={dataitem.IMAGE};
                            nimg=numel(ifname);
                            nZSlice=nimg/nCh;
                            if isfield(metainfo,'info_Posinfo')
                                if metainfo.info_Posinfo.znum~=nZSlice;
                                   message=sprintf('%s\nZ slice number inconsistencies\n',message);
                                else
                                    nZSlice=metainfo.info_Posinfo.znum;
                                end
                            else
                                message=sprintf('Z Slice number missing\n');
                                datainfo.Z=datainfo.Z(1:nZSlice);
                            end
                            temp=cellfun(@(x)raw_data.(x),ifname,'UniformOutput',false);
                            obj.data(data_end_pos).dataval(:,:,:,:,1)=permute(reshape(cell2mat(temp),[metainfo.Width,metainfo.Height,numel(Channels),nZSlice]),[3,1,2,4]);
                            datainfo.data_dim=[nCh,metainfo.Width,metainfo.Height,nZSlice,1];
                        case 'Photo'
                            Channels=metainfo.info_Posinfo.channel;
                            nCh=numel(Channels);
                            % t/Ch info
                            datainfo.t=1:1:nCh;
                            datainfo.dt=1;
                            % X info
                            datainfo.X=linspace(metainfo.WidthOrigin,metainfo.WidthOrigin+metainfo.Width*metainfo.WidthStep,metainfo.Width);
                            datainfo.dX=metainfo.WidthStep;
                            % Y info
                            datainfo.Y=linspace(metainfo.HeightOrigin,metainfo.HeightOrigin+metainfo.Height*metainfo.HeightStep,metainfo.Height);
                            datainfo.dY=metainfo.HeightStep;
                            % Z info
                            datainfo.Z=metainfo.Zlevel;
                            datainfo.dZ=metainfo.info_Posinfo.dz;
                            % T info
                            datainfo.T=0;
                            datainfo.dT=0;
                            datainfo.data_dim=[nCh,metainfo.Width,metainfo.Height,1,1];
                            ifname={dataitem.IMAGE};
                            temp=cellfun(@(x)raw_data.(x),ifname,'UniformOutput',false);
                            obj.data(data_end_pos).dataval(:,:,:,1,1)=permute(reshape(cell2mat(temp),[metainfo.Width,metainfo.Height,numel(Channels)]),[3,1,2]);
                        otherwise
                            return;
                    end
                    % work out dimension size
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
                    obj.data(data_end_pos).datainfo.bin_dim=[1,1,1,1,1];
                    obj.data(data_end_pos).datainfo.data_dim=datainfo.data_dim;
                    ch_name=cell2mat((cellfun(@(x)sprintf('%s|',x),Channels,'UniformOutput',false)));
                    obj.data(data_end_pos).datainfo.parameter_space=ch_name(1:end-1);
                    %obj.data(data_end_pos).datainfo.T_acquisition=info.
                    obj.data(data_end_pos).datainfo.note=metainfo.Comment;
                    obj.data(data_end_pos).datatype=obj.get_datatype;
                    obj.data(data_end_pos).datainfo.last_change=datestr(now);
                    status=true;
                case 'Line2'%line scans
                    % XT
                    Channels=metainfo.viewline2refs.dgprstate.channellist';
                    nCh=numel(Channels);
                    nitem=numel(dataitem);
                    ifname={dataitem.IMAGE};
                    % t/Ch info
                    datainfo.t=1:1:nCh;
                    datainfo.dt=1;
                    % X info
                    datainfo.X=linspace(metainfo.WidthOrigin,metainfo.WidthOrigin+metainfo.Width*metainfo.WidthStep,metainfo.Width);
                    datainfo.dX=metainfo.WidthStep;
                    % Y info
                    datainfo.Y=1;
                    datainfo.dY=1;
                    % Z info
                    datainfo.Z=metainfo.Zlevel;
                    datainfo.dZ=1;
                    % T info
                    % T info
                    datainfo.T=linspace(metainfo.HeightOrigin,metainfo.HeightOrigin+metainfo.Height*metainfo.HeightStep,metainfo.Height);
                    datainfo.dT=metainfo.HeightStep;
                    % get data
                    temp=cellfun(@(x)raw_data.(x),ifname(1:nCh),'UniformOutput',false);
                    % add data
                    obj.data(data_end_pos).dataval(:,:,1,1,:)=permute(reshape(cell2mat(temp),[metainfo.Width,metainfo.Height,numel(Channels)]),[3,1,2]);
                    % work out dimension size
                    datainfo.data_dim=[nCh,metainfo.Width,1,1,metainfo.Height];
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
                    obj.data(data_end_pos).datainfo.bin_dim=[1,1,1,1,1];
                    obj.data(data_end_pos).datainfo.data_dim=datainfo.data_dim;
                    ch_name=cell2mat((cellfun(@(x)sprintf('%s|',x),Channels,'UniformOutput',false)));
                    obj.data(data_end_pos).datainfo.parameter_space=ch_name(1:end-1);
                    %obj.data(data_end_pos).datainfo.T_acquisition=info.
                    obj.data(data_end_pos).datainfo.note=metainfo.Comment;
                    obj.data(data_end_pos).datatype=obj.get_datatype;
                    obj.data(data_end_pos).datainfo.last_change=datestr(now);
                    scaninfo=metainfo.ScanLine;
                    % add background data
                    data_end_pos=numel(obj.data);
                    obj.data(data_end_pos+1)=obj.data(1);
                    data_end_pos=data_end_pos+1;
                    obj.current_data=data_end_pos;
                    % set data index
                    obj.data(data_end_pos).datainfo.data_idx=data_end_pos;
                    % go through selected dataset
                    dataitem=temp_data{data_idx};
                    % get metainfo from dataitem(1)
                    metainfo=getmetainfo(dataitem(nCh+1));
                    % copy over metainfo
                    obj.data(data_end_pos).metainfo=metainfo;
                    % set data name format filename_dataname_channelname
                    obj.data(data_end_pos).dataname=cat(2,data_name{data_idx},'_bg_',name);
                    % t/Ch info
                    datainfo.t=1:1:nCh;
                    datainfo.dt=1;
                    % X info
                    datainfo.X=linspace(metainfo.WidthOrigin,metainfo.WidthOrigin+metainfo.Width*metainfo.WidthStep,metainfo.Width);
                    datainfo.dX=metainfo.WidthStep;
                    % Y info
                    datainfo.Y=linspace(metainfo.HeightOrigin,metainfo.HeightOrigin+metainfo.Height*metainfo.HeightStep,metainfo.Height);
                    datainfo.dY=metainfo.HeightStep;
                    % Z info
                    datainfo.Z=metainfo.Zlevel;
                    datainfo.dZ=1;
                    % T info
                    datainfo.T=0;
                    datainfo.dT=0;
                    temp=cellfun(@(x)raw_data.(x),ifname(nCh+1:2*nCh),'UniformOutput',false);
                    % add data
                    obj.data(data_end_pos).dataval(:,:,:,1,1)=permute(reshape(cell2mat(temp),[metainfo.Width,metainfo.Height,numel(Channels)]),[3,1,2]);
                    % work out dimension size
                    datainfo.data_dim=[nCh,metainfo.Width,metainfo.Height,1,1];
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
                    obj.data(data_end_pos).datainfo.bin_dim=[1,1,1,1,1];
                    obj.data(data_end_pos).datainfo.data_dim=datainfo.data_dim;
                    ch_name=cell2mat((cellfun(@(x)sprintf('%s|',x),Channels,'UniformOutput',false)));
                    obj.data(data_end_pos).datainfo.parameter_space=ch_name(1:end-1);
                    %obj.data(data_end_pos).datainfo.T_acquisition=info.
                    obj.data(data_end_pos).datainfo.note=metainfo.Comment;
                    obj.data(data_end_pos).datatype=obj.get_datatype;
                    obj.data(data_end_pos).datainfo.ScanLine=scaninfo;
                    obj.data(data_end_pos).datainfo.last_change=datestr(now);
                    status=true;
                case 'FF'%folded frame
                    % folded frames
                    Channels=metainfo.FoldedFrameInfo.measureChannels';
                    nCh=numel(Channels);
                    nitem=numel(dataitem);
                    ifname={dataitem.IMAGE};
                    % t/Ch info
                    datainfo.t=1:1:nCh;
                    datainfo.dt=1;
                    % X info
                    datainfo.X=linspace(metainfo.WidthOrigin,metainfo.WidthOrigin+metainfo.Width*metainfo.WidthStep,metainfo.Width);
                    datainfo.dX=metainfo.WidthStep;
                    % Y info
                    nLines=metainfo.FoldedFrameInfo.numFrameLines;
                    datainfo.dY=metainfo.FoldedFrameInfo.TransverseStep;
                    datainfo.Y=datainfo.dY:datainfo.dY:datainfo.dY*nLines;
                    % Z info
                    datainfo.Z=metainfo.Zlevel;
                    datainfo.dZ=1;
                    % T info
                    nFrames=metainfo.FoldedFrameInfo.numFrames;
                    tstart=metainfo.FoldedFrameInfo.firstFrameStartTime;
                    datainfo.dT=metainfo.FoldedFrameInfo.frameTimeLength;%ms
                    datainfo.T=tstart:datainfo.dT:datainfo.dT*nFrames;
                    framecropstart=metainfo.FoldedFrameInfo.firstFramePos;
                    framecropend=nLines*nFrames;
                    % get data
                    temp=cellfun(@(x)raw_data.(x)(:,framecropstart:framecropend),ifname(1:nCh),'UniformOutput',false);
                    % add data
                    obj.data(data_end_pos).dataval(:,:,:,1,:)=permute(reshape(cell2mat(temp),[metainfo.Width,nLines,nFrames,numel(Channels)]),[4,1,2,3]);
                    % work out dimension size
                    datainfo.data_dim=[nCh,metainfo.Width,nLines,1,nFrames];
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
                    obj.data(data_end_pos).datainfo.bin_dim=[1,1,1,1,1];
                    obj.data(data_end_pos).datainfo.data_dim=datainfo.data_dim;
                    ch_name=cell2mat((cellfun(@(x)sprintf('%s|',x),Channels,'UniformOutput',false)));
                    obj.data(data_end_pos).datainfo.parameter_space=ch_name(1:end-1);
                    %obj.data(data_end_pos).datainfo.T_acquisition=info.
                    obj.data(data_end_pos).datainfo.note=metainfo.Comment;
                    obj.data(data_end_pos).datatype=obj.get_datatype;
                    obj.data(data_end_pos).datainfo.last_change=datestr(now);
                    scaninfo=metainfo.ScanLine;
                    % add background data
                    data_end_pos=numel(obj.data);
                    obj.data(data_end_pos+1)=obj.data(1);
                    data_end_pos=data_end_pos+1;
                    obj.current_data=data_end_pos;
                    % set data index
                    obj.data(data_end_pos).datainfo.data_idx=data_end_pos;
                    % go through selected dataset
                    dataitem=temp_data{data_idx};
                    % get metainfo from dataitem(1)
                    metainfo=getmetainfo(dataitem(nCh+1));
                    % copy over metainfo
                    obj.data(data_end_pos).metainfo=metainfo;
                    % set data name format filename_dataname_channelname
                    obj.data(data_end_pos).dataname=cat(2,data_name{data_idx},'_bg_',name);
                    % t/Ch info
                    datainfo.t=1:1:nCh;
                    datainfo.dt=1;
                    % X info
                    datainfo.X=linspace(metainfo.WidthOrigin,metainfo.WidthOrigin+metainfo.Width*metainfo.WidthStep,metainfo.Width);
                    datainfo.dX=metainfo.WidthStep;
                    % Y info
                    datainfo.Y=linspace(metainfo.HeightOrigin,metainfo.HeightOrigin+metainfo.Height*metainfo.HeightStep,metainfo.Height);
                    datainfo.dY=metainfo.HeightStep;
                    % Z info
                    datainfo.Z=metainfo.Zlevel;
                    datainfo.dZ=1;
                    % T info
                    datainfo.T=0;
                    datainfo.dT=0;
                    temp=cellfun(@(x)raw_data.(x),ifname(nCh+1:2*nCh),'UniformOutput',false);
                    % add data
                    obj.data(data_end_pos).dataval(:,:,:,1,1)=permute(reshape(cell2mat(temp),[metainfo.Width,metainfo.Height,numel(Channels)]),[3,1,2]);
                    % work out dimension size
                    datainfo.data_dim=[nCh,metainfo.Width,metainfo.Height,1,1];
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
                    obj.data(data_end_pos).datainfo.bin_dim=[1,1,1,1,1];
                    obj.data(data_end_pos).datainfo.data_dim=datainfo.data_dim;
                    ch_name=cell2mat((cellfun(@(x)sprintf('%s|',x),Channels,'UniformOutput',false)));
                    obj.data(data_end_pos).datainfo.parameter_space=ch_name(1:end-1);
                    %obj.data(data_end_pos).datainfo.T_acquisition=info.
                    obj.data(data_end_pos).datainfo.note=metainfo.Comment;
                    obj.data(data_end_pos).datatype=obj.get_datatype;
                    obj.data(data_end_pos).datainfo.ScanLine=scaninfo;
                    obj.data(data_end_pos).datainfo.last_change=datestr(now);
                    status=true;
                otherwise
                    message=sprintf('Unable t process image type %s yet',imgtype);
            end
        end
        message=sprintf('data loaded from %s\n',filename);
        
    else
        message=sprintf('data load from %s cancelled\n',filename);
    end
catch exception%error handle
    message=sprintf('%s\n',exception.message);
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