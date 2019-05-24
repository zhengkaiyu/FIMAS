function [ status, message ] = op_GatedInt( data_handle, option, varargin )
%op_gatedInt Gated intensity from FLIM traces or images
%--------------------------------------------------------------------------
%   1. gate2/gate1 values
%
%---Batch process----------------------------------------------------------
%   Parameter=struct('selected_data','1','bin_dim','[1,1,1,1,1]','gate1','[0.5,1.5]*1e-9','gate2','[5,12]*1e-9','normalise','total','parameter_space','gInt');
%   selected_data=data index, 1 means previous generated data
%   bin_dim=[1,1,1,1,1],spatial binning before calculation, default no binning
%   gate1=[0.5,1.5]*1e-9, 0.5ns to 1.5ns window (for OGB1)
%   gate2=[5,12]*1e-9, 5ns to 12ns window (for OGB1)
%   normalise=none|peak|total, normalise before gating ratio
%   parameter_space='gInt', name for generated parameters
%--------------------------------------------------------------------------
%   HEADER END
parameters=struct('note','',...
    'operator','op_GatedInt',...
    'parameter_space','gInt',...
    'bin_dim',[1,1,1,1,1],...
    'gate1',[0.5,1.5]*1e-9,...
    'gate2',[5,12]*1e-9,...
    'normalise','total');

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
                    op_GatedInt(data_handle, 'modify_parameters','data_index',data_idx,'paramarg',usrval{option_idx});
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
                    case {'DATA_IMAGE','DATA_TRACE','RESULT_IMAGE','RESULT_TRACE'}
                        % check data dimension, we only take tXY, tXT, tT, tXYZ,
                        % tXYZT
                        switch bin2dec(num2str(data_handle.data(current_data).datainfo.data_dim>1))
                            case {16,17,25,28,29,30,31}
                                % t (10000) / tT (10001) / tXT (11001) / tXY (11100) /
                                % tXYT (11101) / tXYZ (11110) / tXYZT (11111)
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
                                if isempty(data_handle.data(new_data).datainfo.bin_dim)
                                    data_handle.data(new_data).datainfo.bin_dim=[1,1,1,1,1];
                                end
                                % pass on metadata info
                                data_handle.data(new_data).metainfo=data_handle.data(parent_data).metainfo;
                                message=sprintf('%s\nData %s to %s added.',message,num2str(parent_data),num2str(new_data));
                                status=true;
                            otherwise
                                message=sprintf('%s\nonly take tXY, tXT, tT, tXYZ data type',message);
                                return;
                        end
                        % case {'DATA_SPC'}
                end
            end
        case 'modify_parameters'
            for current_data=data_idx
                %change parameters from this method only
                for pidx=1:1:numel(varargin)/2
                    parameters=varargin{2*pidx-1};
                    val=varargin{2*pidx};
                    switch parameters
                        case 'note'
                            data_handle.data(current_data).datainfo.note=num2str(val);
                            status=true;
                        case 'operator'
                            message=sprintf('%s\nUnauthorised to change %s.',message,parameters);
                            status=false;
                        case 'bin_dim'
                            [status,~]=data_handle.edit_datainfo(current_data,'bin_dim',val);
                        case 'gate1'
                            val=str2num(val);
                            if numel(val)~=2
                                message=sprintf('%s\ngate1 must have two elements.',message);
                                status=false;
                            else
                                data_handle.data(current_data).datainfo.gate1=val;
                                status=true;
                            end
                        case 'gate2'
                            val=str2num(val);
                            if numel(val)~=2
                                message=sprintf('%s\ngate2 must have two elements.',message);
                                status=false;
                            else
                                data_handle.data(current_data).datainfo.gate2=val;
                                status=true;
                            end
                        case 'normalise'
                            switch val
                                case {'peak','total','none'}
                                    data_handle.data(current_data).datainfo.normalise=val;
                                otherwise
                                    data_handle.data(current_data).datainfo.normalise='peak';
                            end
                            status=true;
                        case 'parameter_space'
                            data_handle.data(current_data).datainfo.parameter_space=num2str(val);
                            status=true;
                        otherwise
                            message=sprintf('%s\nUnauthorised to change %s.',message,parameters);
                            status=false;
                    end
                    if status
                        message=sprintf('%s\n%s has changed to %s.',message,parameters,val);
                    end
                end
            end
        case 'calculate_data'
            for current_data=data_idx
                % go through each selected data
                parent_data=data_handle.data(current_data).datainfo.parent_data_idx;
                switch data_handle.data(parent_data).datatype
                    case {'DATA_IMAGE','RESULT_IMAGE'}%originated from 3D/4D traces_image
                        % get pixel binnin information
                        pX_lim=numel(data_handle.data(parent_data).datainfo.X);
                        pY_lim=numel(data_handle.data(parent_data).datainfo.Y);
                        pZ_lim=numel(data_handle.data(parent_data).datainfo.Z);
                        pT_lim=numel(data_handle.data(parent_data).datainfo.T);
                        Xbin=data_handle.data(current_data).datainfo.bin_dim(2);
                        Ybin=data_handle.data(current_data).datainfo.bin_dim(3);
                        Zbin=data_handle.data(current_data).datainfo.bin_dim(4);
                        Tbin=data_handle.data(current_data).datainfo.bin_dim(5);
                        
                        % get dt dimension information
                        t=data_handle.data(parent_data).datainfo.t;
                        
                        if data_handle.data(current_data).datainfo.normalise
                            I=nansum(data_handle.data(parent_data).dataval(1:end,:),2);%get max position from total data
                            [~,max_idx]=max(I);% get max position
                        else
                            max_idx=[];
                        end
                        windowsize=[1,Xbin,Ybin,Zbin,Tbin];
                        % get gate range
                        if isempty(data_handle.data(current_data).datainfo.gate1)
                            t_gate1=[];
                        else
                            t_gate1=(t>=data_handle.data(current_data).datainfo.gate1(1))&(t<=data_handle.data(current_data).datainfo.gate1(2));
                        end
                        t_gate2=(t>=data_handle.data(current_data).datainfo.gate2(1))&(t<=data_handle.data(current_data).datainfo.gate2(2));
                        
                        fval=convn(data_handle.data(parent_data).dataval,ones(windowsize),'same');
                        fval=calculate_gateratio(fval,t_gate1,t_gate2,data_handle.data(current_data).datainfo.normalise,max_idx);
                        
                        data_handle.data(current_data).dataval=reshape(fval(1,:),[1,pX_lim,pY_lim,pZ_lim,pT_lim]);
                        data_handle.data(current_data).datainfo.data_dim=[1,pX_lim,pY_lim,pZ_lim,pT_lim];
                        data_handle.data(current_data).datatype=data_handle.get_datatype(current_data);
                        data_handle.data(current_data).datainfo.dt=0;
                        data_handle.data(current_data).datainfo.t=0;
                        data_handle.data(current_data).datainfo.last_change=datestr(now);
                        message=sprintf('%s\nData %s to %s %s calculated.',message,num2str(parent_data),num2str(current_data),parameters.operator);
                        status=true;
                    case {'DATA_TRACE','RESULT_TRACE'}
                        t=data_handle.data(parent_data).datainfo.t;
                        % get gate range
                        if isempty(data_handle.data(current_data).datainfo.gate1)
                            t_gate1=[];
                        else
                            t_gate1=(t>=data_handle.data(current_data).datainfo.gate1(1))&(t<=data_handle.data(current_data).datainfo.gate1(2));
                        end
                        t_gate2=(t>=data_handle.data(current_data).datainfo.gate2(1))&(t<=data_handle.data(current_data).datainfo.gate2(2));
                        if data_handle.data(current_data).datainfo.normalise
                            I=nansum(data_handle.data(parent_data).dataval(1:end,:),2);%get max position from total data
                            [~,max_idx]=max(I);% get max position
                        else
                            max_idx=[];
                        end
                        fval=calculate_gateratio(data_handle.data(parent_data).dataval,t_gate1,t_gate2,data_handle.data(current_data).datainfo.normalise,max_idx);
                        data_handle.data(current_data).dataval=fval;
                        data_handle.data(current_data).datainfo.data_dim=[1,1,1,1,1];
                        data_handle.data(current_data).datatype=data_handle.get_datatype(current_data);
                        data_handle.data(current_data).datainfo.dt=0;
                        data_handle.data(current_data).datainfo.t=0;
                        data_handle.data(current_data).datainfo.last_change=datestr(now);
                        message=sprintf('%s\nNTC = %g.',message,val);
                        message=sprintf('%s\nData %s to %s %s calculated.',message,num2str(parent_data),num2str(current_data),parameters.operator);
                        status=true;
                end
            end
    end
catch exception
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
    message=sprintf('%s\n%s',message,exception.message);
end

    function val=calculate_gateratio(data,gate1,gate2,normalise,maxidx)
        switch normalise
            case 'peak'
                normdata=data(maxidx,:,:,:,:);
                data=data./repmat(normdata,size(data,1),1,1,1,1);
            case 'total'
                normdata=nansum(data,1);
                data=data./repmat(normdata,size(data,1),1,1,1,1);
            case 'none'
                
        end
        %calculate area
        if isempty(gate1)
            val=nanmean(data(gate2,:,:,:,:),1);
        elseif isempty(gate2)
            val=nanmean(data(gate1,:,:,:,:),1);
        else
            val=nanmean(data(gate2,:,:,:,:),1)./nanmean(data(gate1,:,:,:,:),1);
        end
        val(isinf(val))=nan;
    end
end