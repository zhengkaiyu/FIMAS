classdef (ConstructOnLoad=true) DATA_CONTAINER < handle
    %DATA_CONTAINER holds both raw and calculated data
    %   raw data can be FLIM trace or images
    %   calculated data can be images or traces depending on user_op return
    %   user_op must specify parameters structure for calculation
    
    properties (Constant=true);
        %DATA_TYPE will help determine where to output data and data type
        %check for user_op
        DATA_TYPE={'3D_data_trace_image',...
            '2D_data_image',...
            '1D_data_trace',...
            '1D_parameter_trace',...
            '2D_parameter_map',...
            '1D_parameter_histogram',...
            '2D_parameter_scatter',...
            '0D_parameter_scatter',...
            '0D_parameter_point',...
            'template'};
        
        ROI_STRUCTURE=struct('name',{'ALL'},... %name of ROI
            'coord',{[]},...                        %roi handle
            'idx',{[]});                            %pixel index inside
        
        %parameter structure for rawdata
        RAWDATA_INFO=struct('t_scale',1,...    %t scaling factor
            'x_scale',1,...    %x scaling factor
            'y_scale',1,...    %y scaling factor
            'dt',[],...        %t step
            'dx',[],...        %x step
            'dy',[],...        %y step
            'op_zoom',60,...   %optical zoom
            'mag',3.417,...    %magnification factor 60X=3.4167 40X=7.675
            'dig_zoom',1,...  %digital zoom
            'scale_func','@(op_zoom,dig_zoom)(-0.2129*op_zoom+16.192)*op_zoom/dig_zoom/256',...
            't_aquasition',[],...%aquasition time
            'bin_x',5,...       %binning number in x
            'bin_y',5,...         %binning number in y
            'bin_t',0);         %binning number in t
        
        
        %do not display vectors components t,x,y
        %minimal information for all data
        %more parameters for generated data
        BASE_INFO=struct('disp_lb',0,...
            'disp_ub',1,...
            'disp_levels',128,...
            'note','this is template for raw data',...  %notes to self
            'data_idx',1,...
            'parent_data',[],...        %parent source data for calculation
            'operator',[],...        %function used for calculation
            't',[],...     %in ns
            'x',[],...     %in microns
            'y',[]);       %in microns
    end
    
    properties (SetAccess=public);
        data;               %array of data
        roi_placeholder={[]};    %temporary place holder for copy/paste roi
    end
    
    properties (SetAccess=private);
        current_data=1;     %currently selected data
    end
    %======================================================================
    %=============METHOD_SECTION===========================================
    %======================================================================
    methods (Access=public)
        function obj=DATA_CONTAINER(varargin)
            %constructor function
            
            %initialise one template data
            obj.data=struct('dataname','template',...   %default template
                'datatype','template',...   %guess during loading
                'auxinfo',[],...   %specify during loading
                'datainfo',[],...   %guess during loading
                'dataval',[],...      %set during loading
                'current_roi',1,...
                'ROI',obj.ROI_STRUCTURE);          %structure for ROI for this data
            
            %template raw data
            obj.data(1).datainfo=setstructfields(obj.RAWDATA_INFO,obj.BASE_INFO);
        end
    end
    
    methods ( Access = public )
        %-----------
        %data I/O related
        [ status, data_pathname ] = import_data(obj, varargin); %auto import multiple data files
        [ status ] = add_data(obj, name, val, replace);                  %add new calculated data
        [ status ] = remove_data( obj, idx );                   %remove imported data
        select_data(obj,data_idx,roi_list_handle,fileinfo_table_handle,parameter_table_handle,op_handle);  %select data
        update_data( obj, varargin );
        %-----------
        
        %-----------
        %data info display and modify
        display_auxinfo( obj, idx, output_to );                 %display aux info associated with data
        display_datainfo( obj, idx, output_to );                %display data info needed for analysis
        edit_datainfo( obj, data_idx, which_field, val );       %input/edit data info if needed
        %-----------
        
        %-----------
        %data visual display related
        display_datamap( obj, idx, output_to );        %display data into plots
        %-----------
        
        %-----------
        %ROI related functions
        add_roi( obj, where_to, type);          %add ROI to where_to,point/fh/redraw all
        remove_roi( obj );                      %remove selected ROI
        save_roi( obj );
        select_roi( obj, roi_idx, where_from, where_to, data_handle);
        %-----------
        display_roi( obj, parameter, data_handle, where_to, varargin );
        
    end
    
    methods ( Access = private )
        %-----------
        [status]=load_bh_sdt_file(obj,filename);    %load bh sdt binary files (image/trace)
        %-----------
        
        %need updating
        [status]=load_bh_spc_file(obj,filename);    %load bh spc binary files (trace)
        [status]=load_bh_asc_file(obj,filename);    %import bh exported ascii files (trace/image)
        [status] = load_pq_ptu_file(obj,filename);  %load picoquant ptu binary files (trace)
        [status]=load_biorad_pic_file(obj,filename);    %import biorad pic files
        [status]=load_biorad_tiff_file(obj,filename);   %import biorad exported tiff files
        %load picoquant
    end
end