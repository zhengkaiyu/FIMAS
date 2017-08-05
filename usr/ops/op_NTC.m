function [ status, message ] = op_NTC( data_handle, option, varargin )
%OP_NTC Calculate Normalised Total Count from traces or images
%

parameters=struct('note','',...
    'operator','op_NTC',...
    'parameter_space','',...
    'bin_dim',[1,1,1,1,1],...
    'fit_t0',3e-10,...
    'fit_t1',9e-9,... %ns after peak
    'bg_threshold',10,... %background threshold
    't_disp_bound',[0.05,0.5,64]);

status=false;message='';

try
    data_idx=data_handle.current_data;%default to current data
    % get optional input if exist
    if nargin>2
        % get parameters argument
        usroption=varargin(1:2:end);
        % get value argument
        usrval=varargin(2:2:end);
        % loop through to assign input values
        for option_idx=1:numel(usroption)
            switch usroption{option_idx}
                case 'data_index'
                    % specified data indices
                    data_idx=usrval{option_idx};
            end
        end
    end
    
    switch option
        case 'add_data'
            for current_data=data_idx
                switch data_handle.data(current_data).datatype
                    case {'DATA_IMAGE','DATA_TRACE'}
                        % check data dimension, we only take tXY, tXT, tT, tXYZ,
                        % tXYZT
                        switch bin2dec(num2str(data_handle.data(current_data).datainfo.data_dim>1))
                            case {16,17,25,28,29,30,31}
                                % t (10000) / tT (10001) / tXT (11001) / tXY (11100) /
                                % tXYT (11101) / tXYZ (11110) / tXYZT (11111)
                                parent_data=current_data;
                                % add new data
                                data_handle.data_add(cat(2,'op_NTC|',data_handle.data(current_data).dataname),[],[]);
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
                                data_handle.data(new_data).datainfo.parameter_space={'NTC'};
                                data_handle.data(new_data).datainfo.bin_dim=data_handle.data(parent_data).datainfo.bin_dim;
                                if isempty(data_handle.data(new_data).datainfo.bin_dim)
                                    data_handle.data(new_data).datainfo.bin_dim=[1,1,1,1,1];
                                end
                                % pass on metadata info
                                data_handle.data(new_data).metainfo=data_handle.data(parent_data).metainfo;
                                message=sprintf('%s added\n',data_handle.data(new_data).dataname);
                                status=true;
                            otherwise
                                message=sprintf('only take XT or XYT data type\n');
                                return;
                        end
                        % case {'DATA_SPC'}
                        
                end
            end
        case 'modify_parameters'
            current_data=data_handle.current_data;
            %change parameters from this method only
            for pidx=numel(varargin)/2
                parameters=varargin{2*pidx-1};
                val=varargin{2*pidx};
                switch parameters
                    case 'note'
                        data_handle.data(current_data).datainfo.note=num2str(val);
                        status=true;
                    case 'operator'
                        message=sprintf('%sUnauthorised to change %s\n',message,parameters);
                        status=false;
                    case 'fit_t0'
                        val=str2double(val);
                        if val>=data_handle.data(current_data).datainfo.fit_t1;
                            message=sprintf('%sfit_t0 must be strictly < fit_t1\n',message);
                            status=false;
                        else
                            data_handle.data(current_data).datainfo.fit_t0=val;
                            status=true;
                        end
                        
                    case 'fit_t1'
                        val=str2double(val);
                        if val<=data_handle.data(current_data).datainfo.fit_t0;
                            message=sprintf('%sfit_t1 must be strictly > fit_t0\n',message);
                            status=false;
                        else
                            data_handle.data(current_data).datainfo.fit_t1=val;
                            status=true;
                        end
                    case 'bg_threshold'
                        val=str2double(val);
                        data_handle.data(current_data).datainfo.bg_threshold=val;
                        status=true;
                    case 'parameter_space'
                        data_handle.data(current_data).datainfo.parameter_space=val;
                        status=true;
                    otherwise
                        message=sprintf('%sUnauthorised to change %s\n',message,parameters);
                        status=false;
                end
                if status
                    message=sprintf('%s%s has changed to %s\n',message,parameters,val);
                end
            end
        case 'calculate_data'
            for current_data=data_idx
                % go through each selected data
                parent_data=data_handle.data(current_data).datainfo.parent_data_idx;
                switch data_handle.data(parent_data).datatype
                    case {'DATA_IMAGE'}%originated from 3D/4D traces_image
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
                        
                        %initialise data size
                        p_total=pX_lim*pY_lim*pZ_lim*pT_lim;
                        
                        % get fit range
                        t_fit=(t>=data_handle.data(current_data).datainfo.fit_t0);
                        I=nansum(data_handle.data(parent_data).dataval(t_fit,:),2);%get max position from total data
                        [~,max_idx]=max(I);% get max position
                        t_duration=data_handle.data(current_data).datainfo.fit_t1;
                        t=t(t_fit);
                        t_tail=find(t<=(t(max_idx)+t_duration),1,'last');
                        
                        % get min_threshold
                        min_threshold=data_handle.data(current_data).datainfo.bg_threshold;
                        
                        %initialise waitbar
                        waitbar_handle = waitbar(0,'Please wait...','Progress Bar','Calculating...',...
                            'Name',cat(2,'Calculating ',parameters.operator,' for ',data_handle.data(current_data).dataname),...
                            'CreateCancelBtn',...
                            'setappdata(gcbf,''canceling'',1)',...
                            'WindowStyle','normal',...
                            'Color',[0.2,0.2,0.2]);
                        global SETTING; %#ok<TLEV>
                        javaFrame = get(waitbar_handle,'JavaFrame');
                        javaFrame.setFigureIcon(javax.swing.ImageIcon(cat(2,SETTING.rootpath.icon_path,'main_icon.png')));
                        setappdata(waitbar_handle,'canceling',0);
                        % get total calculation step
                        N_steps=p_total;barstep=0;
                        windowsize=[1,Xbin,Ybin,Zbin,Tbin];
                        
                        fval=convn(data_handle.data(parent_data).dataval,ones(windowsize),'same');
                        for p_idx=1:p_total
                            % check waitbar
                            if getappdata(waitbar_handle,'canceling')
                                message=sprintf('NTC calculation cancelled\n');
                                delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
                                return;
                            end
                            % Report current estimate in the waitbar's message field
                            done=p_idx/N_steps;
                            if floor(100*done)>=barstep
                                % update waitbar
                                waitbar(done,waitbar_handle,sprintf('%g%%',barstep));
                                barstep=barstep+1;
                            end
                            raw=nansum(fval(t_fit,p_idx),2);
                            if (max_idx<(length(t_fit)-2))
                                %max_val=mean(raw(max_idx-1:max_idx+1));
                                max_val=raw(max_idx);
                            else
                                max_val=nan;
                            end
                            
                            if max_val>min_threshold
                                raw=raw./max_val;
                                fval(1,p_idx)=nanmean(raw(max_idx:t_tail),1);
                            else
                                fval(1,p_idx)=nan;
                            end
                        end
                        data_handle.data(current_data).dataval=reshape(fval(1,:),[1,pX_lim,pY_lim,pZ_lim,pT_lim]);
                        data_handle.data(current_data).datainfo.data_dim=[1,pX_lim,pY_lim,pZ_lim,pT_lim];
                        data_handle.data(current_data).datatype=data_handle.get_datatype(current_data);
                        data_handle.data(current_data).datainfo.dt=0;
                        data_handle.data(current_data).datainfo.t=0;
                        delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
                        data_handle.data(current_data).datainfo.last_change=datestr(now);
                        status=true;
                    case {'DATA_TRACE'}
                        min_threshold=data_handle.data(current_data).datainfo.bg_threshold;
                        % get dt dimension information
                        t=data_handle.data(parent_data).datainfo.t;
                        t_fit=(t>=data_handle.data(current_data).datainfo.fit_t0);
                        val=calculate_ntc(t(t_fit),data_handle.data(parent_data).dataval(t_fit),[],min_threshold,data_handle.data(current_data).datainfo.fit_t1);
                        data_handle.data(current_data).datainfo.dt=0;
                        data_handle.data(current_data).datainfo.t=0;
                        data_handle.data(current_data).dataval=val;
                        data_handle.data(current_data).datainfo.data_dim=[1,1,1,1,1];
                        data_handle.data(current_data).datatype=data_handle.get_datatype(current_data);
                        data_handle.data(current_data).datainfo.last_change=datestr(now);
                        message=sprintf('NTC = %g\n',val);
                        status=1;
                end
            end
    end
catch exception
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
    message=exception.message;
end

    function val=calculate_ntc(t,data,max_idx,min_threshold,t_duration)
        if nanmax(data)>min_threshold
            data(isnan(data))=0;
            if max_idx>0
                %peak position provided
                max_val=(data(max_idx));
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
                    %max_val=mean(data(max_idx-1:max_idx+1));
                    max_val=data(max_idx);
                else
                    max_val=nan;
                end
            end
            t_end=find(t<=(t(max_idx)+t_duration),1,'last');
            
            %normalise
            data=data./max_val;
            %calculate area
            val=nanmean(data(max_idx:t_end),1);
            %plot(t,data);
        else
            val=nan;
        end
    end
end