function [ status, message ] = load_pq_ptu_file( obj, filename )
%load picoquant ptu binary file with multiple channels

%% function check

% possible spc storage system to save ram

% assume worst
status=false;

try
    %%
    %===================
    %=====Constants=====
    %===================
    %DATA FORMATS
    Tag_Id_Format='char*1';
    Tag_Idx_Format='uint32';
    Tag_TypeCode_Format='uint32';
    
    %DATA OPTIONS
    MEASUREMENT_MODES={'HIST', 'Resrv1', 'T2', 'T3', 'Resrv4','Resrv5','Resrv6','Resrv7', 'CONT'};
    MEASUREMENT_SUBMODES={'OSC','INT','TRES','IMG'};
    IMAGE_DIMENSIONS={'Resrv0','Resrv1','LINE','AREA'};
    IMAGE_IDENTITIES={'Resrv0','PI_E710','Resrv2','LSM','KDT180?100?lm'};
    TYPE_CODES=struct('Name',{'Empty8','Bool8','Int8','BitSet64','Color8','Float8','TDateTime',...  %simple type
        'Int8Array','Float8Array','ASCII-String','Wide-String','BinaryBlob'},...    %enhanced type
        'Code',{'FFFF0008','00000008','10000008','11000008','12000008','20000008','21000008',...    %simple type
        '1001FFFF','2001FFFF','4001FFFF','4002FFFF','FFFFFFFF'});                   %enhanced type
    
    %DATA MASKS
    CHANNEL_MASK=hex2dec('F0000000');
    DTIME_MASK=hex2dec('0FFF0000');
    GTIME_MASK=hex2dec('0000FFFF');
    MAX_CH_NUM=14;
    
    %%
    %===================
    %=====Load Data=====
    %===================
    %open file
    [fid,message]=fopen(filename,'r');
    if fid>=3 %successfully opened
        %------------
        %read header
        
        %Preamble Tags
        info.('File_Type')=char(fread(fid, 8, 'char')');
        info.('File_Format_Version')=char(fread(fid, 8, 'char')');
        
        %Fielded Tags
        while true
            Tag_Id = char(fread(fid, 32, Tag_Id_Format)');
            Tag_Id = Tag_Id(Tag_Id > 0);%trim down
            Tag_Idx = uint32(fread(fid, 1, Tag_Idx_Format));
            if Tag_Idx~=hex2dec('ffffffff')
                %indexed tag
                idx=Tag_Idx+1;%hardware index start from 0
            else
                idx=[];
            end
            Tag_TypeCode = dec2hex(fread(fid, 1, Tag_TypeCode_Format),8);
            type_idx = cellfun(@(x)~isempty(x),regexp({TYPE_CODES.Code},Tag_TypeCode));
            switch TYPE_CODES(type_idx).Name
                %most frequent type at top
                case 'ASCII-String'
                    Tag_Value = uint64(fread(fid, 1, 'uint64'));
                    Tag_Enhancement=fread(fid,Tag_Value,'char*1');
                    Val=char(Tag_Enhancement');
                case 'Int8'
                    Tag_Value = fread(fid, 1, 'int64');
                    Val=Tag_Value;
                case 'Float8'
                    Tag_Value = fread(fid, 1, 'double');
                    Val=Tag_Value;
                case 'Bool8'
                    Tag_Value = fread(fid, 1, 'int64');
                    Val=true;
                    if Tag_Value==0
                        Val=false;
                    end
                case 'Empty8'
                    Tag_Value = uint64(fread(fid, 1, 'uint64'));
                    Val=Tag_Value;
                case 'TDateTime'
                    Tag_Value = fread(fid, 1, 'float64');
                    Val=datestr(Tag_Value+datenum([1899,12,30,0,0,0]),31);%number of days since
                otherwise
                    fprintf('Don''t know how to deal with Type Code %s of Value %f\n',Tag_TypeCode,Tag_Value);
            end
            %special Tag_Id need modification
            switch Tag_Id
                case 'File_GUID'
                    strendpos=strfind(Val,'}');
                    Val=Val(1:strendpos);%remain ms for the moment
                case 'MeasDesc_AcquisitionTime'
                    Val=Val;%remain ms for the moment
                case 'Measurement_Mode'
                    Val=MEASUREMENT_MODES{Val+1};%convert to text, start 0
                case 'Measurement_SubMode'
                    Val=MEASUREMENT_SUBMODES{Val+1};%convert to text, start 0
                case 'ImgHdr_Dimensions'
                    Val=IMAGE_DIMENSIONS{Val+1};%convert to text, start 0
                case 'ImgHdr_Ident'
                    Val=IMAGE_IDENTITIES{Val+1};%convert to text, start 0
                case 'Header_End'
                    break;%END OF FILE HEADER
                case 'Fast_Load_End'
                    %DO NOTHING
                otherwise
                    %PASS ON VALUES AS IS
            end
            %assign value
            if isempty(idx)
                %non-indexed tag
                info.(Tag_Id)=Val;
            else
                %indexed tag
                info.(Tag_Id){idx}=Val;
            end
        end
        
        %------------
        %read data
        BIN_DATA_FORMAT=cat(2,'ubit',num2str(info.TTResultFormat_BitsPerRecord));
        data = fread(fid, info.TTResult_NumberOfRecords, cat(2,BIN_DATA_FORMAT,'=>uint32'));
        %close file
        fclose(fid);
        %=================================================================
        %%
        %---get data channels---
        present_channel=cell2mat(info.HWInpChan_ModuleIdx);%find out channels present
        if numel(present_channel)>1
            % ask for single channel to load
            set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
            set(0,'DefaultUicontrolForegroundColor','k');
            answer=inputdlg(cat(2,num2str(present_channel),'Which Channel to import:'),'Select Channel',1,{'1'});
            set(0,'DefaultUicontrolBackgroundColor','k');
            set(0,'DefaultUicontrolForegroundColor','w');
            if ~isempty(answer)
                %get selected channel
                channel_idx=str2double(answer);
            else
                %default to first channel
                channel_idx=present_channel(1);
            end
        else
            %single channel data
            channel_idx=present_channel;
        end
        
        %---image parameters info---
        marker_hw=2^(info.HW_Markers-1);                %hardware marker
        marker_line_start=2^(info.ImgHdr_LineStart-1);  %linestart marker
        marker_line_stop=2^(info.ImgHdr_LineStop-1);    %linestop marker
        marker_frame=2^(info.ImgHdr_Frame-1);           %frame marker
        isbidirectional=info.ImgHdr_BiDirect;           %if bidirectional
        %get imaging parameters(X/Y are swapped to olympus scan)
        pixel_per_line=info.ImgHdr_PixX;
        line_per_frame=info.ImgHdr_PixY;
        
        %---timing info---
        gtime_step=info.MeasDesc_GlobalResolution;      %gtime step
        dtime_step=info.MeasDesc_Resolution;            %delaytime step
        
        %------------
        % restructure data in spc format
        %---seperate data (PicoHarp T3 Format)---
        channel=uint8(bitand(data,CHANNEL_MASK)/2^28);%channeldata
        %---data/special event channel---
        idx_special=uint64(find(channel==MAX_CH_NUM+1));    %special event
        clear channel;
        
        dtime=uint16(bitand(data,DTIME_MASK)/2^16);%next 12bit=delaytime
        gtime=double(bitand(data,GTIME_MASK));%last 16bit=gtime
        clear data;%clear rawdata to save space
        
        %categorises special events
        idx_overflow=(dtime(idx_special)==0);       %overflow event for global time
        gclock_tick_pos=idx_special(idx_overflow);  %overflow event index
        idx_marker=idx_special(~idx_overflow);      %external marker event index
        clear idx_special idx_overflow;
        %---organise event markers to calculate correct pixind---
        %global linestart_pos linestop_pos clock_data linestart_framenum linestop_framenum;
        %external marker events categories
        hwmarker_pos=idx_marker(dtime(idx_marker)==marker_hw);
        
        %imaging frame signals
        frame_pos=uint32(idx_marker(dtime(idx_marker)==marker_frame));
        %imaging line start/stop signals
        linestart_pos=uint32(idx_marker(dtime(idx_marker)==marker_line_start));
        linestop_pos=uint32(idx_marker(dtime(idx_marker)==marker_line_stop));
        clear idx_marker;
        
        %---calculate global time---
        gtick_num=numel(gclock_tick_pos)-1;
        for tick_idx=1:1:gtick_num
            gs=double(gclock_tick_pos(tick_idx));
            ge=double(gclock_tick_pos(tick_idx+1))-1;
            gtime(gs:ge)=gtime(gs:ge)+tick_idx*GTIME_MASK;
        end
        gtime(double(gclock_tick_pos(end)):end)=gtime(double(gclock_tick_pos(end)):end)+GTIME_MASK*(tick_idx+1);
        gtime=gtime*gtime_step*1000;  %calculate real val in sec
        clear gclock_tick_pos gtime_step;
        
        %---calculate delaytime---
        dtime = double(dtime) * dtime_step;%calculate real delaytime
        
        %calculate delaytime scale
        dtime_repmax=str2double(sprintf('%e',1/info.TTResult_SyncRate));%only carry 1 sig fig
        dtime_max=max(dtime);
        dtime_start=0;dtime_stop=dtime_repmax;
        n_dtime_step=dtime_repmax/dtime_step;
        %fix time step to 256 neareast
        dtime_bin=max(1,floor(n_dtime_step/256));
        t=dtime_start:dtime_bin*dtime_step:dtime_stop;
        n_dtime_step=numel(t);
        clear dtime_start dtime_stop dtime_step;
        
        % --- start getting data into clock data format
        framenum=numel(frame_pos);
        [~,linestart_framenum]=histc(linestart_pos,frame_pos);
        [startlinenum,~]=histc(linestart_framenum,1:1:framenum);
        [~,linestop_framenum]=histc(linestop_pos,frame_pos);
        [stoplinenum,~]=histc(linestop_framenum,1:1:framenum);
        validframe=[];
        
        set(0,'DefaultUicontrolBackgroundColor','w');
        set(0,'DefaultUicontrolForegroundColor','k');
        while isempty(validframe)
            invalidframe=unique([find(startlinenum~=line_per_frame);find(stoplinenum~=line_per_frame)]);
            validframe=setxor(1:1:framenum,invalidframe);
            if isempty(validframe)
                possibleln=unique(startlinenum);
                possibleln=possibleln(possibleln>0);
                % ask for input
                answer=inputdlg(sprintf('Image dimension seemed wrong.\nTry %g.',possibleln),...
                    'Input required',1,{num2str(max(possibleln))});
                if isempty(answer)
                    % cancel and went back to check
                    break;
                else
                    temp=str2double(answer);
                    if temp==pixel_per_line
                        % we got xy swapped over
                        pixel_per_line=line_per_frame;
                    end
                    line_per_frame=temp;
                end
            end
        end
        set(0,'DefaultUicontrolBackgroundColor','k');
        set(0,'DefaultUicontrolForegroundColor','w');
        validframe=validframe(:)';
        
        % --- provide info to confirm loading ---
        temp = figure(...
            'WindowStyle','normal',...% able to use
            'MenuBar','none',...% no menu
            'Position',[100,100,1000,800],...% fixed size
            'Name',cat(2,'Raw DATA meta info: ',filename));% use data name
        % change metainfo window icon
        global SETTING; %#ok<TLEV>
        javaFrame = get(temp,'JavaFrame');
        javaFrame.setFigureIcon(javax.swing.ImageIcon(cat(2,SETTING.rootpath.icon_path,'main_icon.png')));
        % get new figure position
        pos=get(temp,'Position');
        % create table to display meta information
        obj.data(1).metainfo=info;
        [~,infomess]=obj.display_metainfo(1,1,[]);
        uitable(...
            'Parent',temp,...
            'Data',infomess,...% output metainfo
            'ColumnName',{'Field','Value'},...
            'Position',[0 0 pos(3)/2 pos(4)],...% maximise table
            'ColumnWidth',{floor(pos(3)/6) floor(1.5*pos(3)/6)-10},...
            'ColumnEditable',[false false]);% no editing required
        % create table to display data information
        infomess={'pixel/line',num2str(pixel_per_line);...
            'line/frame',num2str(line_per_frame);...
            '# of valid frame',num2str(numel(validframe));...
            '# of invalid frame',num2str(numel(invalidframe));...
            'dtime bin',num2str(dtime_bin);...
            'dtime max',num2str(dtime_max)};
        uitable(...
            'Parent',temp,...
            'Data',infomess,...% output metainfo
            'ColumnName',{'Field','Value'},...
            'Position',[pos(3)/2 0 3*pos(3)/2 pos(4)],...% maximise table
            'ColumnWidth',{floor(pos(3)/8) floor(1.5*pos(3)/8)},...
            'ColumnEditable',[false false]);% no editing required
        button = questdlg('Check data info is correct','Proceed Further?','Proceed','Cancel','Proceed') ;
        switch button
            case 'Proceed'
                frame_per_stack=numel(validframe);
                % ------
                %preallocate frame binning and stack
                if frame_per_stack>1
                    frame_bin=frame_per_stack;
                    frame_skip=1;
                    set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
                    set(0,'DefaultUicontrolForegroundColor','k');
                    answer=inputdlg({cat(2,'Number of frame to bin:(',num2str(frame_per_stack),') @ ',num2str(info.TTResult_InputRate{channel_idx}),' input rate'),'Frame skip:'},'Frame Binning',1,{num2str(frame_bin),num2str(frame_skip)});
                    set(0,'DefaultUicontrolBackgroundColor','k');
                    set(0,'DefaultUicontrolForegroundColor','w');
                    if ~isempty(answer)
                        frame_bin=str2double(answer{1});
                        frame_skip=str2double(answer{2});
                    end
                else
                    frame_bin=1;
                    frame_skip=1;
                end
                
                pixel_per_frame=pixel_per_line*line_per_frame;
                %frame to include in each slice
                frame_sort=arrayfun(@(x)x:frame_skip:frame_per_stack,1:1:frame_skip,'UniformOutput',false);
                frame_order=cellfun(@(x)num2cell(reshape(x(1:frame_bin*floor(numel(x)/frame_bin)),frame_bin,floor(numel(x)/frame_bin)),1),...
                    frame_sort,'UniformOutput',false);
                % start loading frames
                Zslice=1:1:numel(frame_sort);
                Tpage=1:1:numel(frame_order{1});
                %new data for each z
                data_end_pos=numel(obj.data);
                obj.data(data_end_pos+1)=obj.data(1);
                data_end_pos=data_end_pos+1;
                obj.current_data=data_end_pos;
                obj.data(data_end_pos).dataval=zeros(n_dtime_step,pixel_per_line,line_per_frame,numel(Zslice),numel(Tpage));
                T=zeros(1,numel(Tpage));
                
                %initialise waitbar
                waitbar_handle = waitbar(0,'Please wait...','Progress Bar','Calculating...',...
                    'Name',cat(2,'Importing ',filename),...
                    'CreateCancelBtn',...
                    'setappdata(gcbf,''canceling'',1)',...
                    'WindowStyle','normal',...
                    'Color',[0.2,0.2,0.2]);
                setappdata(waitbar_handle,'canceling',0);
                javaFrame = get(waitbar_handle,'JavaFrame');
                javaFrame.setFigureIcon(javax.swing.ImageIcon(cat(2,SETTING.rootpath.icon_path,'main_icon.png')));
                % get total calculation step
                N_steps=numel(validframe);frame_count=1;barstep=0;
                
                for Zsliceind=Zslice
                    %go through z slice
                    for Tpageind=Tpage
                        frame_data=zeros(n_dtime_step,pixel_per_frame);%temporary frame data storage
                        inpageframe=validframe(frame_order{Zsliceind}{Tpageind});
                        % bin in Time
                        for frameind=inpageframe
                            %each time frame to bin together
                            signal_ls=linestart_pos(linestart_framenum==frameind);
                            signal_le=linestop_pos(linestop_framenum==frameind);
                            %{
                            tempdata=arrayfun(@(ls,le)hist3([dtime(ls:le),gtime(ls:le)],'Nbins',...
                                [n_dtime_step,pixel_per_line]),...
                                signal_ls,signal_le,'UniformOutput',false);
                            %}
                            tempdata=arrayfun(@(ls,le)hist3([dtime(ls:le),gtime(ls:le)],'Edges',...
                                {t,linspace(gtime(ls),gtime(le),pixel_per_line)'}),...
                                signal_ls,signal_le,'UniformOutput',false);
                            %save frame data
                            frame_data=frame_data+cell2mat(tempdata');
                            
                            % waitbar
                            frame_count=frame_count+1;
                            done=frame_count/N_steps;
                            % Report current estimate in the waitbar's message field
                            if floor(100*done)>=barstep
                                % update waitbar
                                waitbar(done,waitbar_handle,sprintf('%g%%',floor(100*done)));
                                barstep=barstep+1;
                            end
                            % check waitbar
                            if getappdata(waitbar_handle,'canceling')
                                message=sprintf('Data Import cancelled\n');
                                delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
                                return;
                            end
                        end
                        %assign data
                        obj.data(data_end_pos).dataval(:,:,:,Zsliceind,Tpageind)=reshape(frame_data,[n_dtime_step,pixel_per_line,line_per_frame,1,1]);
                        %frame_data=zeros(n_dtime_step,pixel_per_frame);
                        T(Tpageind)=gtime(signal_ls(1));
                    end
                end
                clear frame_data dtime gtime pixbin linestart_framenum linestop_framenum linestart_pos linestop_pos tempdata;
                %data information
                f_name=fieldnames(info);
                for f_idx=1:length(f_name)
                    obj.data(data_end_pos).metainfo.(f_name{f_idx})=info.(f_name{f_idx});
                end
                obj.data(data_end_pos).datainfo.bin_t=dtime_bin;
                obj.data(data_end_pos).datainfo.X=0:info.ImgHdr_PixResol:(pixel_per_line-1)*info.ImgHdr_PixResol;
                obj.data(data_end_pos).datainfo.Y=0:info.ImgHdr_PixResol:(line_per_frame-1)*info.ImgHdr_PixResol;
                obj.data(data_end_pos).datainfo.Z=Zslice;
                obj.data(data_end_pos).datainfo.t=t;
                obj.data(data_end_pos).datainfo.dt=t(2)-t(1);
                obj.data(data_end_pos).datainfo.dX=info.ImgHdr_PixResol;
                obj.data(data_end_pos).datainfo.dY=info.ImgHdr_PixResol;
                obj.data(data_end_pos).datainfo.dZ=1;
                obj.data(data_end_pos).datainfo.note=info.File_Comment;
                obj.data(data_end_pos).datainfo.T_acquisition=info.MeasDesc_AcquisitionTime;
                obj.data(data_end_pos).datainfo.last_change=datestr(now);
                obj.data(data_end_pos).datainfo.data_idx=obj.current_data;
                [~,name,~]=fileparts(filename);
                obj.data(data_end_pos).dataname=cat(2,name,'_C',num2str(channel_idx));
                obj.data(data_end_pos).datainfo.T=T;
                obj.data(data_end_pos).datainfo.data_dim=[numel(obj.data(data_end_pos).datainfo.t),...
                    numel(obj.data(data_end_pos).datainfo.X),...
                    numel(obj.data(data_end_pos).datainfo.Y),...
                    numel(obj.data(data_end_pos).datainfo.Z),...
                    numel(obj.data(data_end_pos).datainfo.T)];
                obj.data(data_end_pos).datatype=obj.get_datatype;
                delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
                status=1;
            case 'Cancel'
                message=sprintf('%s\nIncorrect file information\nLoading Cancelled\n',message);
            otherwise
                message=sprintf('%s\nIncorrect file information\nLoading Cancelled\n',message);
        end
    else
        message=sprintf('Unable to load file.  Error: %s\n',message);
    end
catch exception
    message=sprintf('%s\n',exception.message);
     if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
end


    function n=myhist3(x,edges)        
        if ~(iscell(edges) && numel(edges)==2 && isnumeric(edges{1}) && isnumeric(edges{2}))
            edges = {edges{1}(:)' edges{2}(:)'};
            nbins = [length(edges{1}) length(edges{2})];
            [nrows,ncols] = size(x);
            bin = zeros(nrows,2);
            for i = 1:2
                minx = min(x(:,i));
                maxx = max(x(:,i));
                
                e = edges{i};
                de = diff(e);
                histcEdges = e;
                edges{i} = [e e(end)+de(end)];
                binwidth{i} = [de de(end)];
                [~,bin(:,i)] = histc(x(:,i),histcEdges,1);
                bin(:,i) = min(bin(:,i),nbins(i));
            end
            n = accumarray(bin(all(bin>0,2),:),1,nbins);
        end
    end

    function m=mycell2mat(c)
        rows = size(c,1);
        cols = size(c,2);
        if (rows < cols)
            m = cell(rows,1);
            for n=1:rows
                m{n} = cat(2,c{n,:});
            end
            m = cat(1,m{:});
        else
            m = cell(1, cols);
            for n=1:cols
                m{n} = cat(1,c{:,n});
            end
            m = cat(2,m{:});
        end
    end
end