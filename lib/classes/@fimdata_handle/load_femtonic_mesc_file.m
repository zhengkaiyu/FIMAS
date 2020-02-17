function [ status, message ] = load_femtonic_mesc_file( obj, filename )
%LOAD_FEMTONIC_MESC_FILE open femtonics mes file format
%   each channel is assigned in dt space

%% function complete
status=false;
message='start loading femtonic mesc file';
try
    persistent content row_idx;
    row_idx=1;content=[];
    % load mesc file structure info
    fileinfo=h5info(filename);
    % converts all fileinto into content
    readmetainfo(fileinfo,[]);
    % get variable names
    groupname=cellfun(@(x)x.GroupName,content,'UniformOutput',false);
    dataname=cellfun(@(x)x.DataName,content,'UniformOutput',false);
    isdata=find(cellfun(@(x)~isempty(x),dataname));
    % get measurement time and comment for each data item
    timestr=cellfun(@(x)x.MeasurementDatePosix,content(isdata),'UniformOutput',false);
    commentstr=cellfun(@(x)char(x.Comment),content(isdata),'UniformOutput',false);
    datalist=cellfun(@(x,y,z)[x,' | ',char(y),' | ',regexprep(z,'\s',';')],groupname(isdata),timestr,commentstr,'UniformOutput',false);
    % ask user to select data to import
    [selected,answer]=listdlg('Name','Select Data Item','PromptString','Which data items?','OKString','Load','ListString',datalist,'ListSize',[400,500],'InitialValue',1:1:numel(datalist));
    if answer
        % ok pressed
        % do the loading bit
        % get name of selected data
        seldata=dataname(isdata(selected));
        % get name of selected data
        ndata=numel(seldata);
        % load selected data and pass on metainfo
        for dataidx=1:ndata
            currentloadidx=isdata(selected(dataidx));
            % make progress bar
            if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
                % Report current estimate in the waitbar's message field
                done=(dataidx-1)/ndata;
                waitbar(done,waitbar_handle,sprintf('%3.1f%%',100*done));
            else
                % create waitbar if it doesn't exist
                waitbar_handle = waitbar(0,'Please wait...',...
                    'Name','Data Importing femtonics mes file',...
                    'Progress Bar','Calculating...',...
                    'CreateCancelBtn',...
                    'setappdata(gcbf,''canceling'',1)',...
                    'WindowStyle','normal',...
                    'Color',[0.2,0.2,0.2]);
                setappdata(waitbar_handle,'canceling',0);
            end
            % go through selected dataset
            dataitemname=groupname{currentloadidx};
            % get number of dataset within the group
            ndataset=numel(dataname{currentloadidx});
            % get datainfo for the current selected set
            metainfo=content{currentloadidx};
            % add new data object
            obj.data_add(sprintf('%s',dataitemname),[],[]);
            % get current data position
            data_end_pos=obj.current_data;
            % get basic image info
            %imginfo=metainfo.MeasurementParamsXML.Task.Params.param;
            % get metainfo fieldnames
            metafname=fieldnames(metainfo);
            % find channel names
            metafnameidx=find(cellfun(@(x)~isempty(x),regexp(metafname,'Channel_\d_Name')));
            metafname=metafname(metafnameidx);
            ch_name=cell2mat(cellfun(@(x)[metainfo.(x)(1:end-1),'|'],metafname,'UniformOutput',false)');
            nCh=numel(metafname);
            % C info
            datainfo.t=1:1:nCh;
            datainfo.dt=1;
            datainfo.ch_name=ch_name(1:end-1);
            % X info
            dimsize=double(metainfo.XDim);
            dimoffset=double(metainfo.XAxisConversionConversionLinearOffset);
            dimres=double(metainfo.XAxisConversionConversionLinearScale);
            datainfo.X=([1:1:dimsize]-1)*dimres+dimoffset;
            datainfo.dX=dimres;
            nX=dimsize;
            % Y info
            dimsize=double(metainfo.YDim);
            dimoffset=double(metainfo.YAxisConversionConversionLinearOffset);
            dimres=double(metainfo.YAxisConversionConversionLinearScale);
            datainfo.Y=([1:1:dimsize]-1)*dimres+dimoffset;
            datainfo.dY=dimres;
            nY=dimsize;
            % Z/T info
            dimsize=double(metainfo.ZDim);
            dimoffset=double(metainfo.ZAxisConversionConversionLinearOffset);
            dimres=double(metainfo.ZAxisConversionConversionLinearScale);
            switch metainfo.ZAxisConversionTitle(1:end-1)
                case 't'
                    % time lapse images
                    datatype='Tstack';
                    %find z absolute position
                    %fieldpos=find(cell2mat(cellfun(@(x,y)(strcmp(x,'SlowZ')&strcmp(y,'AttributePosition')),{metainfo.MeasurementParamsXML.Task.AxisControl.snapshot.axis.id},{metainfo.MeasurementParamsXML.Task.AxisControl.snapshot.axis.attribute},'UniformOutput',false)));
                    %datainfo.Z=metainfo.MeasurementParamsXML.Task.AxisControl.snapshot.axis(fieldpos).value;
                    datainfo.Z=metainfo.GeomTransTransl(3);
                    datainfo.dZ=0;
                    nZ=1;
                    datainfo.T=([1:1:dimsize]-1)*dimres+dimoffset;
                    datainfo.dT=dimres;
                    nT=dimsize;
                case 'z'
                    % slow z stack
                    datatype='slowzstack';
                    datainfo.Z=([1:1:dimsize]-1)*dimres+dimoffset;
                    datainfo.dZ=dimres;
                    nZ=dimsize;
                    datainfo.T=dataidx;
                    datainfo.dT=0;
                    nT=1;
            end
            for datasetidx=1:ndataset
                % load rawdata
                rawdata=h5read(filename,dataname{currentloadidx}{datasetidx});
                % get image scaling parameters
                imgscale=double(metainfo.([metafname{datasetidx}(1:end-4),'Conversion_ConversionLinearScale']));
                imgoffset=double(metainfo.([metafname{datasetidx}(1:end-4),'Conversion_ConversionLinearOffset']));
                % use datainfo to rearrange data
                switch datatype
                    case 'Tstack'
                        % work out dimension size
                        obj.data(data_end_pos).dataval(datasetidx,:,:,1,:)=double(rawdata)*imgscale+imgoffset;
                        datainfo.display_dim=boolean([0,1,1,0,1]);
                    case 'slowzstack'
                        % work out dimension size
                        obj.data(data_end_pos).dataval(datasetidx,:,:,:,1)=double(rawdata)*imgscale+imgoffset;
                        datainfo.display_dim=boolean([0,1,1,1,0]);
                end
            end
            datainfo.data_dim=[nCh,nX,nY,nZ,nT];
            % merge fileinfo and datainfo
            metainfo=setstructfields(content{1},metainfo);
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
            obj.data(data_end_pos).datainfo.display_dim=datainfo.display_dim;
            obj.data(data_end_pos).datainfo.parameter_space=datainfo.ch_name;
            obj.data(data_end_pos).datainfo.note=metainfo.Comment;
            obj.data(data_end_pos).datatype=obj.get_datatype;
            obj.data(data_end_pos).datainfo.last_change=metainfo.MeasurementDatePosix;
            
            status=true;
        end
        %content{isdata}.MeasurementParamsXML
    else
        % cancelled
        message=sprintf('%s\ndata load from %s cancelled',message,filename);
    end
    % close waitbar if exist
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

    function readmetainfo(var,topfname)
        % top level file info
        ngroup=numel(var);
        for groupidx=1:ngroup
            if isstruct(var(groupidx))
                if isempty(topfname)
                    topfname=var(groupidx).Name;
                end
                content{row_idx}.GroupName=sprintf('%s',var(groupidx).Name);
                if isstruct(var(groupidx).Attributes)
                    fnames={var(groupidx).Attributes.Name};
                    for k=1:numel(fnames)
                        switch fnames{k}
                            case {'CreationTime','ModificationTime','AccessTime','MeasurementDatePosix'}
                                % Date time related fields with posix time
                                % format
                                fval=char(datetime(double(var(groupidx).Attributes(k).Value), 'ConvertFrom', 'posixtime'));
                            case {'Name','Comment','ExperimenterSetupID','ExperimenterProfilename','SpaceName','ExperimenterUsername','ExperimenterHostname','CreatingMEScVersion',...
                                    'Channel_1_Name','Channel_1_Conversion_Title','Channel_1_Conversion_UnitName','Channel_1_Conversion_UnitNamePrefix','Channel_1_Conversion_UnitNamePostfix',...
                                    'Channel_0_Name','Channel_0_Conversion_Title','Channel_0_Conversion_UnitName','Channel_0_Conversion_UnitNamePrefix','Channel_0_Conversion_UnitNamePostfix',...
                                    'XAxisConversionTitle','XAxisConversionUnitName','XAxisConversionUnitNamePrefix','XAxisConversionUnitNamePostfix',...
                                    'YAxisConversionTitle','YAxisConversionUnitName','YAxisConversionUnitNamePrefix','YAxisConversionUnitNamePostfix',...
                                    'ZAxisConversionTitle','ZAxisConversionUnitName','ZAxisConversionUnitNamePrefix','ZAxisConversionUnitNamePostfix'}
                                % String related fields
                                fval=char(var(groupidx).Attributes(k).Value)';
                            case 'MeasurementParamsXML'
                                fval=digxmlinfo(var(groupidx).Attributes(k).Value);
                                %   return;
                            otherwise
                                % less important fields
                                switch var(groupidx).Attributes(k).Datatype.Class
                                    case 'H5T_STRING'
                                        % string class treat as cell of
                                        % strings
                                        fval=var(groupidx).Attributes(k).Value;
                                    otherwise
                                        % all other classes are treated as
                                        % double
                                        fval=double(var(groupidx).Attributes(k).Value);
                                end
                        end
                        content{row_idx}.(fnames{k})=fval;
                    end
                end
                % if dataset is not empty we have reached Measurements
                if isempty(var(groupidx).Datasets)
                    % no dataset here keep digging
                    content{row_idx}.DataName=[];
                    row_idx=row_idx+1;
                    readmetainfo(var(groupidx).Groups,topfname);
                else
                    % get dataset name
                    content{row_idx}.DataName=cellfun(@(x)[content{row_idx}.GroupName,'/',x],{var(groupidx).Datasets.Name},'UniformOutput',false);
                    % leave auxillary channels later
                    row_idx=row_idx+1;
                end
            end
        end
    end
end