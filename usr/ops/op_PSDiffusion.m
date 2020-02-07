function [ status, messages ] = op_PSDiffusion( data_handle, option, varargin )
% OP_PSDiffusion fit 1D gaussian over time
%   1D gaussians are fitted to line scan at the point source
%   Parameters DT vs T are extracted from the gaussian fits
%   Robust linear fit is applied to find the gradiant of DT/T => D
%   Applies to both 2D XT and 3D XZT data where operation will apply to
%   each Y slice
%   Automatic mode will detect starting position in X and T as well as
%   linear region.
%   In manual mode, user inputs is required for above parameters

%% function check

parameters=struct('note','',...
    'operator','op_PSDiffusion',...
    'parameter_space',[],...        %modify parameter space names
    'operator_mode','auto',...      %automatic mode or manual mode
    'windowsize',5,...              %auto mode filter window size
    'saturation_level',255,...      %max intensity from image 2^n-1 for nbit images
    'sourcesize',10,...             %point source initial diameter npixel
    'Tbin',3,...                    %time points averages
    'linear_range',[],...           %linear diffusion region for robust linear fit
    'MaxFunEvals',1e4,...
    'MaxIter',1e4,...
    'TolFun',1e-6,...
    'Displaystep',true);

status=false;messages='';
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
                    case {'DATA_IMAGE'}
                        % check data dimension, we only take XYT or XT
                        switch bin2dec(num2str(data_handle.data(current_data).datainfo.data_dim>1))
                            case {9,11}
                                % XT(01001) single image/XZT(01011) stackimages
                                parent_data=current_data;
                                % add new data
                                data_handle.data_add(cat(2,'op_PSDiffusion|',data_handle.data(current_data).dataname),[],[]);
                                % get new data index
                                new_data=data_handle.current_data;
                                % set parent data index
                                data_handle.data(new_data).datainfo.parent_data_idx=parent_data;
                                data_handle.data(new_data).datainfo=setstructfields(data_handle.data(new_data).datainfo,parameters);%parameters field will replace duplicate field in data
                                data_handle.data(new_data).datainfo.parameter_space='D|se|corrcoef|DoF';
                                status=true;
                            otherwise
                                messages=sprintf('only take XT or XZT data type\n');
                                return;
                        end
                        
                end
            end
        case 'modify_parameters'
            current_data=data_handle.current_data;
            %change parameters from this method only
            parameters=varargin{1:2:end};
            val=varargin{2:2:end};
            switch parameters
                case 'note'
                    data_handle.data(current_data).datainfo.note=num2str(val);
                    status=true;
                case 'operator'
                    errordlg('Unauthorised to change parameter');
                case 'operator_mode'
                    switch val
                        case {'auto','manual'}
                            data_handle.data(current_data).datainfo.operator_mode=val;
                            status=true;
                        otherwise
                            errordlg('Can only have auto or manual mode','Error','modal');
                    end
                case 'windowsize'
                    val=str2double(val);
                    % must be great than or equal to sourcesize and less
                    % than T size
                    data_handle.data(current_data).datainfo.windowsize=min(max(val,data_handle.data(current_data).datainfo.sourcesize),data_handle.data(current_data).datainfo.data_dim(5));
                    status=true;
                case 'sourcesize'
                    val=str2double(val);
                    % source size must be <1/5 of X size
                    data_handle.data(current_data).datainfo.sourcesize=min(val,data_handle.data(current_data).datainfo.data_dim(2)/5);
                    status=true;
                case 'Tbin'
                    val=str2double(val);
                    % source size must be <1/5 of X size
                    data_handle.data(current_data).datainfo.Tbin=min(val,data_handle.data(current_data).datainfo.data_dim(2)/5);
                    status=true;
                case 'saturation_level'
                    val=str2double(val);
                    data_handle.data(current_data).datainfo.saturation_level=val;
                    status=true;
                case 'parameter_space'
                    data_handle.data(current_data).datainfo.parameter_space=val;
                    status=true;
                case 'linear_range'
                    val=sort(str2num(val)); %#ok<ST2NM>
                    data_handle.data(current_data).datainfo.linear_range=val(1:2);
                    status=true;
                case {'MaxFunEvals','MaxIter','TolFun'}
                    data_handle.data(current_data).datainfo.(parameters)=str2double(val);
                    status=true;
                case 'Displaystep'
                    data_handle.data(current_data).datainfo.Displaystep=(val==1);
                    status=true;
                otherwise
                    errordlg('Unauthorised to change parameter');
            end
        case 'calculate_data'
            global SETTING; %#ok<TLEV>
            for current_data=data_idx
                figure('Name',sprintf('Point Source Diffusion fitting from data item %s',data_handle.data(current_data).dataname),...
                    'Color','k',...
                    'NumberTitle','off',...
                    'MenuBar','none',...
                    'ToolBar','figure',...
                    'Keypressfcn',@export_panel);
                axeshandle1=subplot(1,4,1);
                axeshandle2=subplot(1,4,2);
                axeshandle3=subplot(1,4,3);
                axeshandle4=subplot(1,4,4);
                % go through each selected data
                switch data_handle.data(current_data).datainfo.operator_mode
                    case 'auto' % automatic mode
                        % get parent data index
                        parent_data=data_handle.data(current_data).datainfo.parent_data_idx;
                        % get X profile axis
                        X=data_handle.data(parent_data).datainfo.X;
                        T=data_handle.data(parent_data).datainfo.T;
                        % get averaging windowsize
                        windowsize= data_handle.data(current_data).datainfo.windowsize;
                        % time binning size
                        Tbin=data_handle.data(current_data).datainfo.Tbin;
                        % set gaussian waist as sourcesize
                        waist=data_handle.data(current_data).datainfo.sourcesize;
                        % fitting parameters
                        MaxFunEvals=data_handle.data(current_data).datainfo.MaxFunEvals;
                        MaxIter=data_handle.data(current_data).datainfo.MaxIter;
                        TolFun=data_handle.data(current_data).datainfo.TolFun;
                        satlevel=data_handle.data(current_data).datainfo.saturation_level;
                        displaystep=data_handle.data(current_data).datainfo.Displaystep;
                        % loop through Z do analysis
                        for Slice_idx=1:data_handle.data(parent_data).datainfo.data_dim(4)
                            % get profile near the source starting
                            % positions to get starting estimates for
                            % gaussian fitting
                            % find starting point
                            slicedata=squeeze(data_handle.data(parent_data).dataval(:,:,:,Slice_idx,:));
                            temp=mean(slicedata,1);% sum in X only to get T profile
                            plot(axeshandle2,T,temp);
                            tempfilt=filter(ones(1,windowsize)/windowsize,1,temp);%smooth data
                            [~,diffpos]=max(tempfilt);diffpos=diffpos-round(windowsize/2);% linear region estimate
                            % work out source release in T
                            [~,puffpos]=max(diff(tempfilt(diffpos-floor(diffpos/2):diffpos+floor(diffpos/2))));
                            puffpos=puffpos-round(windowsize/2)+diffpos-floor(diffpos/2);% move back the averaging window size/2
                            % estimate background signal in the image
                            bg=median(slicedata(:,1:puffpos-1),2);
                            endpos=find(temp(puffpos:end)<=mean(bg),1,'first');% get end position in T
                            if isempty(endpos)
                                endpos=size(slicedata,2);
                            else
                                endpos=endpos+puffpos;
                            end
                            endpos=min(size(slicedata,2)-Tbin,endpos);
                            Y=mean(slicedata(:,puffpos:puffpos+10),2);
                            [~,peakpos]=max(Y);
                            init_estimates(1)=trapz(X,Y);%amplitude
                            init_estimates(3)=X(peakpos);%offset from centre
                            init_estimates(2)=data_handle.data(parent_data).datainfo.dX*waist;%width
                            estimates=init_estimates;
                            DT=nan(numel(T),1);
                            
                            % fit 1D gaussian over T
                            for T_idx=puffpos:1:endpos
                                Y=mean(slicedata(:,T_idx+Tbin),2)-bg;
                                % attempt gaussian fit if signal is above
                                % background signal level
                                if (median(Y)>0)
                                    [estimates,~,exitflag] = fminsearch(@chi2gaussfunc,estimates,...
                                        optimset('Display','off','MaxFunEvals',MaxFunEvals,'MaxIter',MaxIter,'TolX',TolFun),...
                                        X,Y,satlevel);
                                    if exitflag==1&&(max(gaussfunc(estimates,X))>=std(Y))
                                        if (estimates(2)>=waist)
                                            % if fitting worked and result
                                            % estimates are reasonable, i.e.
                                            % width is bigger than source
                                            % peak value is above noise level
                                            DT(T_idx)=estimates(2);% assign width to dataval
                                            if displaystep
                                                %plotting
                                                display_data(gaussfunc(estimates,X), axeshandle3, 'line', {X,[]}, {'X','a.u.'}, [false,false], []);%display fitting
                                                display_data(Y, axeshandle3, 'scatter', {X,[]}, {'X','a.u.'}, [false,false], []);%display data
                                                pause(0.001);% pause to see the result
                                            end
                                        else
                                            estimates(2)=init_estimates(2);
                                        end
                                    end
                                end
                            end
                            % linear DT vs T fit
                            linrange=data_handle.data(current_data).datainfo.linear_range;
                            if isempty(linrange)
                                %auto determine
                                linrange(1)=diffpos;
                                temp=find(isnan(DT(linrange(1):end)),1,'first');
                                if isempty(temp)||temp<10
                                    linrange(2)=endpos;
                                else
                                    linrange(2)=temp+linrange(1);
                                end
                            end
                            [p,S]=robustfit(T(linrange(1):linrange(2))',DT(linrange(1):linrange(2)));
                            f = polyval(flipud(p),T(puffpos:linrange(2)));
                            if displaystep
                                display_data(DT(puffpos:endpos), axeshandle4, 'scatter', {T(puffpos:endpos),[]}, {'T','DT'}, [false,false], []);%display data
                                display_data(f, axeshandle4, 'line', {T(puffpos:linrange(2)),[]}, {'T','DT'}, [false,false], []);%display fitting
                                %residue=f'-DT(linrange(1):linrange(2));
                                pause(0.001);% pause to see the result
                            end
                            nparam=numel(data_handle.data(current_data).datainfo.parameter_space);
                            disp(cat(2,'D=',num2str(p(2)),' se=',num2str(S.se(2))));
                            data_handle.data(current_data).dataval(1:nparam,1,1,1,Slice_idx)=[p(2) S.se(2) -S.coeffcorr(1,2) linrange(2)-linrange(1)];%D_estimate,goodness of fit,degree of freedom
                        end
                        % change data to pT type
                        data_handle.data(current_data).datainfo.T=data_handle.data(parent_data).datainfo.Y;
                        data_handle.data(current_data).datainfo.t=1:nparam;
                        data_handle.data(current_data).datainfo.data_dim=[nparam,1,1,1,data_handle.data(parent_data).datainfo.data_dim(3)];
                        data_handle.data(current_data).datatype=data_handle.get_datatype([]);
                        status=true;
                    case 'manual'
                end
                
            end
    end
catch exception
    messages=exception.message;
end
end