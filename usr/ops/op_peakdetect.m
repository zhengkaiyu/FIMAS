function [ status, message ] = op_PeakDetect( data_handle, option, varargin )
%OP_PEAKDETECT Peak detection require version R2014 or later
%   Detailed explanation goes here
parameters=struct('note','',...
    'operator','op_PeakDetect',...
    'parameter_space','width|prominence',...
    'minpeakprominence',1,...%multiple of std
    'minpeakdist',100,...%ms
    'minpeakwidth',100,...%ms
    'widthref','halfprom',...
    'threshold',1e-4);%multiple of std

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
                    case {'DATA_IMAGE','RESULT_IMAGE','DATA_TRACE','RESULT_TRACE'}
                        % check data dimension, we only take CT, CXT, CXYT,
                        % CXYZT, where C=channel locates in t dimension
                        switch bin2dec(num2str(data_handle.data(current_data).datainfo.data_dim>1))
                            case {17,25,29,31,1,9,13,15}
                                % multi detector channels
                                % tT (10001) / tXT (11001) / tXYT (11101) / tXYZT (11111)
                                % single detector channel
                                % T (00001) / XT (01001) / XYT (01101) / XYZT (01111)
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
                                message=sprintf('%s%s added\n',message, data_handle.data(new_data).dataname);
                                status=true;
                            otherwise
                                message=sprintf('only take T, XT, XYT or XYZT data type\n');
                        end
                end
            end
            % ---------------------
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
                    case 'op_func'
                        val=num2str(val);
                        data_handle.data(current_data).datainfo.op_func=val;
                        data_handle.data(current_data).datainfo.parameter_space=regexp(val,'\w*(?=func)','match');
                        status=true;
                    case 'op_arg'
                        val=num2str(val);
                        data_handle.data(current_data).datainfo.op_arg=val;
                        status=true;
                    case 'widthref'
                        val=num2str(val);
                        switch val
                            case {'halfprom','halfheight'}
                                data_handle.data(current_data).datainfo.widthref=val;
                            otherwise
                                data_handle.data(current_data).datainfo.widthref='halfprom';
                        end
                    case 'parameter_space'
                        errordlg('Parameter space is width and prominence');
                    case {'minpeakdist','minpeakprominence','threshold','minpeakwidth'}
                        val=str2double(val);
                        data_handle.data(current_data).datainfo.(parameters)=val;
                        status=true;
                    otherwise
                        message=sprintf('%sUnauthorised to change %s\n',message,parameters);
                        status=false;
                end
                if status
                    message=sprintf('%s%s has changed to %s\n',message,parameters,val);
                end
            end
            % ---------------------
        case 'calculate_data'
            askforparam=true;
            for current_data=data_idx
                parent_data=data_handle.data(current_data).datainfo.parent_data_idx;
                switch data_handle.data(parent_data).datatype
                    case {'DATA_IMAGE','RESULT_IMAGE'}
                        % get pixel binnin information
                        pX_lim=numel(data_handle.data(parent_data).datainfo.X);
                        pY_lim=numel(data_handle.data(parent_data).datainfo.Y);
                        pZ_lim=numel(data_handle.data(parent_data).datainfo.Z);
                        pT_lim=numel(data_handle.data(parent_data).datainfo.T);
                        Xbin=data_handle.data(current_data).datainfo.bin_dim(2);
                        Ybin=data_handle.data(current_data).datainfo.bin_dim(3);
                        Zbin=data_handle.data(current_data).datainfo.bin_dim(4);
                        Tbin=data_handle.data(current_data).datainfo.bin_dim(5);
                        % binning
                        windowsize=[1,Xbin,Ybin,Zbin,Tbin];
                        fval=convn(data_handle.data(parent_data).dataval,ones(windowsize),'same');
                        datasize=data_handle.data(parent_data).datainfo.data_dim;
                        fval=reshape(fval,datasize(1),prod(datasize(2:4)),datasize(5));
                        p_total=pX_lim*pY_lim*pZ_lim;
                        temp=zeros(datasize(1),p_total,datasize(5));
                        
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
                        
                        minpdist=max(round(data_handle.data(current_data).datainfo.minpeakdist/data_handle.data(current_data).datainfo.dT),1);
                        minpp=data_handle.data(current_data).datainfo.minpeakprominence;
                        minpw=max(round(data_handle.data(current_data).datainfo.minpeakwidth/data_handle.data(current_data).datainfo.dT),1);
                        wref=data_handle.data(current_data).datainfo.widthref;
                        threshold=data_handle.data(current_data).datainfo.threshold;
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
                            
                            % calculation
                            raw=squeeze(fval(:,p_idx,:));
                            %{
                            %detrend
                            [p,s,mu] = polyfit((1:numel(raw))',raw,6);
                            f_y = polyval(p,(1:numel(raw))',[],mu);
                            raw=raw-f_y;
                            %}
                            bg=median(raw);
                            val=raw./bg-1;
                            noise=std(val(val<0));
                            %find peak
                            [~,locs,w,p] = findpeaks(val,...
                            'MinPeakProminence',minpp*noise,...
                            'MinPeakDistance',minpdist,...
                            'MinPeakWidth',minpw,...
                            'WidthReference',wref,...
                            'Threshold',threshold*noise);
                            pvalid=p>0;
                            locs=locs(pvalid);

                            temp(1,p_idx,locs)=(w(pvalid).*p(pvalid));
                        end
                        delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
                        data_handle.data(current_data).dataval=reshape(temp,[1,datasize(2),datasize(3),datasize(4),datasize(5)]);
                        
                        data_handle.data(current_data).datainfo.dt=0;
                        data_handle.data(current_data).datainfo.t=0;
                        data_handle.data(current_data).datainfo.T=data_handle.data(parent_data).datainfo.T;
                        data_handle.data(current_data).datainfo.data_dim=size(data_handle.data(current_data).dataval);
                        data_handle.data(current_data).datatype=data_handle.get_datatype(current_data);
                        
                        message=sprintf('%s%s calculated on %s\n',message,data_handle.data(current_data).datainfo.operator,data_handle.data(current_data).dataname);
                        status=true;
                    case {'DATA_TRACE','RESULT_TRACE'}
                        datasize=data_handle.data(parent_data).datainfo.data_dim;
                        raw=squeeze(data_handle.data(parent_data).dataval);
                        temp=zeros(1,datasize(5));
                        % calculation
                        minpdist=max(round(data_handle.data(current_data).datainfo.minpeakdist/data_handle.data(current_data).datainfo.dT),1);
                        minpp=data_handle.data(current_data).datainfo.minpeakprominence;
                        minpw=max(round(data_handle.data(current_data).datainfo.minpeakwidth/data_handle.data(current_data).datainfo.dT),1)/2;
                        wref=data_handle.data(current_data).datainfo.widthref;
                        threshold=data_handle.data(current_data).datainfo.threshold;
                        %detrend
                        %{
                        [p,s,mu] = polyfit((1:numel(raw))',raw,1);
                        f_y = polyval(p,(1:numel(raw))',[],mu);
                        val=raw-f_y;
                        %}
                        
                        bg=median(raw);
                        val=raw./bg-1;
                        noise=2*std(val(val<0));
                        %find peak
                        [~,locs,w,p] = findpeaks(val,...
                            'MinPeakProminence',minpp*noise,...
                            'MinPeakDistance',minpdist,...
                            'MinPeakWidth',minpw,...
                            'WidthReference',wref,...
                            'Threshold',threshold*noise);
                        pvalid=p>0;
                        locs=locs(pvalid);
                        temp(1,locs)=(w(pvalid).*p(pvalid));
                        %temp(2,locs)=p(pvalid);
                        %temp(1,locs)=1;
                        data_handle.data(current_data).dataval=reshape(temp,[1,1,1,1,datasize(5)]);
                        
                        data_handle.data(current_data).datainfo.dt=1;
                        data_handle.data(current_data).datainfo.t=0;
                        data_handle.data(current_data).datainfo.T=data_handle.data(parent_data).datainfo.T;
                        data_handle.data(current_data).datainfo.data_dim=size(data_handle.data(current_data).dataval);                        
                        data_handle.data(current_data).datatype=data_handle.get_datatype(current_data);
                        
                        message=sprintf('%s%s calculated on %s\n',message,data_handle.data(current_data).datainfo.operator,data_handle.data(current_data).dataname);
                        status=true;
                end
                
            end
            
            
            status=true;
        otherwise
            
    end
    
catch exception
    message=exception.message;
end

end