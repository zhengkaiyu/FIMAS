function [ result, status, message ] = op_ExpFit( data_handle, option, varargin )
%OP_EXPFIT Summary of this function goes here
%   Detailed explanation goes here
%table contents must all have default values
parameters=struct('note','',...
    'operator','op_ExpFit',...
    'parameter_space','coeff|tau|res',...    %modify parameter space names
    'fit_method','tail_fit',...%tail fit|reconvolution
    'fit_t0',0.6e-9,...
    'fit_t1',10e-9,...
    'tau_vec',1,...
    'bg_threshold',10,...
    'FIR_func',[],...
    'MaxFunEvals',1e4,...
    'MaxIter',1e4,...
    'TolFun',1e-6);

status=false;result=[];message='';

try
    current_data=data_handle.current_data;
    switch option
        case 'add_data'
            switch data_handle.data(current_data).datatype
                case {'4D_txyT_image'}
                    result=data_handle.data(current_data);
                    result.current_roi=1;
                    result.roi=data_handle.data(1).roi;
                    
                    result.dataname=cat(2,parameters.operator,'_',data_handle.data(current_data).dataname);
                    result.metainfo=data_handle.data(current_data).metainfo;
                    result.datatype='4D_pxyT_mapstack';
                    result.datainfo=setstructfields(data_handle.data(current_data).datainfo,parameters);%parameters field will replace duplicate field in data
                    result.datainfo.note=data_handle.data(current_data).datainfo.note;
                    result.dataval=[];
                    result.datainfo.parent_data_idx=data_handle.data(current_data).datainfo.data_idx;
                    fprintf('%s\n','New container from f_NTC added');
                case '3D_txT_image'
                    result=data_handle.data(current_data);
                    result.current_roi=1;
                    result.roi=data_handle.data(1).roi;
                    
                    result.dataname=cat(2,parameters.operator,'_',data_handle.data(current_data).dataname);
                    
                    result.datatype='3D_pxT_map';
                    result.metainfo=data_handle.data(current_data).metainfo;
                    result.datainfo=setstructfields(data_handle.data(current_data).datainfo,parameters);%parameters field will replace duplicate field in data
                    result.datainfo.note=data_handle.data(current_data).datainfo.note;
                    result.dataval=[];
                    result.datainfo.parent_data_idx=data_handle.data(current_data).datainfo.data_idx;
                    fprintf('%s\n','New container from f_NTC added');
                case '3D_xyT_image'
                case {'3D_txy_image'}
                    result=data_handle.data(current_data);
                    result.current_roi=1;
                    result.roi=data_handle.data(1).roi;
                    
                    result.dataname=cat(2,parameters.operator,'_',data_handle.data(current_data).dataname);
                    
                    result.datatype='3D_pxy_map';
                    result.metainfo=data_handle.data(current_data).metainfo;
                    result.datainfo=setstructfields(data_handle.data(current_data).datainfo,parameters);%parameters field will replace duplicate field in data
                    result.datainfo.note=data_handle.data(current_data).datainfo.note;
                    result.dataval=[];
                    result.datainfo.parent_data_idx=data_handle.data(current_data).datainfo.data_idx;
                    fprintf('%s\n','New container from f_NTC added');
                case {'1D_t_trace'}
                    result=data_handle.data(current_data);
                    result.current_roi=1;
                    result.roi=data_handle.data(1).roi;
                    
                    result.dataname=cat(2,parameters.operator,'_',data_handle.data(current_data).dataname);
                    
                    result.datatype='0D_parameter_point';
                    result.datainfo=setstructfields(data_handle.data(current_data).datainfo,parameters);%parameters field will replace duplicate field in data
                    result.datainfo.note=data_handle.data(current_data).datainfo.note;
                    result.dataval=[];
                    result.datainfo.parent_data=data_handle.data(current_data).datainfo.data_idx;
                    fprintf('%s\n','New container from f_NTC (normalised total count) added');
                otherwise
                    fprintf('%s\n','unknown data type to process');
                    result=[];
            end
            status=true;
        case 'modify_parameters'
            %change parameters from this method only
            parameters=varargin{1:2:end};
            val=varargin{2:2:end};
            switch parameters
                case 'note'
                    data_handle.data(current_data).datainfo.note=num2str(val);
                    status=true;
                case 'operator'
                    errordlg('Unauthorised to change parameter');
                case 'fit_t0'
                    val=str2double(val);
                    if val>=data_handle.data(current_data).datainfo.fit_t1;
                        fprintf('fit_t0 must be strictly < fit_t1\n');
                    else
                        data_handle.data(current_data).datainfo.fit_t0=val;
                        status=true;
                    end
                case 'fit_t1'
                    val=str2double(val);
                    if val<=data_handle.data(current_data).datainfo.fit_t0;
                        fprintf('fit_t1 must be strictly > fit_t0\n');
                    else
                        data_handle.data(current_data).datainfo.fit_t1=val;
                        status=true;
                    end
                case 'bg_threshold'
                    val=str2double(val);
                    data_handle.data(current_data).datainfo.bg_threshold=val;
                    status=true;
                case 'parameter_space'
                    errordlg('Parameter is automatically calculated from tau_vec');
                case {'tau_vec'}
                    val=str2num(val); %#ok<ST2NM>
                    data_handle.data(current_data).datainfo.(parameters)=val;
                    data_handle.data(current_data).datainfo.parameter_space=[repmat({'coeff|tau'},1,numel(val)),'|res'];
                    status=true;
                case {'MaxFunEvals','MaxIter','TolFun'}
                    val=str2double(val);
                    data_handle.data(current_data).datainfo.(parameters)=val;
                    status=true;
                case 'fit_method'
                    answer = questdlg('Which method for fitting?','Exponential Fitting Method','tail_fit','reconvolution','tail_fit');
                    switch answer
                        case 'reconvolution'
                            data_handle.data(current_data).datainfo.fit_method=answer;
                            if isempty(data_handle.data(current_data).datainfo.FIR_func)
                                %get FIR function
                                [FileName,PathName,~]=uigetfile({'*.asc','ASCII file'},'Get FIR data file (ascii format)');
                                if ~isempty(PathName)
                                    data_handle.data(current_data).datainfo.FIR_func=load(cat(2,PathName,filesep,FileName),'-ascii');
                                    %change fitting method to use FIR
                                    data_handle.data(current_data).datainfo.fit_method='reconvolution';
                                end
                            end
                            status=true;
                        case 'tail_fit'
                            status=true;
                        otherwise
                            data_handle.data(current_data).datainfo.fit_method='tail_fit';%default to tail fit
                    end
                case 'FIR_func'
                    %get FIR file
                    [FileName,PathName,~]=uigetfile({'*.asc','ASCII file'},'Get FIR data file (ascii format)');
                    if ~isempty(PathName)
                        data_handle.data(current_data).datainfo.FIR_func=load(cat(2,PathName,filesep,FileName),'-ascii');
                        %change fitting method to use FIR
                        data_handle.data(current_data).datainfo.fit_method='reconvolution';
                        status=true;
                    end
            end
        case 'calculate_data'
            switch data_handle.data(current_data).datatype
                case {'4D_pxyT_mapstack','3D_pxy_map'}%originated from 3D/4D traces_image
                    %get parent data index
                    parent_data=data_handle.data(current_data).datainfo.parent_data_idx;
                    
                    %get data size and bin size
                    px_lim=numel(data_handle.data(parent_data).datainfo.x);
                    py_lim=numel(data_handle.data(parent_data).datainfo.y);
                    T_lim=size(data_handle.data(parent_data).dataval,4);
                    xbin=data_handle.data(current_data).datainfo.bin_dim(2);
                    ybin=data_handle.data(current_data).datainfo.bin_dim(3);
                    p_total=(px_lim*py_lim);
                    
                    %get fitting parameters
                    t=data_handle.data(parent_data).datainfo.t;
                    min_threshold=data_handle.data(current_data).datainfo.bg_threshold;
                    parameter=data_handle.data(current_data).datainfo.tau_vec;
                    parameter=1./parameter(:)';%reverse
                    MaxFunEvals=data_handle.data(current_data).datainfo.MaxFunEvals;
                    MaxIter=data_handle.data(current_data).datainfo.MaxIter;
                    TolFun=data_handle.data(current_data).datainfo.TolFun;
                    t0=find(t>=data_handle.data(current_data).datainfo.fit_t0,1,'first');
                    t1=find(t<=data_handle.data(current_data).datainfo.fit_t1,1,'last');
                    t=t(t0:t1);
                    m = numel(t);
                    n = numel(parameter);
                    
                    if strmatch(data_handle.data(current_data).datainfo.fit_method,'reconvolution','excat');
                        %get instrumental response
                        FIR=data_handle.data(current_data).datainfo.FIR_func;
                        [~,maxFIR_idx]=max(FIR(:));
                        %get data into t traces to find max
                        data=nansum(data_handle.data(parent_data).dataval(t0:t1,:),2);
                        [~,maxdata_idx]=max(data(:));
                        FIR=circshift(FIR,maxdata_idx-maxFIR_idx);%adjust for shift
                        %calculate FFT of FIR
                        fft_FIR=repmat(fft(FIR),1,length(parameter));
                    else
                        fft_FIR=[];
                    end
                    
                    waitbar_handle = waitbar(0,'Please wait...','Progress Bar','Calculating...',...
                        'CreateCancelBtn',...
                        'setappdata(gcbf,''canceling'',1)',...
                        'WindowStyle','normal',...
                        'Color',[0.2,0.2,0.2]);
                    setappdata(waitbar_handle,'canceling',0);
                    N_steps=size(data_handle.data(parent_data).dataval,4)*p_total;
                    %initialise values
                    estimates=nan(1,n);coeff=nan(1,n);
                    val=nan(n*2+1,px_lim,py_lim);%A(n)+tau(n)+residue
                    data_handle.data(current_data).dataval=nan(size(val,1),px_lim,py_lim,T_lim);
                    
                    for T_idx=1:T_lim
                        frame_data=squeeze(data_handle.data(parent_data).dataval(:,:,:,T_idx));
                        for p_idx=1:p_total
                            if getappdata(waitbar_handle,'canceling')
                                fprintf('NTC calculation cancelled\n');
                                delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
                                return;
                            end
                            % Report current estimate in the waitbar's message field
                            done=(p_total*(T_idx-1)+p_idx)/N_steps;
                            waitbar(done,waitbar_handle,sprintf('%3.1f%%',100*done));
                            
                            xpos=mod(p_idx-1,px_lim)+1;ypos=ceil(p_idx/px_lim);
                            xys=[ypos,xpos];
                            calc_idx=repmat([xys(2)-xbin:1:xys(2)+xbin],2*ybin+1,1)'+(repmat([xys(1)-ybin:1:xys(1)+ybin],2*xbin+1,1)-1)*px_lim;
                            calc_idx=calc_idx(:);
                            calc_idx(calc_idx<1)=[];
                            calc_idx(calc_idx>px_lim*py_lim)=[];
                            data=nansum(frame_data(t0:t1,calc_idx),2);
                            if  max(data(:))> min_threshold
                                [estimates,~,flag] = fminsearch(@chi2expfunc,parameter,...
                                    optimset('Display','off','MaxFunEvals',MaxFunEvals,...
                                    'MaxIter',MaxIter,'TolFun',TolFun),t,data);
                            else
                                flag=0;
                            end
                            if flag<=0
                                estimates=nan(size(estimates));
                                coeff=nan(size(coeff));
                            else
                                parameter=estimates;%update initial guess
                            end
                            residue=chi2expfunc(estimates,t,data);
                            val(:,p_idx) = [coeff',1./estimates,residue];
                        end
                        
                        data_handle.data(current_data).dataval(:,:,:,T_idx)=reshape(val,size(val,1),px_lim,py_lim);
                    end
                    delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
            end
            data_handle.data(current_data).datainfo.t=1:1:size(data_handle.data(current_data).dataval,1);
            status=true;
    end
catch exception
    message=exception.message;
end
end