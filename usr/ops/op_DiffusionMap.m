function [ result ] = op_DiffusionMap( data_handle, option, varargin )
%OP_DIFFUSIONMAP Summary of this function goes here
%   Detailed explanation goes here
result=[];
parameters=struct('note','',...
    'bin_dim',[1,5,5,1],...
    'operator','op_DiffusionMap',...
    'bg_threshold',10);

switch option
    case 'add_data'
        current_data=data_handle.current_data;
        switch data_handle.data(current_data).datatype
            case {'3D_xyT_image','3D_parameter_mapstack'}
                result=data_handle.data(current_data);
                result.current_roi=1;
                result.roi=data_handle.data(1).roi;
                
                result.dataname=cat(2,parameters.operator,'-',data_handle.data(current_data).dataname);
                
                result.datatype='3D_parameter_mapstack';
                result.datainfo=setstructfields(data_handle.data(current_data).datainfo,parameters);%parameters field will replace duplicate field in data
                result.datainfo.note=data_handle.data(current_data).datainfo.note;
                result.dataval=[];
                result.datainfo.parent_data=data_handle.data(current_data).datainfo.data_idx;
                fprintf('New container from %s added\n',parameters.operator);
            otherwise
                fprintf('unknown data type to process for %s\n',parameters.operator);
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
            case 'bg_threshold'
                val=str2double(val);
                data_handle.data(current_data).datainfo.bg_threshold=val;
        end
    case 'calculate_data'
        current_data=data_handle.current_data;
        parent_data=data_handle.data(current_data).datainfo.parent_data;
        data=data_handle.data(parent_data).dataval;
        switch data_handle.data(current_data).datatype
            case {'3D_xyT_image','3D_parameter_mapstack','3D_vector_mapstack'}%originated from 3D/4D traces_image
                T=data_handle.data(parent_data).datainfo.T;
                x=data_handle.data(parent_data).datainfo.x;
                y=data_handle.data(parent_data).datainfo.y;
                px_lim=numel(data_handle.data(parent_data).datainfo.x);
                py_lim=numel(data_handle.data(parent_data).datainfo.y);
                pT_lim=numel(data_handle.data(parent_data).datainfo.T);
                dx=data_handle.data(parent_data).datainfo.dx;
                dy=data_handle.data(parent_data).datainfo.dy;
                xbin=data_handle.data(current_data).datainfo.bin_dim(2);
                ybin=data_handle.data(current_data).datainfo.bin_dim(3);
                Tbin=data_handle.data(current_data).datainfo.bin_dim(4);
                newTlim=pT_lim;
                newxlim=px_lim;
                newylim=py_lim;
                
                data=squeeze(data);
                bg=(nanmean(data,3)<=data_handle.data(current_data).datainfo.bg_threshold);
                data=permute(data,[3,1,2]);data(:,bg)=nan;data=permute(data,[2,3,1]);
                
                newxlim=floor(px_lim/xbin);
                x=squeeze(mean(reshape(x(1:newxlim*xbin),[xbin,newxlim]),1));
                dx=x(2)-x(1);
                data=reshape(data(1:newxlim*xbin,:,:),[xbin,newxlim,py_lim,pT_lim]);
                data=squeeze(nanmean(data,1));
                newylim=floor(py_lim/ybin);
                y=squeeze(mean(reshape(y(1:newylim*ybin),[ybin,newylim]),1));
                dy=y(2)-y(1);
                data=reshape(data(:,1:newylim*ybin,:),[newxlim,ybin,newylim,pT_lim]);
                data=squeeze(nanmean(data,2));
                newTlim=floor(pT_lim/Tbin);
                T=squeeze(mean(reshape(T(1:newTlim*Tbin),[Tbin,newTlim]),1));
                dT=T(2)-T(1);
                data=reshape(data(:,:,1:newTlim*Tbin),[newxlim,newylim,Tbin,newTlim]);
                data=squeeze(nanmean(data,3));

                D=zeros(1,newxlim,newylim,newTlim);
                %min_threshold=data_handle.data(current_data).datainfo.bg_t
                %threshold;
                
                dcdT=diff(data,1,3);
                for T_idx=2:newTlim
                    %dc/dt=diff(data,1,4),d2c/dr2=del2(c)
                    D(1,:,:,T_idx)=dcdT(:,:,T_idx-1)./(4*del2(data(:,:,T_idx-1),dx,dy));                    
                end
                data_handle.data(current_data).dataval=D;
                data_handle.data(current_data).datainfo.x=x;
                data_handle.data(current_data).datainfo.y=y;
                data_handle.data(current_data).datainfo.T=T;
                
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
                    result=calculate_ntc(t(t_fit),data(t_fit),[],parameters.bg_threshold,parameters.fit_t1);
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