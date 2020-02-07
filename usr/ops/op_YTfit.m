function [ status, message ] = op_YTfit( data_handle, option, varargin )
% op_YTfit peak calcium value estimate using more accurate FLIM calcium
%       baseline estimate and dF/F0 calium transient traces
% reference: Yulia's programme
%   Input: Ca0 = uM, resting calcium value
%          kon_I = 1/(uM ms), kon rate of calcium indicator
%          koff_I = 1/ms, koff rate of calcium indicator
%          gamma = dynamic range of the dye
%          Frest = resting fluorescence signal
%          peak_bin = ms, time binning for averaging peak values
%          AP_shift = ms, delay time after electrophysiology AP arrival
%          tAP1 = ms, onset of the first action potential
%          frequency = Hz, stimulus frequency for multiple stimulus
%          nAP = number of action potentials
%          base_bin = ms,
%          base_shift = ms,
%          fitmode=mean/max, calculation using max or mean for base/peak
%   Calculated Variables:
%          delTime = 1/frequency*1e3; % ms
%          Kd_I = koff_I/kon_I
%          Fmax = Frest*(Ca0+Kd_I)/(Ca0+Kd_I/gamma)
%   Optional Input:
%          electrophys_ref, electrophysiology trace dataitem which could be
%          used to establish some Input values automatically
%   Output:
%          Fmax
%          Fpeak,   mean F value over the peak_bin period
%          dF_Fbase
%          dF_Fmax
%          Capeak
%          dCa_free
%          Facilitation (multiple AP only)

parameters=struct('note','',...
    'operator','op_YTfit',...
    'parameter_space','Fpeak|taurise|Fbase|dF_Fbase|dF_Fmax|Capeak|dCa_free|Facilitation',... %
    'bin_dim',[1,1,1,1,1],...
    'Ca0',0.02,...   %uM resting Calcium value
    'kon_I',0.6,... %1/(uM ms) kon rate for calcium indicator
    'koff_I',0.144,... %1/ms koff rate for calcium indicator
    'gamma',6,...    % dynamic range of the dye
    'Frest',1,... %
    'peak_bin',10,... %ms, time binning for averaging peak values
    'AP_shift',4,... %ms, time after AP, start of bin (delay from onset of electrophysiology AP)
    'tAP1',500,... %ms, time of the first AP in electrophysiology
    'frequency',20,... %Hz stimulus frequency, use zero for single stimulus
    'nAP',4,... %number of action potentials
    'base_bin',6,...   %ms
    'base_shift',-4,... %ms before AP
    'fitmode','mean',...%mean or max for find peak and base values
    'delTime',[],...
    'Kd_I',[],...
    'Fmax',[],...
    'electrophys_ref',[]);  %electrophysiology reference channel from other dataitem

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
                    case {'DATA_IMAGE','DATA_TRACE','RESULT_IMAGE','RESULT_TRACE'}
                        % check data dimension, we only take tXY, tXT, tT, tXYZ,
                        % tXYZT
                        switch bin2dec(num2str(data_handle.data(current_data).datainfo.data_dim>1))
                            case {1,16,17,25,28,29,30,31}
                                % T (00001) / t (10000) / tT (10001) / tXT (11001) / tXY (11100) /
                                % tXYT (11101) / tXYZ (11110) / tXYZT (11111)
                                parent_data=current_data;
                                % add new data
                                data_handle.data_add(cat(2,'op_YTfit|',data_handle.data(current_data).dataname),[],[]);
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
                                data_handle.data(new_data).datainfo.dt=1;
                                %data_handle.data(new_data).datainfo.t=1:1:parameters.max_component;% only two parameters
                                %data_handle.data(new_data).datainfo.data_dim(1)=parameters.max_component;
                                data_handle.data(new_data).datainfo.delTime=1/data_handle.data(new_data).datainfo.frequency*1e3; % ms
                                data_handle.data(new_data).datainfo.Kd_I=data_handle.data(new_data).datainfo.koff_I/data_handle.data(new_data).datainfo.kon_I;
                                data_handle.data(new_data).datainfo.Fmax=data_handle.data(new_data).datainfo.Frest*(data_handle.data(new_data).datainfo.Ca0+data_handle.data(new_data).datainfo.Kd_I)/(data_handle.data(new_data).datainfo.Ca0+data_handle.data(new_data).datainfo.Kd_I/data_handle.data(new_data).datainfo.gamma); % computing Fmax
                                % pass on metadata info
                                data_handle.data(new_data).metainfo=data_handle.data(parent_data).metainfo;
                                message=sprintf('%s added\n',data_handle.data(new_data).dataname);
                                status=true;
                            otherwise
                                message=sprintf('only take tXY, tXT, tT, tXYZ data type\n');
                                return;
                        end
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
                    case {'operator','parameter_space'}
                        message=sprintf('%sUnauthorised to change %s\n',message,parameters);
                        status=false;
                    case {'peak_bin','base_bin'}
                        val=str2double(val);
                        if val<=0
                            message=sprintf('%s%s must be a positive value\n',message,parameters);
                            status=false;
                        else
                            data_handle.data(current_data).datainfo.(parameters)=val;
                            status=true;
                        end
                    case {'AP_shift','tAP1','base_shift'}
                        val=str2double(val);
                        data_handle.data(current_data).datainfo.(parameters)=val;
                        status=true;
                    case {'Ca0','gamma','Frest'}%non negative
                        val=str2double(val);
                        if val<=0
                            message=sprintf('%sCa0 must be a positive value\n',message);
                            status=false;
                        else
                            data_handle.data(current_data).datainfo.(parameters)=val;
                            data_handle.data(current_data).datainfo.Fmax=data_handle.data(current_data).datainfo.Frest*(data_handle.data(current_data).datainfo.Ca0+data_handle.data(current_data).datainfo.Kd_I)/(data_handle.data(current_data).datainfo.Ca0+data_handle.data(current_data).datainfo.Kd_I/data_handle.data(current_data).datainfo.gamma); % computing Fmax
                            status=true;
                        end
                    case {'kon_I','koff_I'}
                        val=str2double(val);
                        if val<=0
                            message=sprintf('%s%s must be a positive value\n',message,parameters);
                            status=false;
                        else
                            data_handle.data(current_data).datainfo.(parameters)=val;
                            data_handle.data(current_data).datainfo.Kd_I=data_handle.data(current_data).datainfo.koff_I/data_handle.data(current_data).datainfo.kon_I;
                            data_handle.data(current_data).datainfo.Fmax=data_handle.data(current_data).datainfo.Frest*(data_handle.data(current_data).datainfo.Ca0+data_handle.data(current_data).datainfo.Kd_I)/(data_handle.data(current_data).datainfo.Ca0+data_handle.data(current_data).datainfo.Kd_I/data_handle.data(current_data).datainfo.gamma); % computing Fmax
                            status=true;
                        end
                    case 'frequency'
                        val=str2double(val);
                        if val<=0
                            message=sprintf('%s%s must be a positive value\n',message,parameters);
                            status=false;
                        else
                            data_handle.data(current_data).datainfo.(parameters)=val;
                            data_handle.data(current_data).datainfo.delTime=1/data_handle.data(current_data).datainfo.frequency*1e3; % ms
                        end
                    case 'nAP'%non negative integer
                        val=max(1,round(str2double(val)));%minimum 1AP and integer values only
                        data_handle.data(current_data).datainfo.nAP=val;
                    case 'fitmode'
                        switch val
                            case {'mean','max'}
                                data_handle.data(current_data).datainfo.fitmode=val;
                            otherwise
                                % default to mean
                                data_handle.data(current_data).datainfo.fitmode='mean';
                        end
                        status=true;
                    case 'electrophys_ref'
                        status=false;
                        % ask for ref .mat file or ref data item
                        orig_ref= data_handle.data(current_data).datainfo.electrophys_ref;
                        % ask to select dataitem
                        [s,v]=listdlg('ListString',{data_handle.data.dataname},...
                            'SelectionMode','single',...
                            'Name','op_YTfit',...
                            'PromptString','Select electrophysiology ref data item',...
                            'ListSize',[400,300]);
                        if v
                            % check if size is T 
                            if data_handle.data(s).datainfo.data_dim(5)>1
                                data_handle.data(current_data).datainfo.electrophys_ref=data_handle.data(s).dataval;
                                message=sprintf('Electrophysiology information loaded from %s\n',data_handle.data(s).dataname);
                            else
                                errordlg('Selected dataitem has now ScanLine information','Check selection','modal');
                            end
                        else
                            % didn't change
                            data_handle.data(current_data).datainfo.electrophys_ref=orig_ref;
                        end
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
                        %{
                        % get pixel binnin information
                        pX_lim=numel(data_handle.data(parent_data).datainfo.X);
                        pY_lim=numel(data_handle.data(parent_data).datainfo.Y);
                        pZ_lim=numel(data_handle.data(parent_data).datainfo.Z);
                        pT_lim=numel(data_handle.data(parent_data).datainfo.T);
                        Xbin=data_handle.data(current_data).datainfo.bin_dim(2);
                        Ybin=data_handle.data(current_data).datainfo.bin_dim(3);
                        Zbin=data_handle.data(current_data).datainfo.bin_dim(4);
                        Tbin=data_handle.data(current_data).datainfo.bin_dim(5);
                        
                        windowsize=[1,Xbin,Ybin,Zbin,Tbin];
                        
                        fval=convn(data_handle.data(parent_data).dataval,ones(windowsize),'same');
                        [eigenval,eigenvec]=calculate_NCPCA(fval,data_handle.data(current_data).datainfo.noise_type,...
                            data_handle.data(current_data).datainfo.data_norm,...
                            data_handle.data(current_data).datainfo.bg_threshold,...
                            data_handle.data(current_data).datainfo.max_component,...
                            data_handle.data(parent_data).datainfo.data_dim,...
                            data_handle.data(current_data).datainfo.eigenvec);
                        
                        data_handle.data(current_data).dataval=eigenval;
                        data_handle.data(current_data).datainfo.eigenvec=[data_handle.data(parent_data).datainfo.t(:),eigenvec];
                        data_handle.data(current_data).datainfo.data_dim=[data_handle.data(current_data).datainfo.max_component,pX_lim,pY_lim,pZ_lim,pT_lim];
                        data_handle.data(current_data).datatype=data_handle.get_datatype(current_data);
                        data_handle.data(current_data).datainfo.dt=1;
                        data_handle.data(current_data).datainfo.t=1:1:data_handle.data(current_data).datainfo.max_component;% only two parameters
                        %}
                        data_handle.data(current_data).datainfo.last_change=datestr(now);
                        status=true;
                    case {'DATA_TRACE','RESULT_TRACE'}
                        Xbin=data_handle.data(current_data).datainfo.bin_dim(2);
                        Ybin=data_handle.data(current_data).datainfo.bin_dim(3);
                        Zbin=data_handle.data(current_data).datainfo.bin_dim(4);
                        Tbin=data_handle.data(current_data).datainfo.bin_dim(5);
                        windowsize=[1,Xbin,Ybin,Zbin,Tbin];
                        fval=convn(data_handle.data(parent_data).dataval,ones(windowsize),'same');
                        val=calculate_YTfit(data_handle.data(parent_data).datainfo.T,fval,...
                            data_handle.data(current_data).datainfo.tAP1,...
                            data_handle.data(current_data).datainfo.delTime,...
                            data_handle.data(current_data).datainfo.nAP,...
                            data_handle.data(current_data).datainfo.AP_shift,...
                            data_handle.data(current_data).datainfo.peak_bin,...
                            data_handle.data(current_data).datainfo.base_shift,...
                            data_handle.data(current_data).datainfo.base_bin,...
                            data_handle.data(current_data).datainfo.Fmax,...
                            data_handle.data(current_data).datainfo.Kd_I,...
                            data_handle.data(current_data).datainfo.gamma,...
                            data_handle.data(current_data).datainfo.Ca0,...
                            data_handle.data(current_data).datainfo.fitmode,...
                            data_handle.data(parent_data).datainfo.data_dim,true);
                        data_handle.data(current_data).dataval=[];
                        data_handle.data(current_data).dataval(:,1,1,1,:)=val(:,2:end)';
                        data_handle.data(current_data).datainfo.T=val(:,1);
                        nparam=size(val,2)-1;
                        data_handle.data(current_data).datainfo.t=1:1:nparam;
                        data_handle.data(current_data).datainfo.data_dim=[nparam,1,1,1,size(val,1)];
                        data_handle.data(current_data).datatype=data_handle.get_datatype(current_data);
                        data_handle.data(current_data).datainfo.last_change=datestr(now);
                        status=true;
                end
            end
    end
catch exception
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
    message=exception.message;
end
    function export_panel(handle,eventkey)
        global SETTING;
        switch eventkey.Key
            case {'f3'}
                SETTING.export_panel(findobj(handle,'Type','Axes'));
        end
    end

    function val=calculate_YTfit(time,data,tAP1,delTime,nAP,AP_shift,peak_bin,base_shift,base_bin,Fmax,Kd_I,gamma,Ca0,fitmode,datasize,showplot)
        % arrange to only decay profile no 2D info
        % image arranged as vectors containing each a decay.
        % in the format of p x n, where p is the number of variables and n
        % is number of samples
        time=time(:);
        F_F0=reshape(data,prod(datasize(1:end-1)),datasize(end));
        % find peak and base indices
        idx_peak=arrayfun(@(x)find(time>=x&time<=(x+peak_bin)),(tAP1+AP_shift)+[0:1:nAP-1]*delTime,'UniformOutput',false);
        idx_base=arrayfun(@(x)find(time>=(x-base_bin)&time<=x),(tAP1+base_shift)+[0:1:nAP-1]*delTime,'UniformOutput',false);
        % calculate Fpeak, Fbase
        switch fitmode
            case 'max'
                % find peak, Fpeak=[time,value]
                [Fpeak,pidx]=cellfun(@(x)max(F_F0(x)),idx_peak);
                Fpeak=[time(cellfun(@(x,y)x(y),idx_peak,num2cell(pidx))),Fpeak(:)];
                % find base, Fbase=[time,value]
                [Fbase,pidx]=cellfun(@(x)min(F_F0(x)),idx_base);
                Fbase=[time(cellfun(@(x,y)x(y),idx_base,num2cell(pidx))),Fbase(:)];
            case 'mean'
                % find peak, Fpeak=[time,value]
                Fpeak=cell2mat(cellfun(@(x)[mean(time(x)),mean(F_F0(x))],idx_peak,'UniformOutput',false)');
                % find base, Fbase=[time,value]
                Fbase=cell2mat(cellfun(@(x)[mean(time(x)),mean(F_F0(x))],idx_base,'UniformOutput',false)');
        end
        % computing delF_Fbase=[max,mean]
        dF_Fbase=(Fpeak(:,2)-Fbase(:,2))./Fbase(:,2);
        % computing delF_Fmax=[max,mean]
        dF_Fmax=(Fpeak(:,2)-Fbase(:,2))/Fmax;
        % computing peak calcium Capeak=[max,mean]
        Capeak=Kd_I*(Fpeak(:,2)-Fmax/gamma)./(Fmax-Fpeak(:,2));
        % computing delCa_free
        dCa_free=Capeak-Ca0;
        % compute facilitation
        facilitation=bsxfun(@rdivide,dF_Fmax,dF_Fmax(1,:));
        % compute rise time delay from base to peak
        taurise=Fpeak(:,1)-Fbase(:,1);
        % Output=time|Fpeak|taurise|Fbase|dF_Fbase|dF_Fmax|Capeak|dCa_free|Facilitation
        val=[Fpeak,taurise,Fbase(:,2),dF_Fbase,dF_Fmax,Capeak,dCa_free,facilitation];
        if showplot
            %Display trace results
            figure('Name','YT fitting function',...
                'NumberTitle','off',...
                'MenuBar','none',...
                'ToolBar','figure',...
                'Keypressfcn',@export_panel);
            subplot(2,2,1);
            plot(time,F_F0,'k-');hold on;plot(Fpeak(:,1),Fpeak(:,2),'ro-');plot(Fbase(:,1),Fbase(:,2),'bo-');
            legend({'\DeltaF/F_0','F_{peak}','F_{base}'});
            subplot(2,2,2);plot(Fpeak(:,1),[dF_Fbase,dF_Fmax],'o-');
            legend({'\DeltaF/F_{base}','\DeltaF/F_{max}'});
            subplot(2,2,3);plot(Fpeak(:,1),[Capeak,dCa_free],'o-');
            legend({'[Ca^{2+}]_{peak}(\muM)','\Delta[Ca^{2+}]_{free}(\muM)'});
            subplot(2,2,4);plot(Fpeak(:,1),[taurise,facilitation],'o-');
            legend({'\tau_{rise}(ms)','facilitation'});
        end
    end
end