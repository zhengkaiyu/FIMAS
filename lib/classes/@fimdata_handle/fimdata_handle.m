classdef (ConstructOnLoad = true) fimdata_handle < handle
    % Fluorescent Imaging Microscopy data container
    %   Designed to import and hold various format of imaging data
    %   Version 1.2.2 supported formats:
    %   Biorad          PIC
    %   Olympus         OIB
    %   Becker & Hickl  SDT,SPC
    %   PicoQuant       PTU
    %   Femtonics       MES
    %   TIFF (single,stack)
    %   ASCII traces
    %   ASCII images
    %   EXCEL traces
    
    properties ( Constant = true )
        % Data dimension order
        % tXYZT (delay_time,x,y,z,global_time) or
        % CXYZT (channel,x,y,z,global_time) or
        % pXYZT (parameter,x,y,z,global_time)
        DIM_TAG = {'t','X','Y','Z','T'};
        
        % DATA_TYPE will help determine where to output data and data
        % calculation
        % 5 possible parameters:
        %   microscopic delay time (t) or or channel (C) or parameter space (p)
        %   image x axis (x)
        %   image y axis (y)
        %   image z axis (z)
        %   macroscopic time (T)
        %   TYPE_ID bit
        %   reserve|nD(0)/spc(1)|data(0)/param(1)|t|x|y|z|T
        %
        DATA_TYPE = {...
            'template',...          % template holder(panel number) x00
            'DATA_SPC',...          % single photon counting storage x61-x7F
            'DATA_IMAGE',...        % ndimensional data storage x23-x3F
            'DATA_TRACE',...        % 1dim data trace
            'DATA_POINT',...
            'RESULT_IMAGE',...
            'RESULT_TRACE',...
            'RESULT_POINT',...
            'RESULT_PHASOR',...
            'RESULT_PHASOR_MAP',...
            'RESULT_SCATTER',...
            'RESULT_HISTOGRAM',...
            'RESULT_VECTOR',...
            'RESULT_PARAMETER_MAP'};
        
        % DATA_METAINFO is a parameter structure for key rawdata metainfor
        % containing essential data information which must be filled
        % do not display vectors components t,x,y,T in tables
        % minimal information for all data
        % more parameters for generated data
        DATA_INFO = struct(...
            'data_idx',1,...            % data index in the container
            'parent_data_idx',[],...    % data index of parent data
            'child_data_idx',[],...     % derived child data index
            'operator',[],...           % function used for calculation
            'parameter_space',[],...    % parameter space names
            'parameter_idx',1,...       % current parameter index
            'panel',[],...              % main output panel parent name
            'note','',...               % notes to self
            'last_change',[],...        % last modification time
            'T_acquisition',[],...       % aquasition time
            'dt',0,...                  % delay time step
            'dX',0,...                  % x step
            'dY',0,...                  % y step
            'dZ',0,...                  % z step
            'dT',0,...                  % macroscopic time step
            'data_dim',[],...           % boolean data diminsion of [t/p,X,Y,Z,T]
            'bin_dim',[],...            % binning number in each diminsions
            'display_dim',[false,true,true,false,false],... % boolean display diminsion of [t/p,X,Y,Z,T]
            't_disp_bound',[0,12,128],...  % display bounds for t [lb,ub,levels]
            'X_disp_bound',[0,1,128],...   % display bounds for X [lb,ub,levels]
            'Y_disp_bound',[0,1,128],...   % display bounds for Y [lb,ub,levels]
            'Z_disp_bound',[0,1,128],...   % display bounds for Z [lb,ub,levels]
            'T_disp_bound',[0,1,128],...   % display bounds for T [lb,ub,levels]
            'optical_zoom',60,...       % optical zoom
            'digital_zoom',1,...        % digital zoom
            'mag_factor',3.417,...      % magnification factor 60X=3.4167 40X=7.675
            'scale_func','@(op_zoom,dig_zoom)(-0.2129*op_zoom+16.192)*op_zoom/dig_zoom/256',...
            't',0,...                  %t in ns (data) or pixel index (map)
            'X',0,...                  %X in microns
            'Y',0,...                  %Y in microns
            'Z',0,...                  %Z in microns
            'T',0);                    %T in millisec
        
        %ROI_STRUCT is the structure holder of ROI of data
        ROI_STRUCT = struct(...
            'name',{'ALL'},...      % name of ROI always has ALL
            'type',{'template'},... % type of ROI  template,impoint,impoly,imrect
            'panel',[],...          % output panel parent name
            'coord',{[]},...        % ROI point coordinate to reconstruct
            'idx',{[]},...          % pixel index inside
            'handle',[]);           % actual handle for the roi
    end
    
    properties ( SetAccess = public )
        % template data has index 1
        data;
        
        % current data index pointer
        current_data;
        
        % saved data path
        path=struct('import',pwd,...
            'export',pwd,...
            'saved',pwd,...
            'userop','./usr/ops');
        
        %temporary place holder for copy/paste roi
        roi_placeholder;
    end
    
    properties ( SetAccess = private )
        DATA_SIZE_LIMIT = (2^37)/8;   %=16GIGABYTE if data bigger than this we will ask for binning
    end
    
    events
        
    end
    %======================================
    %=============METHOD_SECTION===========
    %======================================
    methods ( Access = public )
        function obj = fimdata_handle( varargin )
            %constructor function
            if ispc
                %get system memory
                [~,val] = memory;
                %useful memory size = half of the available RAM size
                obj.DATA_SIZE_LIMIT = val.PhysicalMemory.Available/2;
            end
            %initialise one template data
            obj.data = struct(...
                'dataname','template',...       % default name template
                'metainfo',[],...               % file meta information specify during loading
                'datatype',obj.DATA_TYPE{1},... % assign during loading
                'datainfo',obj.DATA_INFO,...    % work out data info during loading
                'dataval',[],...                % actual data value matrix set during loading
                'current_roi',1,...             % default ROI index is 1 for ALL
                'roi',obj.ROI_STRUCT);
            
            obj.current_data=1;
            obj.roi_placeholder={[]};
        end
    end
    
    methods ( Access = public)
        % -------------------
        % data I/O related
        % -------------------
        % open saved binary data
        [ status, message ] = data_open( obj );
        % save data into binary format
        [ status, message ] = data_save( obj );
        % auto import multiple data files
        [ status, message ] = data_import( obj, varargin );
        %export selected data
        [ status, message ] = data_export( obj, data_idx, filename );
        %add new calculated data
        [ status, message ] = data_add( obj, name, val, selected );
        %remove imported data
        [ status, message ] = data_delete( obj, data_idx );
        %-----------
        
        %-----------
        %data info display and modify
        %-----------
        %select data to display
        [ status, message ] = data_select( obj, data_idx );
        
        [ status, message ] = display_metainfo( obj, data_idx, to_sort, output_handle ); %display aux info associated with data
        [ status, message ] = display_datainfo( obj, data_idx, output_handle ); %display data info needed for analysis
        [ status, message ] = edit_datainfo( obj, data_idx, fieldname, newval ); %input/edit data info if needed
        %-----------
        
        %-----------
        %data visual display related
        [ status, message ] = display_datamap(  obj, fig_handle, varargin );%display data into plots
        %-----------
        
        %-----------
        %data processing and analysing operators
        [ status, message, op_output ] = display_data_operator( obj, output_handle, data_index );
        %-----------
        
        %---------------------
        %ROI related functions
        %---------------------
        % add ROI to where_to,point/fh/redraw all
        [ status, message ] = roi_add( obj, type, position );
        % calculate display data in selected ROI
        [ data, status, message ] = roi_calc( obj, roi_idx, parameter );
        % what to do when select a roi selected ROI
        [ status, message ] = roi_select( obj, roi_idx );
        % display data in selected ROI
        [ status, message ] = roi_display( obj, parameter, data_handle, where_to );
        % remove selected ROI
        [ status, message ] = roi_delete( obj );
        % save data in selected ROI
        [ status, message ] = roi_save( obj );
        % transformdata in selected ROI into dataitem
        [ status, message ] = roi_transform( obj );
        %-----------
    end
    
    methods ( Access = private )
        %--------------
        %SPC file type
        %--------------
        
        %load bh sdt binary files (image/trace)
        [ status, message ] = load_bh_sdt_file( obj, filename );
        %load bh spc binary files (photon record)
        [ status, message ] = load_bh_spc_file( obj, filename, autoload);
        %load picoquant ptu binary files (photon record)
        [ status, message ] = load_pq_ptu_file( obj, filename);
        [ status, message ] = load_pq_ptu_file_spc( obj, filename );
        %load picoquant tttr mode pt* binary files (photon record)
        [ status, message ] = load_pq_pt2_file( obj, filename);
        [ status, message ] = load_pq_pt3_file( obj, filename);
        
        %--------------
        %LSM image file type
        %--------------
        
        %import biorad pic files
        [ status, message ] = load_biorad_pic_file( obj, filename);
        %import olympus oib files using bioformat
        [ status, message ] = load_olympus_oib_file( obj, filename);
        %import Femtonics mes files
        [ status, message ] = load_femtonic_mes_file( obj, filename);
        %import Femtonics mesc files
        [ status, message ] = load_femtonic_mesc_file( obj, filename);
        %--------------
        %auxilary file type
        %--------------
        
        %import exported tiff files
        [ status, message ] = load_tiff_file( obj, filename);
        %import exported excel tables
        [ status, message ] = load_excel_file( obj, filename);
        %import exported ascii files (image)
        [ status, message ] = load_aimg_file( obj, filename);
        %import exported ascii files (trace)
        [ status, message ] = load_atrc_file( obj, filename);
        %import exported csv ascii files from bruker localisation
        [ status, message ] = load_bruker_srf_file( obj, filename)
        % older version data file format
        [ status, message ] = load_old_dataformat( obj, filename );
        %------------
        
        %generate intensity corrected colourmap for fitted parameter data
        %from its parent data
        [ scaledmap_f ] = generate_colourmap( obj, axeshandle );
    end
    
    methods ( Access = public )
        %get the data type id from data dimension
        TypeID = get_datatype( obj, index );
        
        %get display data
        [ axis_label, display_axis ] = get_displaydata( obj, data_index, display_dim );
    end
end