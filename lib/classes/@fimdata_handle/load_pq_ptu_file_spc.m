function [ status, message ] = load_pq_ptu_file_spc( obj, filename )
%load picoquant ptu binary file with multiple channels

%% function check

% use spc storage system in the format
% pixind|delaytime|gtime
% pixel index in the order of x|y|z|T(frameno) in a m x n x k x j matrix
% use sub2ind and ind2sub to convert for plot images

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
        info.('File_Name')=char(filename);
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
                    Val=Val*1.0;%remain ms for the moment
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
            options.Resize='on';options.WindowStyle='modal';options.Interpreter='tex';
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
        dtime_max=str2double(sprintf('%1.4e',1/info.TTResult_SyncRate));%only carry 1 sig fig
        dtime_bin=info.MeasDesc_BinningFactor;
        dtime_start=0;dtime_stop=dtime_max;
        n_dtime_step=ceil(dtime_max/dtime_step);
        %
        switch  info.Measurement_Mode
            case 'T3'
                %fix time step to 256 neareast
                dtime_bin=ceil(n_dtime_step/256);
                t=linspace(dtime_start,dtime_stop,n_dtime_step/dtime_bin);%get delay time scale
            case 'T2'
                dtime_bin=1;
                t=[0,dtime_step];%get delay time scale
        end
        %}
        
        %------------
        % restructure data in spc format
        switch  info.Measurement_Mode
            case 'T3'
                %---seperate data (PicoHarp T3 Format)---
                channel=uint8(bitand(data,CHANNEL_MASK)/2^28);%channeldata
                dtime=uint16(bitand(data,DTIME_MASK)/2^16);%next 12bit=delaytime
                gtime=double(bitand(data,GTIME_MASK));%last 16bit=gtime
                clear data;%clear rawdata to save space
                
                %---data/special event channel---
                idx_special=uint64(find(channel==MAX_CH_NUM+1));    %special event
                clear channel;
                
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
                clear dtime_start dtime_stop dtime_step;
                
            case 'T2'
                % ---seperate data (PicoHarp T2 Format)---
                gtime = double(bitand(data,DTIME_MASK+GTIME_MASK));             %the lowest 28 bits
                channel = uint8(bitand(data,CHANNEL_MASK)/2^28);           %channeldata
                
                idx_special = uint64(find(channel==MAX_CH_NUM+1));     %non-photon data index
                idx_overflow = (gtime(idx_special)==0);       %overflow event for global time
                idx_marker = idx_special(~idx_overflow);      %external marker event index
                
                marker_rec = bitand(data(idx_marker),15);       %the lowest 4 bits of marker value
                
                clear data;%clear rawdata to save space
                
                gclock_tick_pos = idx_special(idx_overflow);  %overflow event index
                %---organise event markers to calculate correct pixind---
                %global linestart_pos linestop_pos clock_data linestart_framenum linestop_framenum;
                %external marker events categories
                hwmarker_pos=idx_marker(marker_rec==marker_hw);
                %imaging frame signals
                frame_pos=uint32(idx_marker(marker_rec==marker_frame));
                %imaging line start/stop signals
                linestart_pos=uint32(idx_marker(marker_rec==marker_line_start));
                linestop_pos=uint32(idx_marker(marker_rec==marker_line_stop));
                
                wraparound=210698240;%ps
                %---calculate global time---
                gtick_num=numel(gclock_tick_pos)-1;
                for tick_idx=1:1:gtick_num
                    gs=double(gclock_tick_pos(tick_idx));
                    ge=double(gclock_tick_pos(tick_idx+1))-1;
                    gtime(gs:ge)=gtime(gs:ge)+tick_idx*wraparound;
                end
                gtime(gclock_tick_pos(end):end)=gtime(gclock_tick_pos(end):end)+wraparound*(tick_idx+1);
                gtime=gtime*gtime_step*1000;  %calculate real val in sec
                dtime=double(zeros(numel(gtime),1));
                clear gclock_tick_pos gtime_step;
        end
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
                answer=inputdlg(sprintf('Image dimension seemed wrong\n.Try %g',possibleln),...
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
        
        % ask if want fly back
        button = questdlg(sprintf('Read fly back data?\nThis will double the x pixel numbers.'),...
            'Append flyback','true','false','false');
        if isempty(button)
            % default no flyback
            button='false';
        end
        readflyback=str2num(button);
        
        % --- provide info to confirm loading ---
        temp = figure(...
            'WindowStyle','normal',...% able to use
            'MenuBar','none',...% no menu
            'Position',[100,100,1000,500],...% fixed size
            'Name',cat(2,'Raw DATA meta info: ',filename));% use data name
        % change metainfo window icon
        global SETTING;
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
            'dtime bin',num2str(dtime_bin)};
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
                %rid of info figure
                delete(temp);
                % ------
                %initialise waitbar
                waitbar_handle = waitbar(0,'Please wait...','Progress Bar','Calculating...',...
                    'Name',cat(2,'Importing data from ',filename),...
                    'CreateCancelBtn',...
                    'setappdata(gcbf,''canceling'',1)',...
                    'WindowStyle','normal',...
                    'Color',[0.2,0.2,0.2]);
                global SETTING; %#ok<TLEV>
                javaFrame = get(waitbar_handle,'JavaFrame');
                javaFrame.setFigureIcon(javax.swing.ImageIcon(cat(2,SETTING.rootpath.icon_path,'main_icon.png')));
                setappdata(waitbar_handle,'canceling',0);
                % get total calculation step
                N_steps=numel(validframe)+numel(invalidframe);barstep=0;
                % ------
                %clock_data format in Frame|Line|Pixel and to be converted using
                %ind2sub function to pixind in data variable
                clock_data=zeros(numel(gtime),3,'uint16');
                % start loading frames
                framenum=0;
                T=zeros(numel(validframe),1);
                for frameind=validframe
                    % check waitbar
                    if getappdata(waitbar_handle,'canceling')
                        message=sprintf('Data import cancelled\n');
                        delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
                        return;
                    end
                    % Report current estimate in the waitbar's message field
                    done=frameind/N_steps;
                    if floor(100*done)>=barstep
                        % update waitbar
                        waitbar(done,waitbar_handle,sprintf('%g%%',barstep));
                        barstep=barstep+1;
                    end
                    % ------
                    clock_data(frame_pos(frameind),2)=0;
                    signal_ls=linestart_pos(linestart_framenum==frameind);
                    signal_le=linestop_pos(linestop_framenum==frameind);
                    % mark frame number
                    % next real frame
                    framenum=framenum+1;
                    clock_data(frame_pos(frameind):frame_pos(frameind+1),1)=framenum;
                    T(framenum)=gtime(frame_pos(frameind));
                    
                    if readflyback
                        % mark line number
                        clock_data(signal_ls,2)=1;
                        clock_data(signal_ls(1):signal_le(end),2)=cumsum(double(clock_data(signal_ls(1):signal_le(end),2)));
                    else
                        % mark line number
                        temp=double(clock_data(signal_ls(1):signal_le(end),2));
                        signal_offset=signal_ls(1)-1;
                        temp(signal_ls-signal_offset)=1:1:line_per_frame;
                        temp(signal_le-signal_offset)=-(1:1:line_per_frame);
                        clock_data(signal_ls(1):signal_le(end),2)=cumsum(temp);
                    end
                    % mark pixel number
                    % line 1 to penultimate line with flyback
                    [~,pixind]=arrayfun(@(ls,le1,le2)histc(gtime(ls:le2-1),...
                        [linspace(gtime(ls),gtime(le1),pixel_per_line),...
                        linspace(gtime(le1+1),gtime(le2-1),pixel_per_line-1)]),...
                        signal_ls(1:end-1),signal_le(1:end-1),signal_ls(2:end),...
                        'UniformOutput',false);
                    pixind=cell2mat(pixind);
                    
                    % add last forward line
                    [~,lastline]=histc(gtime(signal_ls(end):signal_le(end)),linspace(gtime(signal_ls(end)),gtime(signal_le(end)),pixel_per_line));
                    
                    % assignment
                    clock_data(signal_ls(1):signal_le(end),3)=[pixind;lastline];
                    pixind=[];
                end
                delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
                clear linestart_framenum linestop_framenum linestart_pos linestop_pos;
                
                if readflyback
                    % append fly back add more pixels
                    pixel_per_line=2*pixel_per_line-1;
                end
                %idx_data=(channel==present_channel)&(clock_data(:,2)>0);
                validdata=clock_data(:,2)>0;
                %gtime=gtime(validdata);%remove nondata record
                clock_data=double(clock_data(validdata,:));
                %delaytime=delaytime(validdata)=[];%remove nondata record
                pixel_per_line=max(clock_data(:,3));
                line_per_frame=max(clock_data(:,2));
                clock_data=sub2ind([pixel_per_line,line_per_frame,framenum], clock_data(:,3), clock_data(:,2), clock_data(:,1));
                
                %assign data
                data_end_pos=numel(obj.data);
                obj.data(data_end_pos+1)=obj.data(1);
                %increment
                data_end_pos=data_end_pos+1;
                obj.current_data=data_end_pos;
                obj.data(data_end_pos).dataval=[clock_data,dtime(validdata),gtime(validdata)];
                clear clock_data dtime gtime validdata;
                %data information
                f_name=fieldnames(info);
                for f_idx=1:length(f_name)
                    obj.data(data_end_pos).metainfo.(f_name{f_idx})=info.(f_name{f_idx});
                end
                obj.data(data_end_pos).datainfo.bin_t=dtime_bin;
                obj.data(data_end_pos).datainfo.X=0:info.ImgHdr_PixResol:(pixel_per_line-1)*info.ImgHdr_PixResol;
                obj.data(data_end_pos).datainfo.Y=0:info.ImgHdr_PixResol:(line_per_frame-1)*info.ImgHdr_PixResol;
                obj.data(data_end_pos).datainfo.Z=0;
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
                obj.data(data_end_pos).dataname=cat(2,name,'_C',num2str(channel_idx),'_',info.File_GUID);
                obj.data(data_end_pos).datainfo.T=T;
                obj.data(data_end_pos).datainfo.data_dim=[numel(obj.data(data_end_pos).datainfo.t),...
                    numel(obj.data(data_end_pos).datainfo.X),...
                    numel(obj.data(data_end_pos).datainfo.Y),...
                    1,...
                    numel(obj.data(data_end_pos).datainfo.T)];
                obj.data(data_end_pos).datatype='DATA_SPC';
                
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
end

%{
function ReadPT2
    ofltime = 0;%overflow time
    WRAPAROUND='C8F0000';
   
        ptime = bitand(data,DTIME_MASK+GTIME_MASK);             %the lowest 28 bits
        channel=uint8(bitand(data,CHANNEL_MASK)/2^28);           %channeldata

        timetag = T2time + ofltime;


        idx_special=uint64(find(channel==MAX_CH_NUM+1));
        idx_overflow=(dtime(idx_special)==0);       %overflow event for global time
        gclock_tick_pos=idx_special(idx_overflow);  %overflow event index
        idx_marker=idx_special(~idx_overflow);      %external marker event index

        if (chan >= 0) && (chan <= 4)
        % actual photon data
            photontime=timetag * info.MeasDesc_GlobalResolution * 1e12; %in ps
        else
            if chan == 15
                
                markers = bitand(T2Record,15);  % where the lowest 4 bits are marker bits
                if markers==0                   % then this is an overflow record
                    ofltime = ofltime + WRAPAROUND; % and we unwrap the time tag overflow
                    GotOverflow(1);
                else                            % otherwise it is a true marker

                    GotMarker(timetag, markers);
                end;
            else
                fprintf(fpout,'Err');
            end;
        end;
        % Strictly, in case of a marker, the lower 4 bits of time are invalid
        % because they carry the marker bits. So one could zero them out.
        % However, the marker resolution is only a few tens of nanoseconds anyway,
        % so we can just ignore the few picoseconds of error.
    end;
end
%}