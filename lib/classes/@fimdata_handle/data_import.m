function [ status, message ] = data_import( obj, varargin )
% import raw data into DATA_CONTAINER
% known formats: see class help
% take varargin in the format of [option_1,val_1,....,option_N,val_N]
% known options are pathname,filename,format

%% function complete
%==============Initialise===============
status=false;
options=[];

data_pathname=obj.path.import;%default to obj value
data_filename=[];%default empty filename

%error handle trial
try
    %=============Argument assignment=======
    if nargin>2
        options=varargin(1:2:end);
        arguments=varargin(2:2:end);
    end
    for argin_num=1:numel(options)
        switch options{argin_num}
            case 'pathname'
                data_pathname=arguments{argin_num};
            case 'filename'
                data_filename=arguments{argin_num};
            otherwise
                message=sprintf('unknown options! try to continue.\n');
                fprintf('%s\n',message);
        end
    end
    
    %==============================================================
    %---------Get filenames---------------
    %if filename not specified ask for it
    if isempty(data_filename)
        pause(0.001);
        %ask for files
        %one or more files from selection
        [filenames,data_pathname,~]=uigetfile({'*.*','All Files (*.*)';...
            '*.pic','Biorad pic file (*.pic)';...
            '*.oib','Olympus oic file (*.oib)';...
            '*.mes','Femtonic mes file (*.mes)';...
            '*.sdt','B&H uncompressed binary file (*.sdt)'; ...
            '*.spc','B&H spec file (*.spc)'; ...
            '*.ptu','Picoquant file (*.ptu)'; ...
            '*.tiff;*.TIF','Biorad exported image file (*.tiff,*.TIF)'; ...
            '*.aimg','ASCII image text file (*.aimg)';...
            '*.atrc','ASCII trace text file (*.atrc)';...
            '*.xls;*.xlsx','Excel file (*.xls,*.xlsx)';...
            '*.edf','exported data analysis file (*.edf)';...
            '*.daf','Old version data analysis file (*.daf)'},...
            'Select Raw Data File',...
            'MultiSelect','on',...
            data_pathname);
        
        if data_pathname~=0     %if files selected
            if ~iscell(filenames)
                %turn single file selection to cell type
                filenames=cellstr(filenames);
            end
        else
            %import action cancelled
            message=sprintf('File Import Action Cancelled\n');
            fprintf('%s\n',message);
            return;
        end
        %get filename and paths
        [~, data_filename, data_format] = cellfun(@(x)fileparts(x),filenames,'UniformOutput',false);
    else
        %single specified file
        [data_pathname, data_filename, data_format] = fileparts(data_filename);
        %turn single string into cell array of size 1
        data_filename=cellstr(data_filename);
        data_format=cellstr(data_format);
        %need to check format here between user input and auto?
    end
    %remove . in the data_format
    data_format=cellfun(@(x)x(2:end),data_format,'UniformOutput',false);
    
    %update import path
    obj.path.import=data_pathname;
    
    %total file number
    num_file=numel(data_filename);
    
    %----------Load files-----------------
    %set current data to template before proceed
    obj.data_select(1);
    %loop through files
    for file_counter=1:1:num_file
        %cat full filename
        filename=cat(2,data_pathname,data_filename{file_counter},'.',data_format{file_counter});
        %=============load data====================
        %load raw data according to file extensions
        %read files to get data and data informations
        switch data_format{file_counter}
            case 'pic'
                %Biorad PIC file format
                [ status, message ] = obj.load_biorad_pic_file(filename);
            case 'oib'
                %Olympus imaging file format
                [ status, message ] = obj.load_olympus_oib_file(filename);
            case 'mes'
                %Femtonic imaging file format
                [ status, message ] = obj.load_femtonic_mes_file(filename);
            case 'sdt'
                %B&H binary file format
                [ status, message ] = obj.load_bh_sdt_file(filename);
            case 'spc'
                %B&H spec file data
                [ status, message ] = obj.load_bh_spc_file(filename);
            case 'ptu'
                %picoquant binary
                %ask for storage format
                button = questdlg('Use spc to minimise memory usage','Storage Format','ndim','spc','ndim');
                switch button
                    case 'ndim'
                        [ status, message ] = obj.load_pq_ptu_file(filename);
                    case 'spc'
                        [ status, message ] = obj.load_pq_ptu_file_spc(filename);
                end
            case {'tiff','tif','TIF','TIFF'}
                %TIF image file format
                [ status, message ] = obj.load_tiff_file(filename);
            case {'xls','xlsx'}
                %Excel data file
                [ status, message ] = obj.load_excel_file(filename);
            case 'aimg'
                %exported ascii image file format
                [ status, message ] = obj.load_aimg_file(filename);
            case 'atrc'
                %exported ascii trace file format
                [ status, message ] = obj.load_atrc_file(filename);
            case 'edf'
                %exported fluorescent data analysis file
                [ status, message ] = obj.data_add(filename,filename,[]);
            case {'daf'}
                % saved older version of data analysis file
                [ status, message ] = obj.load_old_dataformat(filename);
            otherwise
                message=sprintf('file %s, format unknown\n',data_filename{file_counter});
        end
        %append messages
        message=sprintf('File# : %g processed.\nReturn Message : %s\n',file_counter, message);
    end
    %append messages
    message=sprintf('%s\n%g number of file processed from %s\n',message, num_file, data_pathname);
    
catch exception%error handle
    message=sprintf('%s\n',exception.message);
end
