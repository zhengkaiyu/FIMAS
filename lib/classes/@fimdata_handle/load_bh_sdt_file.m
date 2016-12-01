function [ status, message ]= load_bh_sdt_file( obj, filename )
%load_bh_sdt_file load Becker & Hickl sdt file (uncompressed version preferred)
%

%% function check

% assume the worst
status=false;
try
    %%
    %===================
    %=====Constants=====
    %===================
    FILE_HEADER_VALID='5555';
    FILE_HEADER_INVALID='1111';
    
    BLOCK_CREATION_MASK=bin2dec('1111');
    Block_Creation={0,'NOT_USED';...
        1,'MEAS_DATA';...   %NORMAL MEASUREMENT MODES
        2,'FLOW_DATA';...   %CONTINUOUS FLOW MEASUREMENT (BIFL)
        3,'MEAS_DATA_FROM_FILE';...
        4,'CALC_DATA';...   %CALCULATED DATA
        5,'SIM_DATA';...    %SIMULATED DATA
        8,'FIFO_DATA';...   %FIFO MODE DATA
        9,'FIFO_DATA_FROM_FILE';...    %FIFO MODE DATA
        10,'MOM_DATA';...           %moments mode data
        11,'MOM_DATA_FROM_FILE'};
    
    BLOCK_CONTENT_MASK=bin2dec('11110000');
    Block_Content={0,'DECAY_BLOCK';...  %0x00//ONE DECAY CURVE
        16,'PAGE_BLOCK';...  %0x10//SET OF DECAY CURVES = MEASURED PAGE
        32,'FCS_BLOCK';...   %0x20//FCS HISTOGRAM CURVE
        48,'FIDA_BLOCK';...  %0x30//FIDA HISTOGRAM CURVE
        64,'FILDA_BLOCK';... %0x40//FILDA HISTOGRAM CURVE
        80,'MCS_BLOCK';...   %0x50//MCS HISTOGRAM CURVE
        96,'IMG_BLOCK';...      %0x60//FIFO IMAGE - SET OF CURVES
        112,'MCSTA_BLOCK';...   %0x70// MCS Triggered Accumulation histogram curve
        128,'IMG_MCS_BLOCK';...  %0x80// fifo image - set of curves = MCS FLIM
        144,'MOM_BLOCK'};      %0x90// moments mode - set of moments data frames
    
    BLOCK_DATA_TYPE_MASK=bin2dec('111100000000');
    Block_Data_Type={0,'ushort',2;...    %16-BIT UNSINGED SHORT
        256,'ulong',4;...   %32-BIT UNSIGNED LONG, FOR FIFO DECAY CURVES
        512,'double',4};        %32-BIT DOUBLE, FOR HISTOGRAM DATA BLOCKS
    
    BLOCK_DATA_COMPRESS_MASK=bin2dec('1000000000000');
    Block_Data_Compression={0,'UNCOMPRESSED';...
        1,'COMPRESSED'};
    
    BLOCK_DATA_PAGEDATA_MASK=bin2dec('1110000000000000');
    Block_Data_Pagedata={17,'MEAS_PAGE';... %0x11
        18,'FLOW_PAGE';... %0x12
        19,'MEAS_PAGE_FROM_FILE';...   %0x13
        20,'CALC_PAGE';... %0x14
        21,'SIM_PAGE'};  %0x15
    
    %=================================
    %===File Information Related======
    %=================================
    %------file header------
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
    
    %------measurement info--------
    % information collected when measurement is finished
    MeasStopInfo=struct('status',{''},...% last SPC_test_state return value ( status )
        'flags',{''},...% scan clocks bits 2-0( frame, line, pixel), rates_read - bit 15
        'stop_time',{''},...% time from start to  - disarm ( simple measurement )- or to the end of the cycle (for complex measurement )
        'cur_step',{''},...% current step  ( if multi-step measurement )
        'cur_cycle',{''},...% current cycle (accumulation cycle in FLOW mode ) -( if multi-cycle measurement )
        'cur_page',{''},...% current measured page
        'min_sync_rate',{''},...% minimum rates during the measurement
        'min_cfd_rate',{''},...%   ( -1.0 - not set )
        'min_tac_rate',{''},...
        'min_adc_rate',{''},...
        'max_sync_rate',{''},...% maximum rates during the measurement
        'max_cfd_rate',{''},...%   ( -1.0 - not set )
        'max_tac_rate',{''},...
        'max_adc_rate',{''},...
        'reserved1',{''},...
        'reserved2',{''});
    
    MeasStopInfo_format={'ushort','ushort','float','int','int','int','float',...
        'float','float','float','float','float','float','float','int','float'};
    
    % information collected when FIFO measurement is finished
    MeasFCSInfo=struct( 'chan',{''},...               % routing channel number
        'fcs_decay_calc',{''},...     % bit 0 = 1 - decay curve calculated; bit 1 = 1 - fcs   curve calculated; bit 2 = 1 - FIDA  curve calculated; bit 3 = 1 - FILDA curve calculated; bit 4 = 1 - MCS curve calculated; bit 5 = 1 - 3D Image calculated
        'mt_resol',{''},...           % macro time clock in 0.1 ns units
        'cortime',{''},...            % correlation time [ms]
        'calc_photons',{''},...       %  no of photons
        'fcs_points',{''},...         % no of FCS values
        'end_time',{''},...           % macro time of the last photon
        'overruns',{''},...           % no of Fifo overruns when > 0  fcs curve & end_time are not valid
        'fcs_type',{''},...   % 0 - linear FCS with log binning ( 100 bins/log ) when bit 15 = 1 ( 0x8000 ) - Multi-Tau FCS where bits 14-0 = ktau parameter
        'cross_chan',{''},...         % cross FCS routing channel number when chan = cross_chan and mod == cross_mod - Auto FCS otherwise - Cross FCS
        'mod',{''},...                % module number
        'cross_mod',{''},...          % cross FCS module number
        'cross_mt_resol',{''});    % macro time clock of cross FCS module in 0.1 ns units
    % extension of MeasFCSInfo for other histograms ( FIDA, FILDA, MCS )
    MeasFCSInfo_format={'ushort','ushort','uint','float','uint','int','float',...
        'ushort','ushort','ushort','ushort','ushort','uint'};
    
    MeasHISTInfo=struct('fida_time',{''},...% interval time [ms] for FIDA histogram
        'filda_time',{''},...         % interval time [ms] for FILDA histogram
        'fida_points',{''},...        % no of FIDA values or current frame number ( fifo_image)
        'filda_points',{''},...       % no of FILDA values or current line  number ( fifo_image)
        'mcs_time',{''},...            % interval time [ms] for MCS histogram
        'mcs_points',{''},...          % no of MCS values or current pixel number ( fifo_image)
        'cross_calc_phot',{''},...    %  no of calculated photons from cross_channel for Cross FCS histogram
        'mcsta_points',{''},...     %no of MCS_TA values
        'mcsta_flags',{''},...        %MCS_TA flags   bit 0 = 1 - use 'invalid' photons, bit 1-2  =  marker no used as trigger
        'mcsta_tpp',{''},...          %MCS_TA Time per point  in Macro Time units time per point[s] = mcsta_tpp * mt_resol( from MeasFCSInfo)
        'calc_markers',{''},...       %no of calculated markers for MCS_TA
        'reserved3',{''});
    MeasHISTInfo_format={'float','float','int','int','float',...
        'int','uint','ushort','ushort','uint','uint','double'};
    
    Measure_Info=struct('time',{''},...   %time of creation
        'date',{''},...   %date of creation
        'mod_ser_no',{''},... %serial number of the module
        'meas_mode',{''},...
        'cfd_ll',{''},...
        'cfd_lh',{''},...
        'cfd_zc',{''},...
        'cfd_hf',{''},...
        'syn_zc',{''},...
        'syn_fd',{''},...
        'syn_hf',{''},...
        'tac_r',{''},...
        'tac_g',{''},...
        'tac_of',{''},...
        'tac_ll',{''},...
        'tac_lh',{''},...
        'adc_re',{''},...
        'eal_de',{''},...
        'ncx',{''},...
        'ncy',{''},...
        'page',{''},...
        'col_t',{''},...
        'rep_t',{''},...
        'stopt',{''},...
        'overfl',{''},...
        'use_motor',{''},...
        'steps',{''},...
        'offset',{''},...
        'dither',{''},...
        'incr',{''},...
        'mem_bank',{''},...
        'mod_type',{''},...   % module type
        'syn_th',{''},...
        'dead_time_comp',{''},...
        'polarity_l',{''},...   %  2 = disabled line markers
        'polarity_f',{''},...
        'polarity_p',{''},...
        'linediv',{''},...      % line predivider = 2 ** ( linediv)
        'accumulate',{''},...
        'flbck_y',{''},...
        'flbck_x',{''},...
        'bord_u',{''},...
        'bord_l',{''},...
        'pix_time',{''},...
        'pix_clk',{''},...
        'trigger',{''},...
        'scan_x',{''},...
        'scan_y',{''},...
        'scan_rx',{''},...
        'scan_ry',{''},...
        'fifo_typ',{''},...
        'epx_div',{''},...
        'mod_type_code',{''},...
        'mod_fpga_ver',{''},...    % new in v.8.4
        'overflow_corr_factor',{''},...
        'adc_zoom',{''},...
        'cycles',{''},...        %cycles ( accumulation cycles in FLOW mode )
        'StopInfo',{MeasStopInfo},...       %MeasStopInfo structure
        'FCSInfo',{MeasFCSInfo},...   % MeasFCSInfo structure valid only for FIFO meas
        'image_x',{''},...       % 4 subsequent fields valid only for Camera mode
        'image_y',{''},...       %     or FIFO_IMAGE mode
        'image_rx',{''},...
        'image_ry',{''},...
        'xy_gain',{''},...       % gain for XY ADCs ( SPC930 )
        'master_clock',{''},...  % use or not  Master Clock (SPC140 multi-module )
        'adc_de',{''},...        % ADC sample delay ( SPC-930 )
        'det_type',{''},...      % detector type ( SPC-930 in camera mode )
        'x_axis',{''},...        % X axis representation ( SPC-930 )
        'HISTInfo',{MeasHISTInfo},...       %MeasHISTInfo structure
        'HISTInfoExt',{''},...
        'reserve',{''});    %total size of MeasureInfo = 512 bytes
    
    Measure_Info_format={'char9','char11','char16','short','float','float','float','float','float','short',...
        'float','float','short','float','float','float','short','short','short','short','ushort','float','float',...
        'short','char','short','ushort','float','short','short','short','char16','float','short','short','short','short',...
        'short','short','int','int','int','int','float','short','short','int','int','int','int','short','int','ushort','ushort',...
        'float','int','int','MeasStopInfo_format','MeasFCSInfo_format','int','int','int','int','short','short','short','short',...
        'short','MeasHISTInfo_format','MeasHISTInfoExt_format','char'};
    
    
    %------data block info--------
    Data_Header=struct('block_no',{''},... % number of the block in the file valid only  when in 0 .. 0x7ffe range, otherwise use lblock_no field obsolete now, lblock_no contains full block no information
        'data_offs',{''},...       % offset of the data block from the beginning of the file
        'next_block_offs',{''},... % offset to the data block header of the next data block
        'block_type',{''},...      % see block_type defines below
        'meas_desc_block_no',{''},... % Number of the measurement description block corresponding to this data block
        'lblock_no',{''},...       % long block_no - see remarks below
        'block_length',{''});    % reserved2 now contains block( set ) length
    Data_Header_format={'short','long','long','ushort','short','ulong','ulong'};
    Data_Info=struct('creation',{''},...
        'content',{''},...
        'format',{''},...
        'mod_factor',{''},...
        'compression',{''}); %in new version only
    %=====
    info=struct('file_header',{BH_File_Header},...
        'file_info',{File_Info},...
        'setup_info',{Setup_Info},...
        'measure_info',{Measure_Info},...
        'data_header',{Data_Header},...
        'data_info',{Data_Info});
    
    %%
    %===========================================
    %===========================================
    %Read Becker-Hickl Binary Data from SPC-830
    %===========================================
    %open file for reading
    [fid,message]=fopen(filename,'r');
    if fid>=3 %successfully opened
        %=================================
        %=======FILE INFORAMATION=========
        %=================================
        %--- Read File Header Section ---
        f_name=fieldnames(BH_File_Header);
        for n=1:length(BH_File_Header_format)
            info.file_header.(f_name{n})=fread(fid,1,BH_File_Header_format{n});
        end
        %check module identification
        switch dec2hex(bitshift(info.file_header.revision,-4))
            case '20'%SPC130
                info.file_header.hwmodule='SPC130';
            case '28'%SPC150
                info.file_header.hwmodule='SPC150';
            case '25'%SPC830
                info.file_header.hwmodule='SPC830';
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
        
        %--- Read File Information ---
        if ftell(fid)==info.file_header.info_offs %check file position is correct
            buffer=fread(fid,info.file_header.info_length,File_Info_format);
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
        
        %--- Read Setup ---
        %ASCII part
        %ASCII part
        if ftell(fid)==info.file_header.setup_offs
            buffer=fread(fid,info.file_header.setup_length,Setup_ASCII_format);
            temp=char(buffer');
            temp=regexp(temp,'*END','split');
            info.setup_info=temp{1};%ascii part
        else
            fprintf('%s\n','Setup Information size error!');
        end
        %Binary part
        
        %=============================================================
        %========Read data block and measurement descriptions=========
        %=============================================================
        
        %=====Read Measurement Description Block=========
        if ftell(fid)==info.file_header.meas_desc_block_offs
            f_name=fieldnames(info.measure_info);
            %read every measurement describtion block
            for n=1:info.file_header.no_of_meas_desc_blocks
                if n>1%not the first block
                    info.measure_info(n)=info.measure_info(n-1);
                    if ftell(fid)~=info.file_header.meas_desc_block_offs
                        %realign if offset because of version differences
                        newfidpos=info.file_header.meas_desc_block_offs+(n-1)*info.file_header.meas_desc_block_length;
                        fseek(fid,newfidpos,-1);
                    end
                end
                %first block
                for k=1:length(f_name)
                    if strfind(Measure_Info_format{k},'char')
                        n_char=str2double(Measure_Info_format{k}(5:end));
                        if isnan(n_char)
                            n_char=1;
                        end
                        info.measure_info(n).(f_name{k})=char(fread(fid,n_char,'char')');
                    elseif strfind(Measure_Info_format{k},'MeasStopInfo_format')
                        f_name_2=fieldnames(info.measure_info(n).StopInfo);
                        for p=1:length(f_name_2)
                            info.measure_info(n).(f_name{k}).(f_name_2{p})=fread(fid,1,MeasStopInfo_format{p});
                        end
                    elseif strfind(Measure_Info_format{k},'MeasFCSInfo_format')
                        f_name_2=fieldnames(info.measure_info(n).FCSInfo);
                        for p=1:length(f_name_2)
                            info.measure_info(n).(f_name{k}).(f_name_2{p})=fread(fid,1,MeasFCSInfo_format{p});
                        end
                    elseif strfind(Measure_Info_format{k},'MeasHISTInfo_format')
                        f_name_2=fieldnames(info.measure_info(n).HISTInfo);
                        for p=1:length(f_name_2)
                            info.measure_info(n).(f_name{k}).(f_name_2{p})=fread(fid,1,MeasHISTInfo_format{p});
                        end
                    elseif strfind(Measure_Info_format{k},'MeasHISTInfoExt_format')
                        
                    else
                        info.measure_info(n).(f_name{k})=fread(fid,1,Measure_Info_format{k});
                    end
                end
                fseek(fid,info.file_header.meas_desc_block_offs+n*512,-1);%total size of each measureinfo block =512byte
            end
        else
            fprintf('%s\n','Measurement Description size error!');
        end
        
        %======Check Data Block position=======
        if ftell(fid)==info.file_header.data_block_offs
            %everything is fine
        else
            fprintf('%s\n','Data block size error!Reset of File Header Offset Position.')
            fseek(fid,info.file_header.data_block_offs,-1);%seek the start of data block
        end
        %======Read Data Block=======
        for m=1:info.file_header.no_of_data_blocks
            f_name=fieldnames(info.data_header);
            %--- Extraction Information ---
            %header
            for n=1:length(f_name)
                info.data_header(m).(f_name{n})=fread(fid,1,Data_Header_format{n});
            end
            
            %main info
            %creation mode
            buffer=bitand(info.data_header(m).block_type,BLOCK_CREATION_MASK);
            pos=find(cell2mat(Block_Creation(:,1))==buffer);
            if isempty(pos)
                fprintf('%s\n','Unknown block creation mode!');
            else
                %fprintf('%s = %s\n','block creation mode=',Block_Creation{pos,2});
                info.data_info(m).creation=Block_Creation{pos,2};
            end
            
            %content type, determins data type
            buffer=bitand(info.data_header(m).block_type,BLOCK_CONTENT_MASK);
            pos=find(cell2mat(Block_Content(:,1))==buffer);
            if isempty(pos)
                fprintf('%s\n','Unknown block content type!');
            else
                %fprintf('%s = %s\n','block content type',Block_Content{pos,2});
                info.data_info(m).content=Block_Content{pos,2};
            end
            %format
            buffer=bitand(info.data_header(m).block_type,BLOCK_DATA_TYPE_MASK);
            pos=find(cell2mat(Block_Data_Type(:,1))==buffer);
            if isempty(pos)
                fprintf('%s\n','Unknown block content format!');
                info.data_info(m).format='ubit8';%1 byte standard
                info.data_info(m).mod_factor=1;
            else
                %fprintf('%s = %s\n','block data type',Block_Data_Type{pos,2});
                info.data_info(m).format=Block_Data_Type{pos,2};
                info.data_info(m).mod_factor=Block_Data_Type{pos,3};
            end
            %compression
            buffer=bitand(info.data_header(m).block_type,BLOCK_DATA_COMPRESS_MASK);
            pos=find(cell2mat(Block_Data_Compression(:,1))==buffer);
            if isempty(pos)
                fprintf('%s\n','Unknown block compression mode!');
            else
                %fprintf('%s = %s\n','block data compression',Block_Data_Compression{pos,2});
                info.data_info(m).compression=Block_Data_Compression{pos,2};
            end
            %{
            
                            u
                %read raw data
                raw=fread(rawfid,info.data_header(m).block_length/info.data_info(m).mod_factor,info.data_info(m).format);
            %}
            %--- Extraction Data ---
            raw=fread(fid,info.data_header(m).block_length/info.data_info(m).mod_factor,info.data_info(m).format);
            %Data block length is calculated on 1 byte basis, hence /mod_factor
            if ftell(fid)==info.data_header(m).next_block_offs
                %everything is fine
            else
                fprintf('%s\n','Data block size error! Readjust file pointer position');
                fseek(fid,info.data_header(m).next_block_offs,-1);
            end
            
            %add data
            data_end_pos=numel(obj.data);
            obj.data(data_end_pos+1)=obj.data(1);
            data_end_pos=data_end_pos+1;
            obj.current_data=data_end_pos;
            %----assign file infos-----
            f_name=fieldnames(info);
            for f_idx=1:3
                obj.data(data_end_pos).metainfo.(f_name{f_idx})=info.(f_name{f_idx});
            end
            if numel(info.measure_info)>1
                obj.data(data_end_pos).metainfo.measure_info=info.measure_info(m);
            else
                obj.data(data_end_pos).metainfo.measure_info=info.measure_info;
            end
            obj.data(data_end_pos).metainfo.data_header=info.data_header(m);
            obj.data(data_end_pos).metainfo.data_info=info.data_info(m);
            %---assign data infos---
            %colleciton time
            obj.data(data_end_pos).datainfo.T_acquisition=info.measure_info(1).col_t;
            %notes
            obj.data(data_end_pos).datainfo.note=info.file_info.Contents;
            
            %---assign values from info ----
            [~,filename,~]=fileparts(filename);
            obj.data(data_end_pos).dataname=cat(2,filename,'-b',num2str(m));%assign data name
            %time units and micro time
            t_scale=info.measure_info(m).tac_r./info.measure_info(m).tac_g; %sec
            obj.data(data_end_pos).datainfo.dt=t_scale/(info.measure_info(m).adc_re-1);
            obj.data(data_end_pos).datainfo.t=linspace(0,t_scale,info.measure_info(m).adc_re)';
            obj.data(data_end_pos).datainfo.data_idx=data_end_pos;%data index
            %--- Reformat Data & Fill in info---
            switch info.data_info(m).content
                case 'FCS_BLOCK'
                    
                case 'PAGE_BLOCK'
                    %time x scan_x x scan_y x page
                    obj.data(data_end_pos).dataval=reshape(raw,[info.measure_info(m).adc_re,info.measure_info(m).ncx,info.measure_info(m).ncy,1,info.measure_info(m).steps]);
                    obj.data(data_end_pos).datainfo.data_dim=[info.measure_info(m).adc_re,...
                        info.measure_info(m).ncx,...
                        info.measure_info(m).ncy,...
                        1,...
                        info.measure_info(m).steps];
                    obj.data(data_end_pos).datatype=obj.get_datatype;
                    obj.data(data_end_pos).datainfo.dX=1;
                    obj.data(data_end_pos).datainfo.dY=1;
                    obj.data(data_end_pos).datainfo.dZ=1;
                    obj.data(data_end_pos).datainfo.dT=1;
                    obj.data(data_end_pos).datainfo.X=linspace(1,obj.data(data_end_pos).datainfo.dX*info.measure_info(m).ncx,info.measure_info(m).ncx);
                    obj.data(data_end_pos).datainfo.Y=linspace(1,obj.data(data_end_pos).datainfo.dY*info.measure_info(m).ncy,info.measure_info(m).ncy);
                    obj.data(data_end_pos).datainfo.Z=linspace(1,obj.data(data_end_pos).datainfo.dZ*1,1);
                    obj.data(data_end_pos).datainfo.T=linspace(1,obj.data(data_end_pos).datainfo.dT*info.measure_info(m).steps,info.measure_info(m).steps);
                case 'DECAY_BLOCK'
                    %time x scan_x x scan_y x page
                    obj.data(data_end_pos).dataval=reshape(raw,[info.measure_info(m).adc_re,info.measure_info(m).page,1,1,info.measure_info(m).steps]);
                    obj.data(data_end_pos).datainfo.data_dim=[info.measure_info(m).adc_re,...
                        info.measure_info(m).page,...
                        1,...
                        1,...
                        info.measure_info(m).steps];
                    obj.data(data_end_pos).datatype=obj.get_datatype;
                    obj.data(data_end_pos).datainfo.dX=1;
                    obj.data(data_end_pos).datainfo.dY=1;
                    obj.data(data_end_pos).datainfo.dZ=1;
                    obj.data(data_end_pos).datainfo.dT=1;
                    obj.data(data_end_pos).datainfo.X=linspace(1,obj.data(data_end_pos).datainfo.dX*info.measure_info(m).ncx,info.measure_info(m).page);
                    obj.data(data_end_pos).datainfo.Y=linspace(1,obj.data(data_end_pos).datainfo.dY*1,1);
                    obj.data(data_end_pos).datainfo.Z=linspace(1,obj.data(data_end_pos).datainfo.dZ*1,1);
                    obj.data(data_end_pos).datainfo.T=linspace(1,obj.data(data_end_pos).datainfo.dT*info.measure_info(m).steps,info.measure_info(m).steps);
                case 'IMG_BLOCK'
                    %image blocks
                    %update data info
                    if (info.measure_info(m).image_x==0)||(info.measure_info(m).image_y==0)
                        %empty data
                        obj.data(data_end_pos).dataval=[];
                    else
                        obj.data(data_end_pos).datainfo.dX=1;
                        x_scale=obj.data(data_end_pos).datainfo.dX*info.measure_info(m).image_x;
                        obj.data(data_end_pos).datainfo.X=linspace(0,x_scale,info.measure_info(m).image_x)';
                        obj.data(data_end_pos).datainfo.dY=1;
                        y_scale=obj.data(data_end_pos).datainfo.dY*info.measure_info(m).image_y;
                        obj.data(data_end_pos).datainfo.Y=linspace(0,y_scale,info.measure_info(m).image_y)';
                        %assige data
                        if info.measure_info(m).image_x==0 || info.measure_info(m).image_y==0
                            %empty
                            obj.data(data_end_pos).dataval=nan(info.measure_info(m).adc_re,info.measure_info(m).image_x,info.measure_info(m).image_y,1,1);
                        else
                            %time x image_x x image_y
                            obj.data(obj.current_data).dataval=reshape(raw,info.measure_info(m).adc_re,info.measure_info(m).image_x,info.measure_info(m).image_y,1,1);
                        end
                        obj.data(obj.current_data).datainfo.data_dim=[info.measure_info(m).adc_re,...
                            info.measure_info(m).image_x,...
                            info.measure_info(m).image_y,...
                            1,1];
                        obj.data(data_end_pos).datatype=obj.get_datatype;
                    end
                otherwise
                    obj.data(data_end_pos).dataval=raw;
            end
            obj.data(data_end_pos).datainfo.last_change=datestr(now);
            %clean up
            clear raw;
        end
        %==================
        %=======EOF========
        %==================
        if feof(fid)==fseek(fid,0,1)
            fprintf('%s\n','End of File');
        else
            fprintf('%s\n','Have not reached EOF!');
        end
        %close file handle
        fclose(fid);
        status=true;
        %clean up
        clear buffer;clear temp;
    else
        errordlg(message,'Cannot Read file','modal');
    end
    
catch exception
    message=sprintf('%s\n',exception.message);
end