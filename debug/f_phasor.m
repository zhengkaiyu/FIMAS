function [ result ] = f_phasor( data_handle, option, varargin )
%F_PHASOR Summary of this function goes here
%   Detailed explanation goes here
result=[];
parameters=struct('note','',...
    'operator','f_phasor',...
    't_duration',9,... %ns after peak
    'disp_lb',0.1,...
    'disp_ub',0.5,...
    'bg_threshold',10,...
    'FIR_func',[],...
    'method','simple');%simple or deconvole(need FIR)

switch option
    case 'add_data'
        current_data=data_handle.current_data;
        switch data_handle.data(current_data).datatype
            case {'3D_data_trace_image'}
                result=data_handle.data(current_data);
                result.dataname=cat(2,data_handle.data(current_data).dataname,'-',parameters.operator);
                
                result.datatype='2D_parameter_scatter';
                result.datainfo=setstructfields(data_handle.data(current_data).datainfo,parameters);%parameters field will replace duplicate field in data
                result.datainfo.note=data_handle.data(current_data).datainfo.note;
                result.dataval=[];
                result.datainfo.parent_data=data_handle.data(current_data).datainfo.data_idx;
                fprintf('%s\n','New container from f_NTC added');
            case {'1D_data_trace'}
                result=data_handle.data(current_data);
                result.dataname=cat(2,data_handle.data(current_data).dataname,'-',parameters.operator);
                
                result.datatype='0D_parameter_scatter';
                result.datainfo=setstructfields(data_handle.data(current_data).datainfo,parameters);%parameters field will replace duplicate field in data
                result.datainfo.note=data_handle.data(current_data).datainfo.note;
                result.dataval=[];
                result.datainfo.parent_data=data_handle.data(current_data).datainfo.data_idx;
                fprintf('%s\n','New container from f_NTC (normalised total count) added');
            otherwise
                fprintf('%s\n','unknown data type to process');
                result=[];
        end
    case 'modify_parameters'
        current_data=data_handle.current_data;
        %change parameters from this method only
        parameters=varargin{1:2:end};
        val=varargin{2:2:end};
        switch parameters
            case 'note'
                data_handle.data(current_data).datainfo.note=num2str(val);
                result=1;
            case 'operator'
                errordlg('Unauthorised to change parameter');
                result=0;
            case 't_duration'
                val=str2double(val);
                if val<=0;
                    fprintf('t_duration must be strictly > 0\n');
                else
                    data_handle.data(current_data).datainfo.t_duration=val;
                end
            case 'fit_t1'
                val=str2double(val);
                if val<=data_handle.data(current_data).datainfo.fit_t0;
                    fprintf('fit_t1 must be strictly > fit_t0\n');
                else
                    data_handle.data(current_data).datainfo.fit_t1=val;
                end
            case 'bg_threshold'
                val=str2double(val);
                data_handle.data(current_data).datainfo.bg_threshold=val;
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
                    case 'simple'
                        data_handle.data(current_data).datainfo.method='simple';
                        data_handle.data(current_data).datainfo.FIR_func=[];
                    otherwise
                        data_handle.data(current_data).datainfo.fit_method='simple';%default to tail fit
                end
        end
    case 'calculate_data'
        current_data=data_handle.current_data;
        parent_data=data_handle.data(current_data).datainfo.parent_data;
        data=data_handle.data(parent_data).dataval;
        switch data_handle.data(current_data).datatype
            case {'2D_parameter_scatter'}%originated from 3D traces_image
                px_lim=length(data_handle.data(current_data).datainfo.x);
                py_lim=length(data_handle.data(current_data).datainfo.y);
                xbin=data_handle.data(current_data).datainfo.bin_x;
                ybin=data_handle.data(current_data).datainfo.bin_y;
                p_total=(px_lim*py_lim);
                t=data_handle.data(current_data).datainfo.t;
                
                val=zeros(px_lim*py_lim,2);
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
                for p_idx=1:p_total
                    %xpos=mod(p_idx-1,py_lim)+1;ypos=ceil(p_idx/px_lim);
                    xpos=mod(p_idx-1,px_lim)+1;ypos=ceil(p_idx/px_lim);
                    xys=[ypos,xpos];
                    calc_idx=repmat([xys(2)-xbin:1:xys(2)+xbin],2*ybin+1,1)'+(repmat([xys(1)-ybin:1:xys(1)+ybin],2*xbin+1,1)-1)*px_lim;
                    calc_idx=calc_idx(:);
                    calc_idx(calc_idx<1)=[];
                    calc_idx(calc_idx>px_lim*py_lim)=[];
                    raw=sum(data(t_fit,calc_idx),2);
                    val(p_idx,:)=calculate_phasor(t(t_fit),raw,[],min_threshold,data_handle.data(current_data).datainfo.t_duration,FIR,t_FIR);
                end
                val=reshape(val,px_lim,py_lim,2);
                data_handle.update_data('dataval',val);
                result=1;
            case {'0D_parameter_scatter'}%originated from 1D traces
                min_threshold=data_handle.data(current_data).datainfo.bg_threshold;
                t=data_handle.data(current_data).datainfo.t;
                t_fit=(t>=0);
                
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
                
                val=calculate_phasor(t(t_fit),data_handle.data(parent_data).dataval(t_fit),[],min_threshold,data_handle.data(current_data).datainfo.t_duration,FIR,t_FIR);
                data_handle.update_data('dataval',val);
                fprintf('NTC = %g\n',val);
                result=1;
        end
    case 'calculate_roi_data'
        param=varargin{1:2:end};
        val=varargin{2:2:end};
        switch param
            case 'output'
                panel=val;
        end
        current_data=data_handle.current_data;
        current_roi=data_handle.data(current_data).current_roi;
        idx=cell2mat({data_handle.data(current_data).ROI(current_roi).idx}');
        data=data_handle.data(current_data).dataval;
        switch data_handle.data(current_data).datatype
            case {'3D_data_trace_image'}%reduce to 0D
                data=nansum(data(:,idx),2);
                t=data_handle.data(current_data).datainfo.t;
                % --- get parameters ---
                f_name=fieldnames(parameters);f_name=f_name(3:end);
                val=cellfun(@(x)num2str(parameters.(x)),f_name,'UniformOutput',false);
                %ask for new parameters value
                options.Resize='on';options.WindowStyle='modal';options.Interpreter='none';
                set(0,'DefaultUicontrolBackgroundColor',[0.7,0.7,0.7]);
                set(0,'DefaultUicontrolForegroundColor','k');
                answers=inputdlg(f_name,'Input parameters',1,val,options);
                set(0,'DefaultUicontrolBackgroundColor','k');
                set(0,'DefaultUicontrolForegroundColor','w');
                if ~isempty(answers)
                    answers=str2double(answers);
                    original=cell(length(answers),1);changes=cell(length(answers),1);
                    %reassign parameters
                    for m=1:length(answers)
                        original{m}=cat(2,'''',f_name{m},''',',num2str(parameters.(f_name{m})));
                        changes{m}=cat(2,'''',f_name{m},''',',num2str(answers(m)));
                        parameters.(f_name{m})=answers(m);
                    end
                    % --- end ---
                    t_fit=t(t>=parameters.fit_t0);
                    result=calculate_phasor(t(t_fit),data(t_fit),[],parameters.bg_threshold,parameters.fit_t1);
                    plot(panel.PANEL_HIST,result,current_data,'MarkerFaceColor',rand(3,1),'Marker','s','MarkerSize',5,'LineStyle','none','MarkerEdgeColor','y');
                    xlim(panel.PANEL_HIST,'auto');
                    ylim(panel.PANEL_HIST,'auto');
                    fprintf('NTC = %g\n',result);
                    rewrite_mfile(parameters.operator,original,changes);
                else
                    fprintf('NTC calculation cancelled\n');
                end
            case {'2D_parameter_map','2D_data_image'}%return mean value in map
                data=data(idx);
                result=squeeze(nanmean(data));
                plot(panel.PANEL_HIST,result,current_data,'MarkerFaceColor',rand(3,1),'Marker','s','MarkerSize',5,'LineStyle','none','MarkerEdgeColor','y');
                xlim(panel.PANEL_HIST,'auto');
                ylim(panel.PANEL_HIST,'auto');
                fprintf('Mean NTC = %g\n',result);
            case {'1D_data_trace'}
                
        end
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
                data=data./max_val;
                
                t_end=find(t<=t_duration,1,'last');
                t=t(1:t_end);
                data=data(1:t_end);
                t=t(:);
                data=data(:);
            end
            
            rep_rate=1/(t_duration);
            omega=2*pi*rep_rate;
            
            %calculate phasor
            I_tot=trapz(t,data,1);
            g1=trapz(t,data.*cos(omega*t),1)./I_tot;
            s1=trapz(t,data.*sin(omega*t),1)./I_tot;
            
            if ~isempty(FIR)
                %simple method
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