function [ status, message ] = op_PSLocalisation( data_handle, option, varargin )
%op_PSLocalisation Point source localisation using 2D gaussian fitting
%--------------------------------------------------------------------------
%   1. Details here
%
%---Batch process----------------------------------------------------------
%   Parameter=struct('selected_data','1','parameter_space','Cx|Cy|Sigma|Amp|Int|dCx|dCy|dSigma|dAmp','estimate_nsource','1','estimate_func','gauss2dsimplefunc','interval_start','[200,366,466,566,666,766]','baseline_deltaT','100','bg_deltaT','20','AP_deltaT','20','edge_allowance','5','display_fitting','true');
%   selected_data=data index, 1 means previous generated data
%   parameter_space=Cx|Cy|Sigma|Amp|Int|res|dCx|dCy|dSigma|dAmp
%   estimate_nsource=integer(>=0); number of gaussian center in one frame fit
%   estimate_func=gauss2dsimplefunc; 2d function used to estimate the shape use gauss2dsimplefunc or gauss2dgeneralfunc
%   baseline_deltaT=scalar(>0); time interval in ms for baseline period
%   bg_deltaT=scalar or 1xm vector~(>0);   time interval in ms for background pre APs
%   AP_deltaT=scalar or 1xm vector(>0); time interval in ms for m post APs
%   interval_start= 1x(m+1) vector or 'auto\d*'; starting time point for [background,1AP,2AP,...mAP], auto uses AP_deltaT as minimum peak distance in findpeaks function
%   edge_allowance=scalar(>=0); off the edge c(x,y) bounds as multiples of (dx,dy)
%   display_fitting=1|0;    display figure for fitting
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%   HEADER END

%% function complete

%table contents must all have default values
parameters=struct('note','',...
    'operator','op_PSLocalisation',...
    'parameter_space','Cx|Cy|Sigma|Amp|Int|dCx|dCy|dSigma|dAmp|res',...
    'estimate_nsource',1,...
    'estimate_func','gauss2dsimplefunc',...
    'baseline_deltaT',100,...
    'bg_deltaT',20,...
    'AP_deltaT',20,...
    'interval_start',[200,366,466,566,666,766],...
    'edge_allowance',5,...
    'display_fitting',true);

% assume worst
status=false;
% for batch process must return 'Data parentidx to childidx *' for each
% successful calculation
message='';
askforparam=true;
try
    % process input arguments
    % default to current data
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
                    op_PSLocalisation(data_handle, 'modify_parameters','data_index',data_idx,'paramarg',usrval{option_idx});
                case 'paramarg'
                    % batch processing passed on modified paramaters
                    varargin=usrval{option_idx};
                    % batch processing avoid any manual input
                    askforparam=false;
            end
        end
    end

    % performed specified actions
    switch option
        case 'add_data'
            % add new data item
            for current_data=data_idx
                % loop through all selected data
                switch data_handle.data(current_data).datatype
                    % sort out valid input data type
                    case {'DATA_IMAGE'}
                        % check data dimension
                        switch bin2dec(num2str(data_handle.data(current_data).datainfo.data_dim>1))
                            case {13,14,28,29,30,31}
                                % XYT (01101) / XYZ (01110) / tXY (11100)/ tXYT (11101) / tXYZ (11110) / tXYZT (11111)
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
                                data_handle.data(new_data).datainfo.parameter_space='Cx|Cy|Sigma|Amp|Int|dCx|dCy|dSigma|dAmp|res';
                                data_handle.data(new_data).datainfo.bin_dim=data_handle.data(parent_data).datainfo.bin_dim;
                                if isempty(data_handle.data(new_data).datainfo.bin_dim)
                                    data_handle.data(new_data).datainfo.bin_dim=[1,1,1,1,1];
                                end
                                % pass on metadata info
                                data_handle.data(new_data).metainfo=data_handle.data(parent_data).metainfo;
                                message=sprintf('%s\nData %s to %s added.',message,num2str(parent_data),num2str(new_data));
                                status=true;
                            otherwise
                                message=sprintf('only take XT or XYT data type\n');
                                return;
                        end
                        % case {'DATA_SPC'}
                        % spc data type
                end
            end
        case 'modify_parameters'
            % modfied operation parameters
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
                            message=sprintf('%sUnauthorised to change %s',message,parameters);
                            status=false;
                        case 'parameter_space'
                            data_handle.data(current_data).datainfo.parameter_space=val;
                            status=true;
                        case 'estimate_nsource'
                            % minimum one
                            nsource=max(1,round(str2double(val)));
                            data_handle.data(current_data).datainfo.estimate_nsource=nsource;
                            data_handle.data(current_data).datainfo.parameter_space=[repmat('Cx|Cy|Sigma|Amp|',1,nsource),'Int',repmat('|dCx|dCy|dSigma|dAmp',1,nsource),'|res'];
                        case 'estimate_func'
                            data_handle.data(current_data).datainfo.estimate_func=val;
                            nsource=data_handle.data(current_data).datainfo.estimate_nsource;
                            data_handle.data(current_data).datainfo.parameter_space=[repmat('Cx|Cy|Sigmax|Sigmay|Amp|Angle',1,nsource),'Int',repmat('|dCx|dCy|dSigmax|dSigmay|dAmp|dAngle',1,nsource),'|res'];
                            status=true;
                        case 'baseline_deltaT'
                            data_handle.data(current_data).datainfo.baseline_deltaT=max(10,round(str2double(val)));
                        case 'bg_deltaT'
                            val=str2num(val);
                            paramsize=numel(val);
                            if paramsize==1||paramsize==numel(data_handle.data(current_data).datainfo.interval_start)-1
                                data_handle.data(current_data).datainfo.bg_deltaT=max(0,val);
                            else
                                message=sprintf('%s\n%s size does not match size of intervals.',message,parameters);
                                status=false;
                            end
                        case 'AP_deltaT'
                            val=str2num(val);
                            paramsize=numel(val);
                            if paramsize==1||paramsize==numel(data_handle.data(current_data).datainfo.interval_start)-1
                                data_handle.data(current_data).datainfo.AP_deltaT=max(1,val);
                            else
                                message=sprintf('%s\n%s size does not match size of intervals.',message,parameters);
                                status=false;
                            end
                        case 'interval_start'
                            switch val(1)
                                case 'a'
                                    % call peak find function on
                                    % electrophysdata
                                    peakdataidx=str2double(cell2mat(regexp(val,'(?<=auto)\d*','match')));
                                    if ~isempty(peakdataidx)
                                        peakdata=squeeze(data_handle.data(peakdataidx).dataval);
                                        Tdata=data_handle.data(peakdataidx).datainfo.T;
                                        minpdist=min(data_handle.data(current_data).datainfo.bg_deltaT);
                                        pprominence=2*std(peakdata);
                                        [pks,locs,w,p]=findpeaks(peakdata,Tdata,'MinPeakDistance',minpdist,'MinPeakProminence',pprominence);
                                        % plot in debug mode
                                        figure(1);plot(Tdata,peakdata,'r-',locs,pks,'ro');
                                        if isempty(locs)%no peak found revert to default
                                            opts.Interpreter='tex';
                                            answer=inputdlg({'Use auto\d* format failed please input intervals manually here'},'Interval Start',1,{'[200,366,466,566,666,766]'},opts);
                                            if isempty(answer)
                                                data_handle.data(current_data).datainfo.interval_start=[200,366,466,566,666,766];
                                            else
                                                data_handle.data(current_data).datainfo.interval_start=str2num(answer);
                                            end
                                        else
                                            % get background start using the first peak - bg duration - baseline duration
                                            bgstart=locs(1)-data_handle.data(current_data).datainfo.baseline_deltaT-data_handle.data(current_data).datainfo.bg_deltaT;
                                            data_handle.data(current_data).datainfo.interval_start=[bgstart,locs];
                                        end
                                    else
                                        opts.Interpreter='tex';
                                        answer=inputdlg({'Use auto\d* format failed please input intervals manually here'},'Interval Start',1,{'[200,366,466,566,666,766]'},opts);
                                        if isempty(answer)
                                            data_handle.data(current_data).datainfo.interval_start=[200,366,466,566,666,766];
                                        else
                                            data_handle.data(current_data).datainfo.interval_start=str2num(answer);
                                        end
                                    end
                                otherwise
                                    data_handle.data(current_data).datainfo.interval_start=max(0,round(str2num(val)));
                            end
                        case 'edge_allowance'
                            % minimum one
                            data_handle.data(current_data).datainfo.edge_allowance=max(1,round(str2double(val)));
                        case 'display_fitting'
                            switch val
                                case {'1','true'}
                                    data_handle.data(current_data).datainfo.display_fitting=true;
                                otherwise
                                    data_handle.data(current_data).datainfo.display_fitting=false;
                            end
                        otherwise
                            message=sprintf('%s\nUnauthorised to change %s',message,parameters);
                            status=false;
                    end
                    if status
                        message=sprintf('%s\n%s has changed to %s',message,parameters,val);
                    end
                end
            end
        case 'calculate_data'
            options=struct('Display','off',...
                'MaxFunctionEvaluations',1e12,...
                'MaxIterations',1e12,...
                'OptimalityTolerance',1e-12,...
                'StepTolerance',1e-12,...
                'ConstraintTolerance',1e-12);
            % calculate data using operation
            for current_data=data_idx
                parent_data=data_handle.data(current_data).datainfo.parent_data_idx;
                data_handle.data(current_data).dataval=[];
                switch data_handle.data(parent_data).datatype
                    case {'DATA_IMAGE'}%originated from 3D/4D traces_image
                        % go through each selected data
                        signalstart=data_handle.data(current_data).datainfo.interval_start(:);% first interval must be background
                        baselinedt=data_handle.data(current_data).datainfo.baseline_deltaT(:);% duration for the baseline
                        bgdt=data_handle.data(current_data).datainfo.bg_deltaT(:);% duration for the background
                        APdt=data_handle.data(current_data).datainfo.AP_deltaT(:);% duration for the action potentials
                        estn=data_handle.data(current_data).datainfo.estimate_nsource;
                        fit2dfunc=data_handle.data(current_data).datainfo.estimate_func;
                        doplot=data_handle.data(current_data).datainfo.display_fitting;
                        ninterval=numel(signalstart);   % nubmer of intervals
                        if numel(APdt)==1
                            signalinterval=[signalstart,signalstart+[baselinedt,repmat(APdt,1,ninterval-1)]'];  % time intervals
                        else
                            signalinterval=[signalstart,signalstart+[baselinedt;APdt]];  % time intervals
                        end
                        if numel(bgdt)==1
                            bgdt=repmat(bgdt,1,ninterval-1);
                        end

                        edge_allowance=data_handle.data(current_data).datainfo.edge_allowance;
                        % time T is interval order bg->AP1->AP2->...->APn
                        T=0:1:ninterval-1;
                        % time t is parameter space
                        nparam=numel(regexp(data_handle.data(current_data).datainfo.parameter_space,'[|]','split'));
                        nsource=data_handle.data(current_data).datainfo.estimate_nsource;
                        t=1:1:nparam;%

                        % total time interval
                        Tdata=data_handle.data(parent_data).datainfo.T;

                        % x and y interval
                        imgx=data_handle.data(parent_data).datainfo.X;imgx=imgx(:);
                        xbound=[imgx(1),imgx(end)];
                        dx=data_handle.data(parent_data).datainfo.dX;
                        imgy=data_handle.data(parent_data).datainfo.Y;imgy=imgy(:);
                        ybound=[imgy(1),imgy(end)];
                        dy=data_handle.data(parent_data).datainfo.dY;
                        [x,y]=meshgrid(imgy,imgx);
                        xres=numel(imgx);yres=numel(imgy);

                        %-------------------
                        % initialise data holder
                        signaldata=squeeze(data_handle.data(parent_data).dataval);
                        switch fit2dfunc
                            case 'gauss2dsimplefunc'
                                result=nan(size(signalinterval,1),4*estn+1);
                                result_err=nan(size(signalinterval,1),4*estn+1);
                            case 'gauss2dgeneralfunc'
                                result=nan(size(signalinterval,1),6*estn+1);
                                result_err=nan(size(signalinterval,1),6*estn+1);
                        end
                        exportdata=[];
                        if doplot
                            hfig=figure(current_data);clf;
                            hfig.Name=data_handle.data(current_data).dataname;
                            hfig.WindowState='maximized';
                            nplotrow=7;nplotcol=ninterval;
                        end
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
                        N_steps=size(signalinterval,1);barstep=0;
                        data_handle.data(current_data).dataval(:,1,1,1,:)=[result,result_err]';
                        %--------------------------------------------------------------------------
                        % fitting gaussian through intervals time lapsed through interval (APs)
                        for partidx=1:N_steps
                            fail=false;
                            % check waitbar
                            if getappdata(waitbar_handle,'canceling')
                                message=sprintf('%s\n%s calculation cancelled.',message,parameters.operator);
                                delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
                                return;
                            end
                            % Report current estimate in the waitbar's message field
                            done=partidx/N_steps;
                            if floor(100*done)>=barstep
                                % update waitbar
                                waitbar(done,waitbar_handle,sprintf('%g%%',barstep));
                                barstep=max(barstep+1,floor(100*done));
                            end

                            % find time interval
                            timeidx=(Tdata>=signalinterval(partidx,1)&Tdata<=signalinterval(partidx,2));
                            % find corresponding images
                            tempimg=squeeze(mean(signaldata(:,:,timeidx),3));
                            if partidx==1
                                % background image
                                bgimg=tempimg;
                                tracetimeidx=timeidx;bgtimeidx=timeidx;
                                titletext='baseline';
                            else
                                timestamp(partidx)=signalinterval(partidx,1);
                                bgtimeidx=(Tdata>=signalinterval(partidx,1)-bgdt(partidx-1)&Tdata<signalinterval(partidx,1));
                                titletext=sprintf('int%i|%g',partidx,signalinterval(partidx,1));
                                tracetimeidx=(Tdata>=signalinterval(partidx,1)-bgdt(partidx-1)&Tdata<=10*(signalinterval(partidx,2)-signalinterval(partidx,1))+signalinterval(partidx,1));
                                if isempty(find(bgtimeidx, 1))
                                    % no background correction use baseline

                                else
                                    bgimg=squeeze(mean(signaldata(:,:,bgtimeidx),3));
                                end
                                if max(tempimg(:))>2*pnoiseimg
                                    % subtract background image
                                    tempimg=tempimg-bgimg;
                                else
                                    tempimg=[];
                                end
                            end
                            if ~isempty(tempimg)
                                % get maximum intensity
                                satlevel=max(tempimg(:));
                                pnoise=std(tempimg(:));
                                % get estimated minimum intensity
                                pnoiseimg=squeeze(std(bgimg(:)));
                                if doplot
                                    % plot raw images in the first row
                                    hax=subplot(nplotrow,nplotcol,partidx,'Parent',hfig);
                                    mesh(hax,x,y,tempimg,'FaceColor','interp','EdgeColor','none');
                                    xlim(hax,ybound);ylim(hax,xbound);
                                    axis(hax,'square');view(hax,[0 -90]);
                                    title(hax,titletext);

                                    % plot temporal profile
                                    temporaltrace=squeeze(mean(signaldata(:,:,tracetimeidx),[1,2]));
                                    f0=squeeze(mean(signaldata(:,:,bgtimeidx),[1,2,3]));
                                    temporaltrace=(temporaltrace-f0)./f0;
                                    hax=subplot(nplotrow,nplotcol,nplotcol*1+partidx,'Parent',hfig);
                                    plot(hax,Tdata(tracetimeidx),temporaltrace,'b-');axis(hax,'square');hold(hax,'on');
                                    title(hax,'t profile');
                                    exportdata{partidx}.temporalall=[Tdata(tracetimeidx)',temporaltrace];
                                end
                                %------
                                % estimate position in x axis
                                % get xprofile
                                xprofile=nanmean(tempimg,2);xprofile=xprofile(:);
                                if doplot
                                    % plot xprofile
                                    hax=subplot(nplotrow,nplotcol,nplotcol*2+partidx,'Parent',hfig);
                                    plot(hax,imgx,xprofile,'bo');axis(hax,'square');view(hax,[90 90]);hold(hax,'on');
                                    title(hax,'y profile');
                                end
                                if median(xprofile)>0
                                    % try and find peak position firsts
                                    [maxval,loc]=findpeaks(xprofile,'NPeaks',estn,'SortStr','descend');
                                    if isempty(loc)
                                        % if peak not found, use maximum
                                        [maxval,loc]=max(xprofile);
                                    end
                                    % if number of peak is less than wanted
                                    if numel(loc)<estn
                                        peakpos=[imgx(loc);(rand(estn-numel(loc),1)-0.5)*xres*dx+mean(imgx)];
                                        maxval=[maxval;repmat(max(maxval),(estn-numel(loc)),1)];
                                    else
                                        peakpos=imgx(loc);
                                    end
                                    % make educated guess
                                    xinitestimates=[peakpos,repmat(dx,estn,1),maxval];
                                    % set lower bound (center,sigma,amplitude)
                                    lb=repmat([xbound(1)-edge_allowance*dx,dx,pnoise/estn],estn,1);
                                    % set upper bound (center,sigma,amplitude)
                                    ub=repmat([xbound(2)+edge_allowance*dx,diff(xbound)/2,satlevel/estn],estn,1);
                                    % try to fit 1D gaussian
                                    [xestimates,~,xexitflag,output] = fmincon(@chi2gauss1dfunc,xinitestimates,[],[],[],[],lb,ub,@mygausscon,options,imgx,xprofile,satlevel/numel(imgx));
                                    if xexitflag>0
                                        if doplot
                                            for fidx=1:estn
                                                plot(hax,imgx,gauss1dfunc(xestimates(fidx,:),imgx),'r--','LineWidth',3);
                                            end
                                            plot(hax,imgx,gauss1dfunc(xestimates,imgx),'b--','LineWidth',3);
                                            ylim(hax,sort([0,max(xprofile)]));
                                        end
                                    else
                                        xestimates=xinitestimates;
                                        fprintf('%s\n',output.message);
                                    end
                                else
                                    fail=true;
                                end
                                %------
                                % estimate position in y axis
                                % get y profile
                                yprofile=nanmean(tempimg,1);yprofile=yprofile(:);
                                if doplot
                                    % plot y profile
                                    hax=subplot(nplotrow,nplotcol,nplotcol*3+partidx,'Parent',hfig);
                                    plot(hax,imgy,yprofile,'bo');axis(hax,'square');hold(hax,'on');
                                    title(hax,'x profile');
                                end
                                if median(yprofile)>0
                                    % try and find peak position firsts
                                    [maxval,loc]=findpeaks(yprofile,'NPeaks',estn,'SortStr','descend');
                                    if isempty(loc)
                                        % if peak not found, use maximum
                                        [maxval,loc]=max(yprofile);
                                    end
                                    % if number of peak is less than wanted
                                    if numel(loc)<estn
                                        peakpos=[imgy(loc);(rand(estn-numel(loc),1)-0.5)*yres*dy+mean(imgy)];
                                        maxval=[maxval;repmat(max(maxval),(estn-numel(loc)),1)];
                                    else
                                        peakpos=imgy(loc);
                                    end
                                    % make educated guess
                                    yinitestimates=[peakpos,repmat(dy,estn,1),maxval];
                                    % set lower bound (center,sigma,amplitude)
                                    lb=repmat([ybound(1)-edge_allowance*dy,dy/2,pnoise/estn],estn,1);
                                    % set upper bound (center,sigma,amplitude)
                                    ub=repmat([ybound(2)+edge_allowance*dy,diff(ybound)/2,satlevel/estn],estn,1);
                                    % try to fit 1D gaussian
                                    [yestimates,~,yexitflag,output] = fmincon(@chi2gauss1dfunc,yinitestimates,[],[],[],[],lb,ub,@mygausscon,options,imgy,yprofile,satlevel/numel(imgx));
                                    if yexitflag>0
                                        if doplot
                                            for fidx=1:estn
                                                plot(hax,imgy,gauss1dfunc(yestimates(fidx,:),imgy),'r--','LineWidth',3);
                                            end
                                            plot(hax,imgy,gauss1dfunc(yestimates,imgy),'b--','LineWidth',3);
                                            ylim(hax,sort([0,max(yprofile)]));
                                        end
                                    else
                                        yestimates=yinitestimates;
                                        fprintf('%s\n',output.message);
                                    end
                                else
                                    fail=true;
                                end
                                if ~fail
                                    %--------
                                    % 2d gaussian estimates
                                    switch fit2dfunc
                                        case 'gauss2dsimplefunc'
                                            % use xesitmate and yestimate to make a educated guess
                                            initestimates=[xestimates(:,1),yestimates(:,1),min([xestimates(:,2),yestimates(:,2)],[],2),max([xestimates(:,3),yestimates(:,3)],[],2)];
                                            % allow 5dx and 5dy variation from original estimate
                                            xmin=xestimates(:,1)-edge_allowance*dx;xmax=xestimates(:,1)+edge_allowance*dx;
                                            ymin=yestimates(:,1)-edge_allowance*dy;ymax=yestimates(:,1)+edge_allowance*dy;
                                            % make lower and upper bound
                                            lb=[xmin,ymin,min([xestimates(:,2),yestimates(:,2)],[],2)*0.5,min([xestimates(:,3),yestimates(:,3)],[],2)*0.5];
                                            ub=[xmax,ymax,max([xestimates(:,2),yestimates(:,2)],[],2)*1.5,max([xestimates(:,3),yestimates(:,3)],[],2)*1.5];
                                        case 'gauss2dgeneralfunc'

                                            initestimates=[xestimates(:,1),yestimates(:,1),min([xestimates(:,2),yestimates(:,2)],[],2),min([xestimates(:,2),yestimates(:,2)],[],2),max([xestimates(:,3),yestimates(:,3)],[],2),0];
                                            % allow 5dx and 5dy variation from original estimate
                                            xmin=xestimates(:,1)-edge_allowance*dx;xmax=xestimates(:,1)+edge_allowance*dx;
                                            ymin=yestimates(:,1)-edge_allowance*dy;ymax=yestimates(:,1)+edge_allowance*dy;
                                            % make lower and upper bound
                                            lb=[xmin,ymin,min([xestimates(:,2),yestimates(:,2)],[],2)*0.5,min([xestimates(:,2),yestimates(:,2)],[],2)*0.5,min([xestimates(:,3),yestimates(:,3)],[],2)*0.5,0];
                                            ub=[xmax,ymax,max([xestimates(:,2),yestimates(:,2)],[],2)*1.5,max([xestimates(:,2),yestimates(:,2)],[],2)*1.5,max([xestimates(:,3),yestimates(:,3)],[],2)*1.5,180];
                                    end

                                    % conditional function minimum search for a 2D gaussian
                                    [estimates,fval,exitflag,output] = fmincon(@chi2gauss2dfunc,initestimates,[],[],[],[],lb,ub,@mygausscon,optimset(options),imgx,imgy,tempimg,satlevel);
                                    if exitflag>0
                                        % standard error estimates using hessian output from fminunc (acucrate)
                                        [estimates,fval,exitflag,output,grad,hessian]=fminunc(@chi2gauss2dfunc,estimates,optimset(options),imgx,imgy,tempimg,satlevel);
                                        if nsource>1
                                            [~,sortidx]=sort(estimates(:,1));
                                            estimates=estimates(sortidx,:);
                                        end
                                        if exitflag<0
                                            est_stderr=nan(numel(estimates),1);
                                        else
                                            % calcuate standard error of the estimated parameters
                                            est_stderr=sqrt(abs(diag(inv(hessian))));
                                        end
                                        estimates(:,3)=abs(estimates(:,3));
                                        switch fit2dfunc
                                            case 'gauss2dsimplefunc'
                                                fitimg=gauss2dsimplefunc(estimates,imgx,imgy);
                                            case 'gauss2dgeneralfunc'
                                                fitimg=gauss2dgeneralfunc(estimates,imgx,imgy);
                                        end
                                        resimg=(fitimg-tempimg);
                                        I_total=trapz(imgx,trapz(imgy,fitimg,2));
                                        estimates=estimates';
                                        imgresidue=sqrt(mean(resimg(:).^2));
                                        result(partidx,:)=[estimates(:)',I_total];
                                        if nsource>1
                                            est_stderr=reshape(est_stderr,nsource,4);
                                            est_stderr=est_stderr(sortidx,:)';
                                        end
                                        result_err(partidx,:)=[est_stderr(:)',imgresidue];
                                        if doplot
                                            % plot fitted image
                                            hax=subplot(nplotrow,nplotcol,nplotcol*4+partidx,'Parent',hfig);
                                            mesh(hax,x,y,fitimg,'EdgeColor','none','FaceColor','interp');colormap('jet');
                                            hold(hax,'on');
                                            % plot estimated center
                                            scatter(hax,estimates(2,:),estimates(1,:),30,'d','ko','filled');
                                            title(hax,sprintf('fitted'));
                                            xlim(hax,ybound);ylim(hax,xbound);
                                            axis(hax,'square');view(hax,[0 -90]);

                                            % draw residual between fitted and original image

                                            hax=subplot(nplotrow,nplotcol,nplotcol*5+partidx,'Parent',hfig);
                                            mesh(hax,x,y,resimg,'EdgeColor','none','FaceColor','interp');colormap('jet');
                                            xlim(hax,ybound);ylim(hax,xbound);
                                            axis(hax,'square');view(hax,[0 -90]);
                                            title(hax,sprintf('residual:\n%0.3g',imgresidue));

                                            % plot xy profiles
                                            xprofile=nanmean(fitimg,2);xprofile=xprofile(:);
                                            hax=subplot(nplotrow,nplotcol,nplotcol*2+partidx,'Parent',hfig);
                                            plot(hax,imgx,xprofile,'r-','LineWidth',3);
                                            yprofile=nanmean(fitimg,1);yprofile=yprofile(:);
                                            hax=subplot(nplotrow,nplotcol,nplotcol*3+partidx,'Parent',hfig);
                                            plot(hax,imgy,yprofile,'r-','LineWidth',3);

                                            % plot radial profile
                                            datainfo.X=imgx;datainfo.Y=imgy;datainfo.data_dim=[1,size(tempimg),1,1];
                                            parameter.val_lb=-Inf;parameter.val_ub=Inf;parameter.dr=max(max(diff(datainfo.X)),max(diff(datainfo.Y)));
                                            roi.name='CENTER';roi.coord=[estimates(2,:),estimates(1,:)];
                                            hax=subplot(nplotrow,nplotcol,nplotcol*6+partidx,'Parent',hfig);
                                            [r,v,~]=calculate_rprofile( tempimg, datainfo, parameter, roi );
                                            plot(hax,r,v,'bo');axis(hax,'square');hold(hax,'on');
                                            % export this
                                            exportdata{partidx}.radialraw=[r',v'];
                                            title(hax,'radial profile');
                                            [r,v,~]=calculate_rprofile( fitimg, datainfo, parameter, roi );
                                            plot(hax,r,v,'r-','LineWidth',3);
                                            ylim(hax,[0 max(v)])
                                            exportdata{partidx}.radialfit=[r',v'];

                                            % plot peak temporal profile
                                            delta=0.1;
                                            posxidx=(imgx>=(estimates(1,:)-delta)&imgx<=(estimates(1,:)+delta));
                                            posyidx=(imgy>=(estimates(2,:)-delta)&imgy<=(estimates(2,:)+delta));
                                            temporaltrace=squeeze(mean(signaldata(posxidx,posyidx,tracetimeidx),[1,2]));
                                            f0=squeeze(mean(signaldata(posxidx,posyidx,bgtimeidx),[1,2,3]));
                                            temporaltrace=(temporaltrace-f0)./f0;
                                            hax=subplot(nplotrow,nplotcol,nplotcol*1+partidx,'Parent',hfig);
                                            plot(hax,Tdata(tracetimeidx),temporaltrace,'r-','LineWidth',1);

                                            exportdata{partidx}.temporalsource=[Tdata(tracetimeidx)',temporaltrace];
                                            exportdata{partidx}.estimate=[signalinterval(partidx,1),result(partidx,:)];

                                            % plot temporal profile
                                            temporaltrace=squeeze(mean(signaldata(:,:,tracetimeidx),[1,2]));
                                            f0=squeeze(mean(signaldata(:,:,bgtimeidx),[1,2,3]));
                                            temporaltrace=(temporaltrace-f0)./f0;
                                            hax=subplot(nplotrow,nplotcol,nplotcol*1+partidx,'Parent',hfig);
                                            plot(hax,Tdata(tracetimeidx),temporaltrace,'b-');axis(hax,'square');hold(hax,'on');
                                            title(hax,'t profile');
                                            exportdata{partidx}.temporalall=[Tdata(tracetimeidx)',temporaltrace];

                                            if partidx>1
                                                plot(hax,[signalinterval(partidx,1),signalinterval(partidx,1)],[-0.05,0.5],'k--','LineWidth',0.5);
                                                plot(hax,[signalinterval(partidx,1)-bgdt(partidx-1),signalinterval(partidx,1)-bgdt(partidx-1)],[-0.05,0.5],'k-','LineWidth',1);
                                                plot(hax,[signalinterval(partidx,2),signalinterval(partidx,2)],[-0.05,0.5],'k--','LineWidth',0.5);

                                                xlim(hax,[signalinterval(partidx,1)-10,signalinterval(partidx,1)+50]);
                                            end
                                        end
                                    else
                                        fprintf('%s\n',output.message);
                                    end
                                end
                            else

                            end
                        end
                        delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
                        save(regexprep(cat(2,data_handle.data(current_data).dataname,'.m'),'[|]','_'),"exportdata",'-mat');
                        data_handle.data(current_data).dataval(:,1,1,1,:)=[result,result_err]';
                        data_handle.data(current_data).datainfo.t=t;
                        data_handle.data(current_data).datainfo.dt=1;
                        data_handle.data(current_data).datainfo.X=1;
                        data_handle.data(current_data).datainfo.dX=1;
                        data_handle.data(current_data).datainfo.Y=1;
                        data_handle.data(current_data).datainfo.dY=1;
                        data_handle.data(current_data).datainfo.T=timestamp;
                        data_handle.data(current_data).datainfo.dT=1;
                        data_handle.data(current_data).datainfo.data_dim=size(data_handle.data(current_data).dataval);
                        data_handle.data(current_data).datatype=data_handle.get_datatype(current_data);
                        data_handle.data(current_data).datainfo.last_change=datestr(now);
                        message=sprintf('%s\nData %s to %s %s calculated.',message,num2str(parent_data),num2str(current_data),data_handle.data(current_data).datainfo.operator);
                        status=true;
                end
            end
            %--------clean up------------------------
            % close waitbar if exist
            if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
                delete(waitbar_handle);
            end
    end
    %-------- error handle ----------------------
catch exception
    % delete waitbar if exist
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
    % output error message
    message=sprintf('%s\n%s',message,exception.message);
end