function [ status, message ] = op_Spiral2Polar( data_handle, option, varargin )
%OP_SPIRAL2POLAR Transform spiral scan to r-T or theta-T linescan profile
%--------------------------------------------------------------------------
%
%
%---Batch process----------------------------------------------------------
%   Parameter=struct('selected_data','1','polardim','theta','histbinsize','1','ref_dataindex','[]','opmode','mean');
%   selected_data=data index, 1 means previous generated data
%   polardim=r|theta, in which polar direction do we bin, we will collapse the other dimension
%   histbinsize=scalar of binning size >0
%   ref_scanline=data index which has the scanline info
%   opmode=sum|max|min|mean|median|nansum|nanmax|nanmin|nanmean|nanmedian
%--------------------------------------------------------------------------
%   HEADER END

%% function check

parameters=struct('note','',...
    'operator','op_Spiral2Polar',...
    'parameter_space','',...
    'polardim','theta',...
    'histbinsize',1,...
    'ref_dataindex',[],...
    'ref_scanline',[],...
    'opmode','mean');

% assume worst
status=false;
% for batch process must return 'Data parentidx to childidx *' for each
% successful calculation
message='';
askforparam=true;
try
    %default to current data
    data_idx=data_handle.current_data;
    % get optional input if exist
    if nargin>2
        % get parameters argument
        usroption=varargin(1:2:end);
        % get value argument
        usrval=varargin(2:2:end);
        % loop through to assign input values
        for option_idx=1:numel(usroption)
            switch usroption{option_idx}
                case {'data_index','selected_data'}
                    % specified data indices
                    data_idx=usrval{option_idx};
                case 'batch_param'
                    % batch processing need to modify parameters to user
                    % specfication
                    op_spiral2polar(data_handle, 'modify_parameters','data_index',data_idx,'paramarg',usrval{option_idx});
                case 'paramarg'
                    % batch processing passed on modified paramaters
                    varargin=usrval{option_idx};
                    % batch processing avoid any manual input
                    askforparam=false;
            end
        end
    end
    switch option
        case 'add_data'
            for current_data=data_idx
                switch data_handle.data(current_data).datatype
                    case {'DATA_IMAGE','RESULT_IMAGE'}
                        % check data dimension, we only take tXY, tXT, tT, tXYZ,
                        % tXYZT
                        switch bin2dec(num2str(data_handle.data(current_data).datainfo.data_dim>1))
                            case {9,25,24}
                                %XT (01001), tXT (11001), tX (11000)
                                parent_data=current_data;
                                % add new data
                                data_handle.data_add(sprintf('%s|%s',parameters.operator,data_handle.data(current_data).dataname),[],[]);
                                % get new data index
                                new_data=data_handle.current_data;
                                % copy over datainfo
                                data_handle.data(new_data).datainfo=data_handle.data(parent_data).datainfo;
                                % set data index
                                data_handle.data(new_data).datainfo.data_idx=new_data;
                                % set parent data index
                                data_handle.data(new_data).datainfo.parent_data_idx=parent_data;
                                % combine the parameter fields
                                data_handle.data(new_data).datainfo=setstructfields(data_handle.data(new_data).datainfo,parameters);%parameters field will replace duplicate field in data
                                data_handle.data(new_data).datainfo.parameter_space={''};
                                data_handle.data(new_data).datainfo.bin_dim=data_handle.data(parent_data).datainfo.bin_dim;
                                if isempty(data_handle.data(new_data).datainfo.bin_dim)
                                    data_handle.data(new_data).datainfo.bin_dim=[1,1,1,1,1];
                                end
                                % pass on metadata info
                                data_handle.data(new_data).metainfo=data_handle.data(parent_data).metainfo;
                                % pass on scan line if found
                                %data_handle.data(new_data).metainfo.info_Linfo.lines(data_handle.data(new_data).metainfo.info_Linfo.current)
                                message=sprintf('%s\nData %s to %s added.',message,num2str(parent_data),num2str(new_data));
                                status=true;
                            otherwise
                                message=sprintf('%sonly take XT or tXT data type',message);
                                return;
                        end
                        % case {'DATA_SPC'}
                        
                end
            end
            % ---------------------
        case 'modify_parameters'
            for current_data=data_idx
                %change parameters from this method only
                for pidx=1:1:numel(varargin)/2
                    parameters=varargin{2*pidx-1};
                    val=varargin{2*pidx};
                    switch parameters
                        case 'polardim'
                            switch val
                                case {'theta','r'}
                                    data_handle.data(current_data).datainfo.polardim=val;
                                otherwise
                                    data_handle.data(current_data).datainfo.polardim=theta;
                            end
                        case 'note'
                            data_handle.data(current_data).datainfo.note=num2str(val);
                            status=true;
                        case 'operator'
                            message=sprintf('%s\nUnauthorised to change %s.',message,parameters);
                            status=false;
                        case 'ref_dataindex'
                            status=false;
                            if askforparam
                                % ask for ref .mat file or ref data item
                                orig_ref=data_handle.data(current_data).datainfo.ref_scanline;
                                refdataindex=data_handle.data(current_data).datainfo.ref_dataindex;
                                % ask to select dataitem
                                [s,v]=listdlg('ListString',{data_handle.data.dataname},...
                                    'SelectionMode','single',...
                                    'Name','op_Spiral2Polar',...
                                    'PromptString','Select scanref data item',...
                                    'ListSize',[400,300],...
                                    'InitialValue',refdataindex);
                                if v
                                    % check if scanline field exist
                                    if isfield(data_handle.data(s).datainfo,'ScanLine')
                                        data_handle.data(current_data).datainfo.ref_dataindex=s;
                                        data_handle.data(current_data).datainfo.ref_scanline=data_handle.data(s).datainfo.ScanLine;
                                        message=sprintf('%s\nScanline information loaded from %s',message,data_handle.data(s).dataname);
                                    else
                                        errordlg('Selected dataitem has now ScanLine information','Check selection','modal');
                                    end
                                else
                                    % didn't change
                                    data_handle.data(current_data).datainfo.ref_scanline=orig_ref;
                                end
                            else
                                % auto batch mode
                                refdataindex=data_handle.data(current_data).datainfo.ref_dataindex;
                                data_handle.data(current_data).datainfo.ref_scanline=data_handle.data(refdataindex).datainfo.ScanLine;
                            end
                        case 'histbinsize'
                            data_handle.data(current_data).datainfo.histbinsize=str2double(val);
                        case 'opmode'
                            switch val
                                case {'mean','nanmean','sum','nansum','max','nanmax','min','nanmin','median','nanmedian'}
                                    % valid ones
                                    data_handle.data(current_data).datainfo.opmode=val;
                                otherwise
                                    % if invalid operation proposed default to sum
                                    data_handle.data(current_data).datainfo.opmode='mean';
                            end
                        otherwise
                            message=sprintf('%s\nUnauthorised to change %s.',message,parameters);
                            status=false;
                    end
                    if status
                        message=sprintf('%s\n%s has changed to %s.',message,parameters,val);
                    end
                end
            end
            % ---------------------
        case 'calculate_data'
            for current_data=data_idx
                % go through each selected data
                parent_data=data_handle.data(current_data).datainfo.parent_data_idx;
                rawdata=data_handle.data(parent_data).dataval;
            end
            status=true;
    end
catch exception
    % error handle
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
    message=sprintf('%s\n%s',message,exception.message);
end