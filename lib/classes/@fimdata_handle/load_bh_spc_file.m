function [ status, message ] = load_bh_spc_file( obj, filename )
%LOAD_SPEC_FILE Import Becker and Hickl spc data file from SPC-830 module
%  FIFO Data Files (SPC-130, SPC-140, SPC-150, SPC-830, SPC-131 )

% -------------------------------------------------------------
% File Reader Constants, see ./lib/SPC_data_file_structure.h
% -------------------------------------------------------------
% use spc storage system in the format
% pixind|delaytime|gtime
% pixel index in the order of x|y|z|T(frameno) in a m x n x k x j matrix
% use sub2ind and ind2sub to convert for plot images

status=false;
% --- file header validity ---
FILE_HEADER_VALID='5555';
FILE_HEADER_INVALID='1111';

% --- .spc file specific masks ---
% masks for different parts of the frame
INVALID32=uint32(hex2dec('80000000'));      % Invalid
MTOV32=uint32(hex2dec('40000000'));         % Macro time overflow
INVALID_MTOV32=uint32(hex2dec('C0000000')); % Invalid + Macro time overflow
OVRUN32=uint32(hex2dec('20000000'));        % Fifo overrun, recording gap
ROUT32=uint32(hex2dec('F000'));             % Routing signals( inverted )
MT32=uint32(hex2dec('FFF'));                % Macro time
ADC32=uint32(hex2dec('0FFF0000'));          % ADC value
OV_CNT=uint32(hex2dec('0FFFFFFF'));         % Overflow count

% masks for the 1st frame in .spc file
RB_NO32=uint32(hex2dec('78000000'));        % routing bits number used during measurement
MT_CLK32=uint32(hex2dec('00FFFFFF'));       % macro time clock in 0.1 ns units
M_FILE32=uint32(hex2dec('02000000'));       %// file with markers
R_FILE32=uint32(hex2dec('04000000'));       %// file with raw data ( diagnostic mode only )

MARKER_FRAME=uint32(hex2dec('90000000'));
% external markers
MARKER0=uint32(hex2dec('90001000'));
MARKER1=uint32(hex2dec('90002000'));
MARKER2=uint32(hex2dec('90004000'));
MARKER3=uint32(hex2dec('90008000'));

% external marker assignment
P_MARK32=MARKER0;   %pixel marker
L_MARK32=MARKER1;   %line  marker
F_MARK32=MARKER2;   %frame marker
HW_MARK32=MARKER3;  %hardware marker

% --------------
BH_File_Header=struct('revision',{''},...% software revision number  (lower 4 bits >= 10(decimal))
    'info_offs',{''},...% offset of the info part which contains general text information (Title, date, time, contents etc.)
    'info_length',{''},...% length of the info part
    'setup_offs',{''},... % offset of the setup text data (system parameters, display parameters, trace parameters etc.)
    'setup_length',{''},...% length of the setup data
    'data_block_offs',{''},...% offset of the first data block
    'no_of_data_blocks',{''},...% no_of_data_blocks valid only when in 0 .. 0x7ffe range,if equal to 0x7fff  the  field 'reserved1' contains valid no_of_data_blocks
    'data_block_length',{''},...% length of the longest block in the file
    'meas_desc_block_offs',{''},...% offset to 1st. measurement description block (system parameters connected to data blocks)
    'no_of_meas_desc_blocks',{''},...% number of measurement description blocks
    'meas_desc_block_length',{''},...% length of the measurement description blocks
    'header_valid',{''},... % valid: 0x5555, not valid: 0x1111
    'reserved1',{''},...% reserved1 now contains no_of_data_blocks
    'reserved2',{''},...
    'chksum',{''});% checksum of file header
BH_File_Header_format={'short','long','short','long','short','long','short',...
    'long','long','short','short','ushort','ulong','ushort','ushort'};%header_format_for_sdt_file
%------file info------
File_Info=struct('ID',{''},...
    'Title',{''},...
    'Version',{''},...
    'Revision',{''},...
    'Date',{''},...
    'Time',{''},...
    'Author',{''},...
    'Company',{''},...
    'Contents',{''});
File_Info_format='char';
%------setup info------
Setup_Info='';
Setup_ASCII_format='schar';
%binary part of setup is ignore as we are not interested in recreating the
%display on SPCM software
BIN_DATA_FORMAT='uint32';

info=struct('file_header',{BH_File_Header},...
    'file_info',{File_Info},...
    'setup_info',{Setup_Info});

try
    %%
    %===================
    %=====Load Data=====
    %===================
    %open file
    [data_fid,message]=fopen(filename,'r');
    if data_fid>=3 %successfully opened
        %=================================
        %=======FILE INFORAMATION=========
        %=================================
        
        %find corresponding .set file
        set_filename=cat(2,filename(1:end-4),'.set');
        set_fid=fopen(set_filename,'r');
        %if found
        %===================================
        %=======read config files .set========
        %===================================
        if (set_fid>=3)
            nosetfile=false;
            %============================
            %==Read File Header Section==
            %============================
            f_name=fieldnames(BH_File_Header);
            for n=1:length(BH_File_Header_format)
                info.file_header.(f_name{n})=fread(set_fid,1,BH_File_Header_format{n});
            end
            %check module identification
            switch dec2hex(bitshift(info.file_header.revision,-4))
                case '20'%SPC130
                    info.hwmodule='SPC130';
                case '28'%SPC150
                    info.hwmodule='SPC150';
                case '25'%SPC830
                    info.hwmodule='SPC830';
                otherwise
                    fprintf('%s\n','unknown hardware module type');
            end
            %check file header is valid
            switch dec2hex(info.file_header.header_valid)
                case FILE_HEADER_VALID
                    fprintf('%s\n','valid file header');
                case FILE_HEADER_INVALID
                    error_msg='!INVALID FILE HEADER!';
                    fprintf('%s\n',error_msg);
                    return;
            end
            
            %============================
            %===Read File Information====
            %============================
            
            if ftell(set_fid)==info.file_header.info_offs %check file position is correct
                buffer=fread(set_fid,info.file_header.info_length,File_Info_format);
                if strmatch(char(buffer(1:15)'),'*IDENTIFICATION')
                    buffer=char(buffer(16:end)');%skip *IDENTIFICATION
                    f_name=fieldnames(info.file_info);f_name{end+1}='*END';
                    for n=1:length(f_name)-1
                        pos(1)=strfind(buffer,f_name{n});
                        pos(2)=strfind(buffer,f_name{n+1});
                        temp=char(buffer(pos(1):pos(2)-1));
                        temp=regexp(temp,'(:[ \S]*)','match');
                        info.file_info.(f_name{n})=temp{1}(2:end);
                    end
                else
                    error_msg='!''*IDENTIFICATION'' NOT FOUND IN FILE INFO!';
                    fprintf('%s\n',error_msg);
                    return;
                end
            else
                fprintf('%s\n','File Information Offset error');
            end
            %============================
            %========Read Setup==========
            %============================
            %ASCII part
            %CFD:LL=Limit Low, LH=Limit Hight,ZC=Zero crossing,HF=Hold time
            %SYN:ZC=Zero crossing,FD=Frequency Divider,FQ=Threshold,HF=Holdoff
            %TAC:R=Range,G=gain,OF=offset,LL=Limit Low,LH=Limit
            %     High,TC=Time/Channel, TD=Time/Division
            %ADC:RE=Resolution
            if ftell(set_fid)==info.file_header.setup_offs
                buffer=fread(set_fid,info.file_header.setup_length,Setup_ASCII_format);
                buffer=char(buffer');
                buffer=regexp(buffer,'*END','split');
                binbuffer=buffer{2};%binary part
                buffer=buffer{1};% only ascii part
                buffer=regexp(buffer,'\n','split');% split string into each row
                sys_para_bound=find(cellfun(@(x)~isempty(x),regexp(buffer,'SYS_PARA_BEGIN|SYS_PARA_END','match')));% find system parameter boundary
                % read individual system parameters
                for idx=sys_para_bound(1)+1:sys_para_bound(2)-1
                    [temp,i]=regexp(buffer{idx},'\W*','split');
                    fname=temp{3};
                    switch temp{4}
                        case 'C'
                            val=temp{5};
                        case 'S'
                            val=buffer{idx}(i(4)+1:i(end)-1);
                        case {'I','F','L','U'}
                            val=str2double(buffer{idx}(i(4)+1:i(end)-1));
                        case {'B'}
                            val=boolean(str2double(temp{5}));
                    end
                    info.setup_info.(fname)=val;
                end
            else
                fprintf('%s\n','Setup Information size error!');
            end
            %Binary part
            
            clear binbuffer;
            fclose(set_fid);
            
            present_channel = info.setup_info.SP_IMG_RX;
            dtime_step = info.setup_info.SP_TAC_TC;                         %delaytime step
            dtime_max = info.setup_info.SP_TAC_R/info.setup_info.SP_TAC_G;  %only carry 1 sig fig
            dtime_start = dtime_step;dtime_stop=dtime_max;
            n_dtime_step = info.setup_info.SP_ADC_RE;
            % get image size from info data
            pixel_per_line=info.setup_info.SP_IMG_X;
            line_per_frame=info.setup_info.SP_IMG_Y;
        else
            nosetfile=true;
            fprintf('unable to find/open .set file\n');
            [~,info.file_info.Title,~]=fileparts(filename);
            info.setup_info.SP_COL_T=[];
            present_channel = 1;
            % default TAC setting for SPC150/SPC830
            dtime_step = 4.8861e-11;                         %delaytime step
            dtime_max = 5.0034e-08/4;  %only carry 1 sig fig
            dtime_start = dtime_step;dtime_stop=dtime_max;
            n_dtime_step = 256;
            % get image size from info data
            pixel_per_line=256;
            line_per_frame=256;
        end
        clear buffer temp;
        %===================================
        %=======read data files .spc========
        %===================================
        fseek(data_fid,0,'eof');
        eof_marker=ftell(data_fid);
        fseek(data_fid,0,'bof');
        % get number of records
        info.NumberOfRecords=eof_marker/4;%4byte data size
        
        %first byte
        data = fread(data_fid, info.NumberOfRecords, cat(2,BIN_DATA_FORMAT,'=>uint32'));
        fclose(data_fid);
        %=================================================================
        %
        % info.setup_info.SP_IMG_RX   %route x (2 means 2detectors)
        % info.setup_info.SP_ADC_RE  %adc number
        % info.setup_info.SP_TAC_TC %adc time per channel
        % info.setup_info.SP_IMG_X   %X PIXEL NUMBER
        % info.setup_info.SP_IMG_Y   %Y PIXEL NUMBER
        % info.setup_info.COL_T     %collection time
        
        % 1st byte is data block info
        routing_bit_num=bitand(data(1),RB_NO32)/2^27;
        macroclk_unit=double(bitand(data(1),MT_CLK32))*0.1*1e-9;%ns ,in unit of 0.1ns, converts to ns
        %0x1000 * 50e-9, macro time overflow (12bit) with internal macro time clock
        OV_TIME32=macroclk_unit*2^12;%MACRO TIME OVER FLOW OF 12BIT ADC WITH 50ns INTERVAL
        marker_file=bitand(data(1),M_FILE32)/2^25;%check for marker file, if so we have p/l/f clock
        ismarker=uint32(hex2dec('10000000'));
        data(1)=INVALID_MTOV32;% ignore first byte
        %%
        % --- get data channels ---
        %channel=uint8(bitand(data,ROUT32)/2^12);
        %multi_overflow = logical((bitand(data,INVALID_MTOV32)/2^28)==12); %invalid+macro_overflow
        %multi_overflow_idx=find(multi_overflow);%find multiple overflow index
        %multi_overflow=double(multi_overflow);%change to double for calculation
        %macro_ov_cnt = double(bitand(data(multi_overflow_idx),OV_CNT));%multiple overflow count
        %multi_overflow(multi_overflow_idx)=multi_overflow(multi_overflow_idx).*macro_ov_cnt;%get correct overflow
        macro_overflow = logical(bitand(data,MTOV32)/2^30); %normal overflow event index
        
        % --- calculate global time ---
        gtime_step = OV_TIME32;      %gtime step
        % normal overflow + multiple overflow + recorded time
        %gtime=(cumsum(double(macro_overflow))+cumsum(multi_overflow)).*gtime_step+double(bitand(data,MT32))*macroclk_unit;
        gtime=(cumsum(double(macro_overflow))).*gtime_step+double(bitand(data,MT32))*macroclk_unit;%multiple over flow seem to screw up the gT
        clear multi_overflow overflowmk macro_overflow macro_ov_cnt multi_overflow_idx;
        
        % --- calculate delaytime ---
        %fix time step to 256 neareast
        dtime_bin = ceil(n_dtime_step/256);
        t = dtime_start:dtime_step:dtime_stop;%get delay time scale
        % get delaytime from data
        dtime = (4095-double(bitand(data,ADC32)/2^16))*dtime_max/4096;%calculate real delaytime
        
        % --- find actual photon data ---
        invalid_data = logical(bitand(data,INVALID32)/2^31); %valid delay time indices
        
        % --- image parameters info ---
        if marker_file==1
            marker_pixel=logical((bitand(data,P_MARK32)-MARKER_FRAME)/2^12);         %pixel marker
            marker_line=logical((bitand(data,L_MARK32)-MARKER_FRAME)/2^13);         %line marker
            marker_frame=logical((bitand(data,F_MARK32)-MARKER_FRAME)/2^14);           %frame marker
            %marker_hw=logical((bitand(data,HW_MARK32)-MARKER_FRAME)/2^15);                  %hardware marker
        end
        % remove data to save space
        clear data;
        
        if marker_file==1
            %imaging frame signals
            frame_pos=find(marker_frame==1);  % frame stop mark
            line_pos=find(marker_line==1);    % line stop mark
            pixel_pos=find(marker_pixel==1);  % pixel stop mark
            %hwmarker_pos=find(marker_hw==1);  % hardware mark
            clear marker_frame marker_line marker_pixel marker_hw;
            % --- start getting data into clock data format ---
            framenum=numel(frame_pos);
            if framenum==0
                % linescan has no frame marker
                frame_pos=1;
                framenum=numel(frame_pos);
            end
            [linenum,linestop_framenum]=histc(line_pos,frame_pos);
            if linenum==0
                linenum=numel(line_pos);
            end
            [pixelnum,~]=histc(pixel_pos,line_pos);
            validframe=[];
            % validate line per frame and pixel per line
            set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
            set(0,'DefaultUicontrolForegroundColor','k');
            while isempty(validframe)
                invalidframe=unique(find(linenum~=line_per_frame));
                validframe=setxor(1:1:framenum,invalidframe);
                if isempty(validframe)
                    possibleln=unique(linenum);
                    possibleln=possibleln(possibleln>0);
                    % ask for input
                    answer=inputdlg(sprintf('Image line per frame seemed wrong.\nTry %s\n If unsure press cancel.',num2str(possibleln')),...
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
            possiblepn=unique(pixelnum);
            answer=inputdlg(sprintf('Image pixel per line seemed wrong.\nTry %s',num2str(possiblepn')),...
                'Input required',1,{num2str(max(possiblepn))});
            if isempty(answer)
                % cancel and went back to check
                return;
            else
                temp=str2double(answer);
                pixel_per_line=temp;
            end
            set(0,'DefaultUicontrolBackgroundColor','k');
            set(0,'DefaultUicontrolForegroundColor','w');
        else
            % no marker file we need to know width x height x nframe
            validframe=1;
            invalidframe=0;
            set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
            set(0,'DefaultUicontrolForegroundColor','k');
            %ask for pixel/line/frame info
            % get binning information
            prompt = {'X size',...
                'dX',...
                'Y size',...
                'dY',...
                'T size',...
                'dT'};
            dlg_title = cat(2,'Data size information',obj.data(obj.current_data).dataname);
            num_lines = 1;
            def = {'256','1','256','1','1','1'};
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            set(0,'DefaultUicontrolBackgroundColor','k');
            set(0,'DefaultUicontrolForegroundColor','w');
            if isempty(answer)
                % cancel and went back to check
                return;
            else
                temp=str2double(answer);
                pixel_per_line=temp(1);
                widthstep=temp(2);
                line_per_frame=temp(3);
                heightstep=temp(4);
                nFrame=temp(5);
                framestep=temp(6);
                
            end
        end
        % ------------
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
        button = questdlg('Check data info is correct','Proceed Further?','Cancel','Proceed','Proceed') ;
        % ------------------------
        switch button
            case 'Proceed'
                button = questdlg('Use spc to minimise memory usage','Storage Format','ndim','spc','ndim');
                switch button
                    case 'spc'
                        %assign data
                        data_end_pos=numel(obj.data);
                        obj.data(data_end_pos+1)=obj.data(1);
                        %increment
                        data_end_pos=data_end_pos+1;
                        obj.current_data=data_end_pos;
                        if marker_file==1
                            % get global Time
                            T=gtime(frame_pos);%convert to second
                            % correct frame clock
                            %clock_data format in Frame|Line|Pixel and to be converted using
                            %ind2sub function to pixind in data variable
                            clock_data=zeros(numel(gtime),3)*0.0;
                            % get frame clock
                            clock_data(frame_pos,1)=1;
                            clock_data(:,1)=cumsum(clock_data(:,1));
                            % get line clock
                            clock_data(line_pos,2)=1;
                            clock_data(frame_pos(2:end),2)=-linenum(1:end-1)+1;
                            clock_data(:,2)=cumsum(clock_data(:,2));
                            % get pixel clock
                            clock_data(pixel_pos,3)=1;
                            clock_data(line_pos(2:end),3)=-pixelnum(1:end-1);
                            clock_overlap=intersect(line_pos,pixel_pos);
                            clock_data(clock_overlap,3)=clock_data(clock_overlap,3)+1;
                            clock_data(:,3)=cumsum(clock_data(:,3));
                            clear pixel_pos line_pos frame_pos linestop_framenum pixelnum clock_overlap;
                            % get rid of clock data
                            validdata=(~invalid_data)&(clock_data(:,2)>0)&(clock_data(:,1)>0);
                            clear invalid_data;
                            clock_data=clock_data(validdata,:);
                            maxdim=max(clock_data);
                            pixel_per_line=maxdim(3);
                            line_per_frame=maxdim(2);
                            % convert to linear index for storage
                            clock_data=sub2ind([pixel_per_line,line_per_frame,framenum], clock_data(:,3), clock_data(:,2), clock_data(:,1));
                            % assign dimension data
                            obj.data(data_end_pos).datainfo.bin_t=dtime_bin;
                            obj.data(data_end_pos).datainfo.X=0:1:(pixel_per_line-1)*1;
                            obj.data(data_end_pos).datainfo.Y=0:1:(line_per_frame-1)*1;
                            obj.data(data_end_pos).datainfo.Z=1:1:1;
                            obj.data(data_end_pos).datainfo.t=t;
                            obj.data(data_end_pos).datainfo.dt=t(2)-t(1);
                            obj.data(data_end_pos).datainfo.dX=double(1);
                            obj.data(data_end_pos).datainfo.dY=double(1);
                            obj.data(data_end_pos).datainfo.dZ=double(1);
                            obj.data(data_end_pos).datainfo.T=T;
                            if isempty(diff(T))
                                obj.data(data_end_pos).datainfo.dT=1;
                            else
                                obj.data(data_end_pos).datainfo.dT=mean(diff(T));
                            end
                        else
                            clock_data=zeros(numel(gtime),3)*0.0;
                            % get frame clock
                            frame_time=linspace(gtime(1),gtime(end)+gtime_step,nFrame+1);
                            [~,fidx]=histc(gtime,frame_time);
                            T=frame_time(1:end-1);
                            clock_data(:,1)=fidx;
                            % get line clock
                            nLine=line_per_frame*nFrame;
                            line_time=0:heightstep:gtime(end)+gtime_step;
                            [~,lidx]=histc(gtime,line_time);
                            clock_data(:,2)=mod(lidx-1,line_per_frame)+1;
                            % get pixel clock
                            nPixel=pixel_per_line*line_per_frame*nFrame;
                            pixel_time=0:widthstep:(gtime(end)+gtime_step);
                            [~,pidx]=histc(gtime,pixel_time);
                            clock_data(:,3)=mod(pidx-1,pixel_per_line)+1;
                            %[a,b,c]=index2sub(pidx,pixel_per_line*line_per_frame,pixel_per_line);
                            %clock_data(:,3)=a;clock_data(:,2)=b;clock_data(:,1)=c;
                            validdata=(~invalid_data)&(clock_data(:,1)>0);
                            clock_data=clock_data(validdata,:);
                            clock_data=sub2ind([pixel_per_line,line_per_frame,nFrame], clock_data(:,3), clock_data(:,2), clock_data(:,1));
                            % assign dimension data
                            obj.data(data_end_pos).datainfo.bin_t=dtime_bin;
                            obj.data(data_end_pos).datainfo.X=0:widthstep:(pixel_per_line-1)*widthstep;
                            obj.data(data_end_pos).datainfo.Y=0:heightstep:(line_per_frame-1)*heightstep;
                            obj.data(data_end_pos).datainfo.Z=1:1:1;
                            obj.data(data_end_pos).datainfo.t=t;
                            obj.data(data_end_pos).datainfo.dt=t(2)-t(1);
                            obj.data(data_end_pos).datainfo.dX=widthstep;
                            obj.data(data_end_pos).datainfo.dY=heightstep;
                            obj.data(data_end_pos).datainfo.dZ=double(1);
                            obj.data(data_end_pos).datainfo.T=T;
                            obj.data(data_end_pos).datainfo.dT=framestep;
                        end
                        
                        obj.data(data_end_pos).dataval=[clock_data,dtime(validdata),gtime(validdata)];
                        clear clock_data dtime gtime validdata;
                        %data information
                        f_name=fieldnames(info);
                        for f_idx=1:length(f_name)
                            obj.data(data_end_pos).metainfo.(f_name{f_idx})=info.(f_name{f_idx});
                        end
                        
                        obj.data(data_end_pos).datainfo.note='';
                        obj.data(data_end_pos).datainfo.T_acquisition=info.setup_info.SP_COL_T;
                        obj.data(data_end_pos).datainfo.last_change=datestr(now);
                        obj.data(data_end_pos).datainfo.data_idx=obj.current_data;
                        obj.data(data_end_pos).dataname=info.file_info.Title;
                        obj.data(data_end_pos).datainfo.data_dim=[numel(obj.data(data_end_pos).datainfo.t),...
                            numel(obj.data(data_end_pos).datainfo.X),...
                            numel(obj.data(data_end_pos).datainfo.Y),...
                            numel(obj.data(data_end_pos).datainfo.Z),...
                            numel(obj.data(data_end_pos).datainfo.T)];
                        obj.data(data_end_pos).datatype='DATA_SPC';
                        status=1;
                    case 'ndim'
                        % update valid frames
                        validframe=validframe(:)';
                        %line_per_frame=line_per_frame;
                        % update valid line index in valid frames
                        %linenum=linenum(validframe);
                        validlinenum=arrayfun(@(x)find(linestop_framenum==x),validframe,'UniformOutput',false);
                        %line_pos=line_pos(validlinenum{1}(1):validlinenum{end}(end));
                        temp=cellfun(@(x)line_pos(x),validlinenum,'UniformOutput',false);
                        signal_lineend=cellfun(@(x)x(2:end),temp,'UniformOutput',false);
                        signal_linestart=cellfun(@(x)x(1:end-1),temp,'UniformOutput',false);
                        % get pixel to each line
                        [pixelnum,~]=histc(pixel_pos,line_pos);
                        %[pixelnum,temp]=histc(pixel_linenum,cell2mat(validlinenum));
                        pixel_per_line=pixelnum(1);
                        %clear pixel_framenum pixelnum linestop_framenum linenum;
                        clear temp;
                        
                        frame_per_stack=numel(validframe);
                        % ------
                        %preallocate frame binning and stack
                        if frame_per_stack>1
                            frame_bin=frame_per_stack;
                            frame_skip=1;
                            set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
                            set(0,'DefaultUicontrolForegroundColor','k');
                            answer=inputdlg({cat(2,'Number of frame to bin:(',num2str(frame_per_stack),') @ ',num2str(info.setup_info.DI_MAXCNT),' max count'),'Frame skip:'},'Frame Binning',1,{num2str(frame_bin),num2str(frame_skip)});
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
                        pixel_per_frame=pixel_per_line*line_per_frame;
                        N_steps=numel(Tpage);barstep=0;
                        frame_count=1;
                        for Zsliceind=Zslice
                            %go through z slice
                            for Tpageind=Tpage
                                frame_data=zeros(n_dtime_step,pixel_per_frame);%temporary frame data storage
                                inpageframe=validframe(frame_order{Zsliceind}{Tpageind});
                                % bin in Time
                                parfor frameind=inpageframe
                                    %each time frame to bin together
                                    
                                    signal_ls=signal_linestart{frameind};
                                    signal_le=signal_lineend{frameind};
                                    
                                    %}
                                    %{
                            tempdata=arrayfun(@(ls,le)hist3([dtime(ls:le),gtime(ls:le)],'Nbins',...
                                [n_dtime_step,pixel_per_line]),...
                                signal_ls,signal_le,'UniformOutput',false);
                                    %}
                                    % check valid data
                                    %{
                            tempdata=arrayfun(@(ls,le)hist3([dtime(ls:le),gtime(ls:le)],'Edges',...
                                {t,linspace(gtime(ls),gtime(le),pixel_per_line)'}),...
                                signal_ls,signal_le,'UniformOutput',false);
                                    %}
                                    tempdata=arrayfun(@(ls,le)hist3([dtime(ls:le),gtime(ls:le)],'Edges',...
                                        {t,gtime(pixel_pos(pixel_pos>=ls&pixel_pos<=le))}),...
                                        signal_ls,signal_le,'UniformOutput',false);
                                    
                                    %save frame data
                                    frame_data=frame_data+cell2mat(tempdata');
                                    
                                end
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
                                %assign data
                                obj.data(data_end_pos).dataval(:,:,:,Zsliceind,Tpageind)=reshape(frame_data,[n_dtime_step,pixel_per_line,line_per_frame,1,1]);
                                %frame_data=zeros(n_dtime_step,pixel_per_frame);
                                T(Tpageind)=gtime(line_pos(validlinenum{inpageframe(1)}(1)));
                            end
                        end
                        clear frame_data dtime gtime pixbin linestart_framenum linestop_framenum linestart_pos linestop_pos tempdata;
                        %data information
                        f_name=fieldnames(info);
                        for f_idx=1:length(f_name)
                            obj.data(data_end_pos).metainfo.(f_name{f_idx})=info.(f_name{f_idx});
                        end
                        obj.data(data_end_pos).datainfo.bin_t=dtime_bin;
                        obj.data(data_end_pos).datainfo.X=0:1:(pixel_per_line-1)*1;
                        obj.data(data_end_pos).datainfo.Y=0:1:(line_per_frame-1)*1;
                        obj.data(data_end_pos).datainfo.Z=Zslice;
                        obj.data(data_end_pos).datainfo.t=t;
                        obj.data(data_end_pos).datainfo.dt=t(2)-t(1);
                        obj.data(data_end_pos).datainfo.dX=double(1);
                        obj.data(data_end_pos).datainfo.dY=double(1);
                        obj.data(data_end_pos).datainfo.dZ=double(1);
                        obj.data(data_end_pos).datainfo.note='';
                        obj.data(data_end_pos).datainfo.T_acquisition=info.setup_info.SP_COL_T;
                        obj.data(data_end_pos).datainfo.last_change=datestr(now);
                        obj.data(data_end_pos).datainfo.data_idx=obj.current_data;
                        obj.data(data_end_pos).dataname=info.file_info.Title;
                        obj.data(data_end_pos).datainfo.T=T;
                        obj.data(data_end_pos).datainfo.data_dim=[numel(obj.data(data_end_pos).datainfo.t),...
                            numel(obj.data(data_end_pos).datainfo.X),...
                            numel(obj.data(data_end_pos).datainfo.Y),...
                            numel(obj.data(data_end_pos).datainfo.Z),...
                            numel(obj.data(data_end_pos).datainfo.T)];
                        obj.data(data_end_pos).datatype=obj.get_datatype;
                        delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
                        status=1;
                end
            case 'Cancel'
                message=sprintf('%s\nIncorrect file information\nLoading Cancelled\n',message);
            otherwise
                message=sprintf('%s\nIncorrect file information\nLoading Cancelled\n',message);
        end
    else
        fprintf('unable to open data file\n');
    end
catch exception
    message=sprintf('%s\n',exception.message);
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
end