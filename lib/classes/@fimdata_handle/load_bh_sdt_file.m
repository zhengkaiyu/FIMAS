function [ status, message ] = load_bh_sdt_file( obj, filename )
%load_bh_sdt_file load Becker & Hickl sdt file (uncompressed version only)
%

%% function check

% assume the worst
status=false;
try
    %%
    %===================
    %=====Constants=====
    %===================
    BH_HDR_LENGTH=42;
    BH_HEADER_VALID='5555';
    BH_HEADER_INVALID='1111';
    BH_HEADER_CHKSUM='55aa';
    BH_MAX_SPC=4;

    BH_FILE_TYPE={1,'NON_FIFO';...     %NON-FIFO MODE
        2,'FIFO';...                %FIFO MODE
        3,'FIFO_IMAGE'};            %FIFO IMAGE MODE

    BH_REVISION_MASK=bin2dec('1111');
    BH_MODULE_MASK=bin2dec('111111110000');
    BH_MODULE_ID={32,'SPC-130';...         %'0x20'
        33,'SPC-600';...                %'0x21'
        34,'SPC-630';...                %'0x22'
        35,'SPC-700';...                %'0x23'
        36,'SPC-730';...                %'0x24'
        37,'SPC-830';...                %'0x25'
        38,'SPC-140';...                %'0x26'
        39,'SPC-930';...                %'0x27'
        40,'SPC-150';...                %'0x28'
        41,'DPC-230';...                %'0x29'
        42,'SPC-130EM';...              %'0x2a'
        43,'SPC-160';...                %'0x2b'
        46,'SPC-150N';...               %'0x2e'
        128,'SPC-150NX';...             %'0x80'
        129,'SPC-160X';...              %'0x81'
        130,'SPC-160PCIE';...           %'0x82'
        131,'SPC-130EMN';...            %'0x83'
        132,'SPC-180N';...              %'0x84'
        133,'SPC-180NX';...             %'0x85'
        134,'SPC-180NXX';...            %'0x86'
        135,'SPC-180N-USB';...          %'0x87'
        136,'SPC-130IN';...             %'0x88'
        137,'SPC-130INX';...            %'0x89'
        138,'SPC-130INXX';...           %'0x8a'
        139,'SPC-QC-104';...            %'0x8b'
        140,'SPC-QC-004'};              %'0x8c'

    BH_BLOCK_CREATION_MASK=bin2dec('1111');
    BH_Block_Creation={0,'NOT_USED';...
        1,'MEAS_DATA';...               % NORMAL MEASUREMENT MODES
        2,'FLOW_DATA';...               % CONTINUOUS FLOW MEASUREMENT (BIFL)
        3,'MEAS_DATA_FROM_FILE';...
        4,'CALC_DATA';...               % CALCULATED DATA
        5,'SIM_DATA';...                % SIMULATED DATA
        8,'FIFO_DATA';...               % FIFO MODE DATA
        9,'FIFO_DATA_FROM_FILE';...     % FIFO MODE DATA
        10,'MOM_DATA';...               % moments mode data
        11,'MOM_DATA_FROM_FILE'};

    BH_BLOCK_CONTENT_MASK=bin2dec('11110000');
    BH_Block_Content={0,'DECAY_BLOCK';...  % 0x00 ONE DECAY CURVE
        16,'PAGE_BLOCK';...             % 0x10 SET OF DECAY CURVES = MEASURED PAGE
        32,'FCS_BLOCK';...              % 0x20 FCS HISTOGRAM CURVE
        48,'FIDA_BLOCK';...             % 0x30 FIDA HISTOGRAM CURVE
        64,'FILDA_BLOCK';...            % 0x40 FILDA HISTOGRAM CURVE
        80,'MCS_BLOCK';...              % 0x50 MCS HISTOGRAM CURVE
        96,'IMG_BLOCK';...              % 0x60 FIFO IMAGE - SET OF CURVES
        112,'MCSTA_BLOCK';...           % 0x70  MCS Triggered Accumulation histogram curve
        128,'IMG_MCS_BLOCK';...         % 0x80  fifo image - set of curves = MCS FLIM
        144,'MOM_BLOCK'};               % 0x90  moments mode - set of moments data frames

    BH_BLOCK_DATA_TYPE_MASK=bin2dec('111100000000');
    BH_Block_Data_Type={0,'ushort',2;...   % 16-BIT UNSINGED SHORT
        256,'ulong',4;...               % 32-BIT UNSIGNED LONG, FOR FIFO DECAY CURVES
        512,'double',4};                % 32-BIT DOUBLE, FOR HISTOGRAM DATA BLOCKS

    BH_BLOCK_DATA_COMPRESS_MASK=bin2dec('1000000000000');
    BH_Block_Data_Compression={0,'UNCOMPRESSED';...
        1,'COMPRESSED'};

    BH_BLOCK_DATA_PAGEDATA_MASK=bin2dec('1110000000000000');
    BH_Block_Data_Pagedata={17,'MEAS_PAGE';... % 0x11
        18,'FLOW_PAGE';...                  % 0x12
        19,'MEAS_PAGE_FROM_FILE';...        % 0x13
        20,'CALC_PAGE';...                  % 0x14
        21,'SIM_PAGE'};                     % 0x15

    %=================================
    %===File Information Related======
    %=================================
    %------file header------
    BH_File_Header_format=struct('revision','short',... % software revision number  (lower 4 bits >= 10(decimal))
        'info_offs','long',...                          % offset of the info part which contains general text information (Title, date, time, contents etc.)
        'info_length','short',...                       % length of the info part
        'setup_offs','long',...                         % offset of the setup text data (system parameters, display parameters, trace parameters etc.)
        'setup_length','ushort',...                     % length of the setup data
        'data_block_offs','long',...                    % offset of the first data block
        'no_of_data_blocks','short',...                 % no_of_data_blocks valid only when in 0 .. 0x7ffe range,if equal to 0x7fff  the  field 'reserved1' contains valid no_of_data_blocks
        'data_block_length','ulong',...                 % length of the longest block in the file
        'meas_desc_block_offs','long',...               % offset to 1st. measurement description block (system parameters connected to data blocks)
        'no_of_meas_desc_blocks','short',...            % number of measurement description blocks
        'meas_desc_block_length','short',...            % length of the measurement description blocks
        'header_valid','ushort',...                     % valid: 0x5555, not valid: 0x1111
        'reserved1','ulong',...                         % reserved1 now contains no_of_data_blocks
        'reserved2','ushort',...
        'chksum','ushort');                             % checksum of file header

    %------file info------
    BH_File_Info_format=struct('ID','char',...
        'Title','char',...
        'Version','char',...
        'Revision','char',...
        'Date','char',...
        'Time','char',...
        'Author','char',...
        'Company','char',...
        'Contents','char');

    %------setup info------

    %------measurement info--------
    % information collected when measurement is finished
    BH_MeasStopInfo_format=struct('status','ushort',...    % last SPC_test_state return value ( status )
        'flags','ushort',...                            % scan clocks bits 2-0( frame, line, pixel), rates_read - bit 15
        'stop_time','float',...                         % time from start to  - disarm ( simple measurement )- or to the end of the cycle (for complex measurement )
        'cur_step','int',...                            % current step  ( if multi-step measurement )
        'cur_cycle','int',...                           % current cycle (accumulation cycle in FLOW mode ) -( if multi-cycle measurement )
        'cur_page','int',...                            % current measured page
        'min_sync_rate','float',...                     % minimum rates during the measurement
        'min_cfd_rate','float',...                      % ( -1.0 - not set )
        'min_tac_rate','float',...
        'min_adc_rate','float',...
        'max_sync_rate','float',...                     % maximum rates during the measurement
        'max_cfd_rate','float',...                      % ( -1.0 - not set )
        'max_tac_rate','float',...
        'max_adc_rate','float',...
        'reserved1','int',...
        'reserved2','float');

    % information collected when FIFO measurement is finished
    BH_MeasFCSInfo_format=struct( 'chan','ushort',...      % routing channel number
        'fcs_decay_calc','ushort',...                   % bit 0 = 1 - decay curve calculated; bit 1 = 1 - fcs   curve calculated; bit 2 = 1 - FIDA  curve calculated; bit 3 = 1 - FILDA curve calculated; bit 4 = 1 - MCS curve calculated; bit 5 = 1 - 3D Image calculated
        'mt_resol','uint',...                           % macro time clock in 0.1 ns units
        'cortime','float',...                           % correlation time [ms]
        'calc_photons','uint',...                       % no of photons
        'fcs_points','int',...                          % no of FCS values
        'end_time','float',...                          % macro time of the last photon
        'overruns','ushort',...                         % no of Fifo overruns when > 0  fcs curve & end_time are not valid
        'fcs_type','ushort',...                         % 0 - linear FCS with log binning ( 100 bins/log ) when bit 15 = 1 ( 0x8000 ) - Multi-Tau FCS where bits 14-0 = ktau parameter
        'cross_chan','ushort',...                       % cross FCS routing channel number when chan = cross_chan and mod == cross_mod - Auto FCS otherwise - Cross FCS
        'mod','ushort',...                              % module number
        'cross_mod','ushort',...                        % cross FCS module number
        'cross_mt_resol','uint');                        % macro time clock of cross FCS module in 0.1 ns units

    % extension of MeasFCSInfo for other histograms ( FIDA, FILDA, MCS )
    BH_MeasHISTInfo_format=struct('fida_time','float',...  % interval time [ms] for FIDA histogram
        'filda_time','float',...                        % interval time [ms] for FILDA histogram
        'fida_points','int',...                         % no of FIDA values or current frame number ( fifo_image)
        'filda_points','int',...                        % no of FILDA values or current line  number ( fifo_image)
        'mcs_time','float',...                          % interval time [ms] for MCS histogram
        'mcs_points','int',...                          % no of MCS values or current pixel number ( fifo_image)
        'cross_calc_phot','uint',...                    % no of calculated photons from cross_channel for Cross FCS histogram
        'mcsta_points','ushort',...                     % no of MCS_TA values
        'mcsta_flags','ushort',...                      % MCS_TA flags   bit 0 = 1 - use 'invalid' photons, bit 1-2  =  marker no used as trigger
        'mcsta_tpp','uint',...                          % MCS_TA Time per point  in Macro Time units time per point[s] = mcsta_tpp * mt_resol( from MeasFCSInfo)
        'calc_markers','uint',...                       % no of calculated markers for MCS_TA
        'fcs_calc_phot','uint',...                      % no of calculated pohtons for FCS histogram
        'reserved3','uint');                            % not used

    BH_MeasHISTInfoExt_format=struct('first_frame_time','float',...    % macro time of the 1st frame marker
        'frame_time','float',...                                    % time between first two frame markers
        'line_time','float',...                                     % time between first two line markers (in the 1st frame)
        'pixel_time','float',...                                    % time between first two pixel markers (in the 1st frame&line)
        'scan_type','short',...                                     % 0 - unidir, 1 - bidir
        'skip_2nd_line_clk','short',...                             % fifo image (some microscope delivers line clock at the begin and at the end of the line
        'right_border','uint',...                                   % for bidir scanning
        'info','char_40');                                          % not used

    BH_MeasureInfoExt_format=struct('DCU_in_use','uint',...% bits 0..3 = 1 when DCU module M1..M4 was in use, bits 4..8, 12..16, 18..22, 26..30- bit = 1, when connector 1..5 of module M1..M4 outputs were enabled
        'dcu_ser_no','char_64',...                      % serial number of used DCU modules, char[4][16]
        'scope_name','char_32',...                      % name of connected microscope
        'lens_name','char_64',...                       % name of lens used with connected microscope
        'SIS_in_use','uint',...                         % bits 0..3 = 1 when SIS module M1..M4 was in use, bits 4..5, 8..9, 12..13, 16..17- bit = 1, when switch A..B of module M1..M4 outputs were enabled,
        'sis_ser_no','char_64',...                      % serial number of used SIS modules, char[4][16]
        'gvd_ser_no','char_16',...                      % serial number of used GVD module,= 0 - GVD module was not used
        'zoom_factor','float',...                       % scanner zoom factor
        'FOV_at_zoom_1','float',...                     % scanner FOV at zoom = 1 , in  m
        'scope_connected','short',...                   % microscope mode = 0 - not connected, 1 - simulation w/o MTBAPI,2 - simulation,    3 - hardware,
        'lens_magnifier','float',...                    % lens magnifier
        'image_size','float',...                        % used image size, in  m  0 - not valid  = FOV_at_zoom_1 / zoom_factor / lens_magnifier, if values available and image_size_source = 0
        'tdc_offset','float_4',...                      % TDC offset for 4 inputs of TDC-104 module, float[4]
        'tdc_control','ulong',...                       % TDC control bits
        'scale_bar','uchar',...                         % image scale bar : bit 0 = 0 - off, 1 - on ( visible), bits 5-4 system type = 00 - not defined,
        'sbEnable1','char',...                          % 01 - GVD on motorized Axio,
        'sbEnable3','char',...                          % 10 - GVD on manual Axio - currently not available
        'sbSysType','char',...                          % 11 - LSM980, no GVD
        'reserve','char_1249');                         % keep always total size = 1536B extension of MeasureInfo for additional info

    BH_Measure_Info_format=struct('time','char_9',...   % time of creation
        'date','char_11',...                            % date of creation
        'mod_ser_no','char_16',...                      % serial number of the module
        'meas_mode','short',...
        'cfd_ll','float',...
        'cfd_lh','float',...
        'cfd_zc','float',...
        'cfd_hf','float',...
        'syn_zc','float',...
        'syn_fd','short',...
        'syn_hf','float',...
        'tac_r','float',...
        'tac_g','short',...
        'tac_of','float',...
        'tac_ll','float',...
        'tac_lh','float',...
        'adc_re','short',...
        'eal_de','short',...
        'ncx','short',...
        'ncy','short',...
        'page','ushort',...
        'col_t','float',...
        'rep_t','float',...
        'stopt','short',...
        'overfl','char',...
        'use_motor','short',...
        'steps','ushort',...
        'offset','float',...
        'dither','short',...
        'incr','short',...
        'mem_bank','short',...
        'mod_type','char_16',...                        % module type
        'syn_th','float',...
        'dead_time_comp','short',...
        'polarity_l','short',...                        % 2 = disabled line markers
        'polarity_f','short',...
        'polarity_p','short',...
        'linediv','short',...                           % line predivider = 2 ** ( linediv)
        'accumulate','short',...
        'flbck_y','int',...
        'flbck_x','int',...
        'bord_u','int',...
        'bord_l','int',...
        'pix_time','float',...
        'pix_clk','short',...
        'trigger','short',...
        'scan_x','int',...
        'scan_y','int',...
        'scan_rx','int',...
        'scan_ry','int',...
        'fifo_typ','short',...
        'epx_div','int',...
        'mod_type_code','ushort',...
        'mod_fpga_ver','ushort',...                     % new in v.8.4
        'overflow_corr_factor','float',...
        'adc_zoom','int',...
        'cycles','int',...                              % cycles ( accumulation cycles in FLOW mode )
        'StopInfo',BH_MeasStopInfo_format,...           % MeasStopInfo structure
        'FCSInfo',BH_MeasFCSInfo_format,...             % MeasFCSInfo structure valid only for FIFO meas
        'image_x','int',...                             % 4 subsequent fields valid only for Camera mode
        'image_y','int',...                             % or FIFO_IMAGE mode
        'image_rx','int',...
        'image_ry','int',...
        'xy_gain','short',...                           % gain for XY ADCs ( SPC930 )
        'master_clock','short',...                      % use or not  Master Clock (SPC140 multi-module )
        'adc_de','short',...                            % ADC sample delay ( SPC-930 )
        'det_type','short',...                          % detector type ( SPC-930 in camera mode )
        'x_axis','short',...                            % X axis representation ( SPC-930 )
        'HISTInfo',BH_MeasHISTInfo_format,...           % MeasHISTInfo structure
        'HISTInfoExt',BH_MeasHISTInfoExt_format,...
        'sync_delay','float',...                        % Sync Delay [ns] when using BH SyncDel USB box
        'sdel_ser_no','ushort',...                      % serial number of Sync Delay box,= 0 - SyncDelay box was not used
        'sdel_input','char',...                         % active input of SyncDelay box, 0 - IN 1, 1 - IN 2
        'mosaic_ctrl','char',...                        % bit 0 - mosaic imaging was used, bit 1 - mosaic type ( 000 - sequence of frames, 001 - rout. channels) bit 2-3 - mosaic restart type ( 0 - no, 1 - Marker 3, 2 - Ext. trigger, bit 4-5 - mosaic type extension(010 - sequence of Z planes of Axio Observer.Z1) 011 - sequence of frames with motor stage )
        'mosaic_x','uchar',...                          % no of mosaic elements in X dir.  (lower 8 bits )
        'mosaic_y','uchar',...                          % no of mosaic elements in Y dir.  (lower 8 bits )
        'frames_per_el','short',...                     % frames per mosaic element 1 .. 32767
        'chan_per_el','short',...                       % routing channels per mosaic element 1 .. 256
        'mosaic_cycles_done','int',...                  % number of mosaic accumulation cycles done
        'mla_ser_no','ushort',...                       % serial number of MLA4 device,  = 0 - MLA4 device was not used
        'DCC_in_use','uchar',...                        % bits 0..3 = 1 when DCC module M1..M4 was in use
        'dcc_ser_no','char_12',...                      % serial number of used DCC module
        'TiSaLas_status','ushort',...                   % laser status :bit 0 - used or not, b1 - present, b2 - on/off, b3 - shutter, b4 - warm up, b5 - pulsing,b6 - error, b7-10 - laser type 0-15, 0 = unknown
        'TiSaLas_wav','ushort',...                      % laser wavelength in nm
        'AOM_status','uchar',...                        % AOM status :bit 0 - used or not, b1 - present,b2 - modulation, b3 - remote, b4 - error
        'AOM_power','uchar',...                         % AOM power in %  0 - 100
        'ddg_ser_no','char_8',...                       % serial number of used DDG module, = 0 - DDG module was not used
        'prior_ser_no','int',...                        % serial number of used Prior device, 0 - not used
        'mosaic_x_hi','uchar',...                       % no of mosaic elements in X dir.  (higher 8 bits )
        'mosaic_y_hi','uchar',...                       % no of mosaic elements in Y dir.  (higher 8 bits )
        'reserve','char_11',...                         % total size of old MeasureInfo = 512 bytes
        'extension_used','char',...                     % MeasureInfoExt used
        'minfo_ext',BH_MeasureInfoExt_format);          % extension structure - size fixed to 1536 bytes, new total size of MeasureInfo = 2048 bytes

    Data_Info=struct('creation',{''},...
        'content',{''},...
        'format',{''},...
        'mod_factor',{''},...
        'compression',{''}); %in new version only

    %%
    %===========================================
    %===========================================
    %Read Becker-Hickl Binary Data from SPC-830
    %===========================================
    % initialise info structure
    info=struct('file_header',[],...
        'file_info',[],...
        'setup_info',[],...
        'measure_info',[],...
        'data_header',[],...
        'data_info',[]);

    % open file for reading
    [fid,message]=fopen(filename,'r');

    if fid>=3 % successfully opened
        %=================================
        %=======FILE INFORAMATION=========
        %=================================
        %--- Read File Header Section ---
        info.file_header = read_file_section_binary_info( fid, 0, BH_File_Header_format );
        % check file header is valid
        switch dec2hex(info.file_header.header_valid)
            case BH_HEADER_VALID
                fprintf('%s has a valid fileheader.\n',filename);
            case BH_HEADER_INVALID
                fprintf('%s has an INVALID FILE HEADER!\n',filename);
                return;
        end
        % check module identification
        buffer=bitshift(bitand(info.file_header.revision,BH_MODULE_MASK),-4);
        pos=cell2mat(BH_MODULE_ID(:,1))==buffer;
        info.file_header.hwmodule = BH_MODULE_ID{pos,2};
        info.file_header.software_rev = bitand(info.file_header.revision,BH_REVISION_MASK);

        if info.file_header.software_rev<15
            % old version
            BH_FileBlockHeadder_format=struct('block_no','short',...    % number of the block in the file valid only  when in 0 .. 0x7ffe range, otherwise use lblock_no field obsolete now, lblock_no contains full block no information
                'data_offs','long',...                                      % offset of the data block from the beginning of the file
                'next_block_offs','long',...                                % offset to the data block header of the next data block
                'block_type','ushort',...                                   % see block_type defines below
                'meas_desc_block_no','short',...                            % Number of the measurement description block corresponding to this data block
                'lblock_no','ulong',...                                     % long block_no - see remarks below
                'block_length','ulong');                                    % reserved2 now contains block( set ) length

        else
            % current version
            BH_FileBlockHeadder_format=struct('data_offs_ext','uchar',...   % extension of data_offs field - address bits 32-39
                'next_block_offs_ext','uchar',...                           % extension of next_block_offs field - address bits 32-39
                'data_offs','ulong',...                                     % offset of the block's data, bits 0-31
                'next_block_offs','ulong',...                               % offset to the data block header of the next data block, bits 0-31
                'block_type','ushort',...                                   % see block_type defines above
                'meas_desc_block_no','short',...
                'lblock_no','ulong',...                                     % long block_no - see remarks below
                'block_length','ulong');                                    % block( set ) length ( not compressed ) in bytes up to 2GB

        end

        %--- Read File Information ---
        info.file_info=read_file_section_ascii_info(fid,info.file_header.info_offs,info.file_header.info_length,'*IDENTIFICATION','*END',fieldnames(BH_File_Info_format));

        %--- Read Setup ---
        info.setup_info = read_bh_setup_info(fid, info.file_header.setup_offs, info.file_header.setup_length);


        %--- Read Measurement Description Block ---
        %read every measurement describtion block
        for n = 1:info.file_header.no_of_meas_desc_blocks
            if n>1 % not the first block
                info.measure_info(n) = info.measure_info(n-1);
                info.measure_info(n) = read_file_section_binary_info( fid, ftell(fid), BH_Measure_Info_format);
            end
            %first block
            info.measure_info = read_file_section_binary_info( fid, info.file_header.meas_desc_block_offs, BH_Measure_Info_format);
        end

        %--- Read Data Block ---
        for m=1:info.file_header.no_of_data_blocks
            if m>1
                info.data_header(m) = info.data_header(m-1);
                info.data_header(m) = read_file_section_binary_info( fid, ftell(fid) , BH_FileBlockHeadder_format);
            end
            % first block
            info.data_header = read_file_section_binary_info( fid, info.file_header.data_block_offs , BH_FileBlockHeadder_format);

            % main info
            % creation mode
            buffer=bitand(info.data_header(m).block_type,BH_BLOCK_CREATION_MASK);
            pos=find(cell2mat(BH_Block_Creation(:,1))==buffer);
            if isempty(pos)
                fprintf('%s\n','Unknown block creation mode!');
            else
                %fprintf('%s = %s\n','block creation mode=',Block_Creation{pos,2});
                info.data_info(m).creation=BH_Block_Creation{pos,2};
            end

            %content type, determins data type
            buffer=bitand(info.data_header(m).block_type,BH_BLOCK_CONTENT_MASK);
            pos=find(cell2mat(BH_Block_Content(:,1))==buffer);
            if isempty(pos)
                fprintf('%s\n','Unknown block content type!');
            else
                %fprintf('%s = %s\n','block content type',Block_Content{pos,2});
                info.data_info(m).content=BH_Block_Content{pos,2};
            end
            %format
            buffer=bitand(info.data_header(m).block_type,BH_BLOCK_DATA_TYPE_MASK);
            pos=find(cell2mat(BH_Block_Data_Type(:,1))==buffer);
            if isempty(pos)
                fprintf('%s\n','Unknown block content format!');
                info.data_info(m).format='ubit8';%1 byte standard
                info.data_info(m).mod_factor=1;
            else
                %fprintf('%s = %s\n','block data type',Block_Data_Type{pos,2});
                info.data_info(m).format=BH_Block_Data_Type{pos,2};
                info.data_info(m).mod_factor=BH_Block_Data_Type{pos,3};
            end
            %compression
            buffer=bitand(info.data_header(m).block_type,BH_BLOCK_DATA_COMPRESS_MASK);
            pos=find(cell2mat(BH_Block_Data_Compression(:,1))==buffer);
            if isempty(pos)
                fprintf('%s\n','Unknown block compression mode!');
            else
                %fprintf('%s = %s\n','block data compression',Block_Data_Compression{pos,2});
                info.data_info(m).compression=BH_Block_Data_Compression{pos,2};
            end

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
            for f_idx=1:numel(f_name)
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
                        stack_size=numel(raw)/(info.measure_info(m).adc_re*info.measure_info(m).image_x*info.measure_info(m).image_y);
                        size_check=mod(numel(raw),(info.measure_info(m).adc_re*info.measure_info(m).image_x*info.measure_info(m).image_y*info.measure_info(m).mosaic_x*info.measure_info(m).mosaic_y));
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
                            if size_check==0
                                if info.measure_info.mosaic_ctrl % mosaic images need convert mosaic to Z stack
                                    % reshape into adc_re x image_x x mosaic_x x image_y x mosaic_y dimension
                                    obj.data(obj.current_data).dataval=reshape(raw,info.measure_info(m).adc_re,info.measure_info(m).image_x,info.measure_info(m).mosaic_x,info.measure_info(m).image_y,info.measure_info(m).mosaic_y);
                                    % shift dim around and restack mosaic into a single z stack
                                    obj.data(obj.current_data).dataval=(reshape(permute(obj.data(obj.current_data).dataval,[1 2 4 3 5]),[info.measure_info(m).adc_re,info.measure_info(m).image_x,info.measure_info(m).image_y,stack_size,1]));
                                    obj.data(data_end_pos).datainfo.dZ=1;
                                    z_scale=obj.data(data_end_pos).datainfo.dZ*stack_size;
                                    obj.data(data_end_pos).datainfo.Z=linspace(1,z_scale,stack_size)';
                                else
                                    obj.data(obj.current_data).dataval=reshape(raw,info.measure_info(m).adc_re,info.measure_info(m).image_x,info.measure_info(m).image_y,stack_size,1);
                                end
                            else
                                fprintf('%s\n','raw data stack size incorrect, check settings');
                            end
                        end
                        obj.data(obj.current_data).datainfo.data_dim=[info.measure_info(m).adc_re,...
                            info.measure_info(m).image_x,...
                            info.measure_info(m).image_y,...
                            stack_size,1];
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
        errordlg(message,sprintf('Cannot Read data file %s',filename),'modal');
    end

catch exception
    message=sprintf('%s\n',exception.message);
end