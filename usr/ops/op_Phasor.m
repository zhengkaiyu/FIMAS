function [ status, message ] = op_Phasor( data_handle, option, varargin )
%OP_Phasor Does Phasor analysis map on t/T images/traces
%--------------------------------------------------------------------------
%
%---Batch process----------------------------------------------------------
%   Parameter=struct('selected_data','1','t_duration','9','disp_lb','0.53','disp_ub','3.85','fixed_comp','2.3','bg_threshold','10','parameter_space','Llow|Lmid|Lhigh');
%   selected_data=data index, 1 means previous generated data
%   t_duration=9, ns of interval for phasor analysis
%   disp_lb=0.63, ns (OGB1 femtonics) marker for lower tau point
%   disp_lb=3.85, ns (OGB1 femtonics) marker for upper tau point
%   fixed_comp=2.3, ns (iGlu) marker for fixed components tau point
%   bg_threshold=10,background tail photon count threshold
%   parameter_space='Llow|Lmid|Lhigh', name for generated parameters
%--------------------------------------------------------------------------
%   HEADER END

%table contents must all have default values
parameters=struct('note','',...
    'operator','op_Phasor',...
    't_duration',9,... %ns after peak
    'parameter_space','Llow|Lmid|Lhigh',...
    'disp_lb',0.53,...
    'disp_ub',3.85,...
    'fixed_comp',2.3,...
    'bg_threshold',10,...
    'FIR_func',[],...
    'method','simple');%simple or deconvole(need FIR)

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
                    op_Phasor(data_handle, 'modify_parameters','data_index',data_idx,'paramarg',usrval{option_idx});
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
                        % check data dimension, we only take CT, CXT, CXYT,
                        % CXYZT, where C=channel locates in t dimension
                        switch bin2dec(num2str(data_handle.data(current_data).datainfo.data_dim>1))
                            case {16,17,25,28,29,31}
                                % multi detector channels
                                % t (10000) / tT (10001) / tXT (11001) / tXY(11100) / tXYT (11101) / tXYZT (11111)
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
                                data_handle.data(new_data).datainfo.X_disp_bound=[0,1,64];
                                data_handle.data(new_data).datainfo.Y_disp_bound=[0,0.5,32];
                                % combine the parameter fields
                                data_handle.data(new_data).datainfo=setstructfields(data_handle.data(new_data).datainfo,parameters);%parameters field will replace duplicate field in data
                                data_handle.data(new_data).datainfo.bin_dim=data_handle.data(current_data).datainfo.bin_dim;
                                if isempty(data_handle.data(new_data).datainfo.bin_dim)
                                    data_handle.data(new_data).datainfo.bin_dim=[1,1,1,1,1];
                                end
                                data_handle.data(new_data).datainfo.t=[1,2];% only two parameters
                                data_handle.data(new_data).datainfo.data_dim(1)=2;
                                % pass on metadata info
                                data_handle.data(new_data).metainfo=data_handle.data(parent_data).metainfo;
                                message=sprintf('%s\nData %s to %s added.',message,num2str(parent_data),num2str(new_data));
                                status=true;
                            otherwise
                                message=sprintf('%s\nonly take XT or XYT data type.',message);
                                return;
                        end
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
                        case 'parameter_space'
                            data_handle.data(current_data).datainfo.parameter_space=val;
                            status=true;
                        case 't_duration'
                            val=str2double(val);
                            if val<=0;
                                message=sprintf('%s\nt_duration must be strictly > 0.',message);
                                status=false;
                            else
                                data_handle.data(current_data).datainfo.t_duration=val;
                                status=true;
                            end
                        case 'disp_lb'
                            val=str2double(val);
                            if val>=data_handle.data(current_data).datainfo.disp_ub;
                                message=sprintf('%s\ndisp_lb must be strictly < disp_ub.',message);
                                status=false;
                            else
                                data_handle.data(current_data).datainfo.disp_lb=val;
                                status=true;
                            end
                        case 'disp_ub'
                            val=str2double(val);
                            if val<=data_handle.data(current_data).datainfo.disp_lb;
                                message=sprintf('%s\ndisp_ub must be strictly > disp_lb.',message);
                                status=false;
                            else
                                data_handle.data(current_data).datainfo.disp_ub=val;
                                status=true;
                            end
                        case 'fixed_comp'
                            val=str2double(val);
                            data_handle.data(current_data).datainfo.fixed_comp=val;
                            status=true;
                        case 'bg_threshold'
                            val=str2double(val);
                            data_handle.data(current_data).datainfo.bg_threshold=val;
                            status=true;
                        case 'method'
                            answer = questdlg('Which method for fitting?','Exponential Fitting Method','simple','deconvolution','simple');
                            switch answer
                                case 'deconvolution'
                                    data_handle.data(current_data).datainfo.method=answer;
                                    if isempty(data_handle.data(current_data).datainfo.FIR_func)
                                        %get FIR function
                                        [FileName,PathName,~]=uigetfile({'*.asc','ASCII file'},'Get FIR data file (ascii format)');
                                        if ~isempty(PathName)
                                            temp=load(cat(2,PathName,filesep,FileName),'-ascii');
                                            if size(temp,1)<3
                                                data_handle.data(current_data).datainfo.FIR_func=temp';
                                            else
                                                data_handle.data(current_data).datainfo.FIR_func=temp;
                                            end
                                            %change fitting method to use FIR
                                            data_handle.data(current_data).datainfo.method='deconvolution';
                                        end
                                    end
                                    status=true;
                                case 'simple'
                                    data_handle.data(current_data).datainfo.method='simple';
                                    data_handle.data(current_data).datainfo.FIR_func=[];
                                    status=true;
                                otherwise
                                    data_handle.data(current_data).datainfo.fit_method='simple';%default to tail fit
                                    status=true;
                            end
                    end
                    if status
                        message=sprintf('%s\n%s has changed to %s.',message,parameters,val);
                    end
                end
            end
        case 'calculate_data'
            for current_data=data_idx
                parent_data=data_handle.data(current_data).datainfo.parent_data_idx;
                
                pX_lim=numel(data_handle.data(parent_data).datainfo.X);
                pY_lim=numel(data_handle.data(parent_data).datainfo.Y);
                pZ_lim=numel(data_handle.data(parent_data).datainfo.Z);
                pT_lim=numel(data_handle.data(parent_data).datainfo.T);
                Xbin=data_handle.data(current_data).datainfo.bin_dim(2);
                Ybin=data_handle.data(current_data).datainfo.bin_dim(3);
                Zbin=data_handle.data(current_data).datainfo.bin_dim(4);
                Tbin=data_handle.data(current_data).datainfo.bin_dim(5);
                p_total=(pX_lim*pY_lim*pZ_lim*pT_lim);
                t=data_handle.data(parent_data).datainfo.t;
                % binning
                windowsize=[1,Xbin,Ybin,Zbin,Tbin];
                data=data_handle.data(parent_data).dataval(:,:,:,:,:);
                data=convn(data,ones(windowsize),'same');
                
                datasize=[2,data_handle.data(parent_data).datainfo.data_dim(2:end)];
                val=zeros(2,pX_lim*pY_lim*pZ_lim*pT_lim);
                I=sum(data(1:end,:),2);
                [~,max_idx]=max(I);
                t_fit=(t>=0);
                min_threshold=data_handle.data(current_data).datainfo.bg_threshold;
                if strmatch(data_handle.data(current_data).datainfo.method,'simple','exact')
                    FIR=[];t_FIR=[];
                else
                    switch size(data_handle.data(current_data).datainfo.FIR_func,2)>1;
                        case 2
                            FIR=data_handle.data(current_data).datainfo.FIR_func(:,2);
                            t_FIR=data_handle.data(current_data).datainfo.FIR_func(:,1);
                        case 1
                            FIR=data_handle.data(current_data).datainfo.FIR_func(:,1);
                            t_FIR=linspace(0,max(t(t_fit)),numel(FIR))';
                        otherwise
                            FIR=[];
                            t_FIR=[];
                    end
                end
                
                %initialise waitbar
                waitbar_handle = waitbar(0,'Please wait...','Progress Bar','Calculating...',...
                    'Name',cat(2,'Calculating ',parameters.operator,' for ',data_handle.data(current_data).dataname),...
                    'CreateCancelBtn',...
                    'setappdata(gcbf,''canceling'',1)',...
                    'WindowStyle','normal',...
                    'Color',[0.2,0.2,0.2]);
                global SETTING; %#ok<TLEV>
                setappdata(waitbar_handle,'canceling',0);
                javaFrame = get(waitbar_handle,'JavaFrame');
                javaFrame.setFigureIcon(javax.swing.ImageIcon(cat(2,SETTING.rootpath.icon_path,'main_icon.png')));
                % get total calculation step
                N_steps=pT_lim*pZ_lim*pY_lim*pX_lim;barstep=0;frame_count=0;
                for T_idx=1:1:pT_lim
                    for Z_idx=1:1:pZ_lim
                        for Y_idx=1:1:pY_lim
                            for X_idx=1:1:pX_lim
                                calc_idx=(T_idx-1)*pZ_lim*pY_lim*pX_lim+(Z_idx-1)*pY_lim*pX_lim+(Y_idx-1)*pX_lim+X_idx;
                                val(1:2,calc_idx)=calculate_phasor(t(t_fit),data(t_fit,calc_idx),max_idx,min_threshold,data_handle.data(current_data).datainfo.t_duration*1e-9,FIR,t_FIR);
                                % waitbar
                                frame_count=frame_count+1;
                                done=frame_count/N_steps;
                                % Report current estimate in the waitbar's message field
                                if floor(100*done)>=barstep
                                    % update waitbar
                                    waitbar(done,waitbar_handle,sprintf('%g%%',barstep));
                                    barstep=barstep+1;
                                end
                                % check waitbar
                                if getappdata(waitbar_handle,'canceling')
                                    message=sprintf('%s\n%s calculation cancelled.',message,parameters.operator);
                                    delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
                                    return;
                                end
                            end
                        end
                    end
                end
                delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
                val=reshape(val,2,pX_lim,pY_lim,pZ_lim,pT_lim);
                data_handle.data(current_data).dataval=val;
                data_handle.data(current_data).datatype=data_handle.get_datatype;
                data_handle.data(current_data).datainfo.last_change=datestr(now);
                message=sprintf('%s\nData %s to %s %s calculated.',message,num2str(parent_data),num2str(current_data),parameters.operator);
                status=true;
            end
    end
catch exception
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
    message=sprintf('%s\n%s',message,exception.message);
end

    function val=calculate_phasor(t,data,max_idx,min_threshold,t_duration,FIR,t_FIR)
        if nanmax(data)>min_threshold
            data(isnan(data))=0;
            if isempty(FIR)
                %simple method
                if max_idx>0
                    %peak position provided
                    max_val=(mean(data(max_idx-2:max_idx+2)));
                else
                    %interpolate the data to get smoother trace for max search
                    endidx=ceil(length(t)/2);
                    xx=linspace(t(1),t(endidx),endidx);
                    l=ceil(length(xx)/64);
                    yy=spline(t(1:l:endidx),data(1:l:endidx),xx);
                    %find maximum
                    [max_val,max_idx]=max(yy);
                    max_idx=max_idx(1);
                    if (max_idx<(length(yy)-2))
                        if (max_idx>2)
                            max_val=(mean(data(max_idx-2:max_idx+2)));
                        else
                            max_val=(data(max_idx));
                        end
                    else
                        max_val=nan;
                    end
                end
                
                
                %normalise
                %data=data(max_idx:t_end);
                data=circshift(data,-max_idx);
                %data=data./max_val;
                t=circshift(t',-max_idx);
                t_end=find(t>=t_duration+t(1),1,'first');
                t=t(1:t_end);
                data=data(1:t_end);
                t=t(:)-t(1);
                data=data(:);
            end
            
            rep_rate=1/(t_duration);
            omega=2*pi*rep_rate;
            
            %calculate phasor
            I_tot=trapz(t,data,1);
            g1=trapz(t,data.*cos(omega*t),1)./I_tot;
            s1=trapz(t,data.*sin(omega*t),1)./I_tot;
            
            if ~isempty(FIR)
                %deconvolution method
                I_tot=trapz(t_FIR,FIR,1);
                g2=trapz(t_FIR,FIR.*cos(omega*t_FIR),1)./I_tot;
                s2=trapz(t_FIR,FIR.*sin(omega*t_FIR),1)./I_tot;
                
                f_I=(g1+1i*s1)/(g2+1i*s2);%need complex division
                g=real(f_I);
                s=imag(f_I);
            else
                g=g1;s=s1;
            end
            val=[g,s];
            %scatter(g,s,10,'MarkerEdgeColor','r');
            %pause(0.001);
        else
            val=[nan,nan];
        end
    end
end