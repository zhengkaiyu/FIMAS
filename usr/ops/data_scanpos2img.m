function [ status, message ] = data_scanpos2img( obj, selected_data, askforparam, defaultparam )
%data_scanpos2img Transform femtonics scan data to images using scx and scy
%--------------------------------------------------------------------------
%   Femtonics data can store real time mirror scan data scx and scy for all
%   data scans.  These data are used to transform scaned detector data from
%   any scan type to pixelated images using intensity proportioned
%   repopulated scatter data and histcount2 with fixed resolution.
%
%---Batch process----------------------------------------------------------
%   Parameter=struct('selected_data','1','signaldataidx','1','scandataidx','[4,5]','split_ROI','1','bglev','400','I_scaling','1','psfwd','0.45','dx','','dy','','newdata','1');
%   selected_data=1x2 vector, scan data index [scx,scy] in t channel
%   signaldataidx=scalar, signal data index in t channel
%   scandataidx=data index, relative data index to selected data,!=0
%   split_ROI=1|0,   reconstruct whole image as one or split scan protocol
%   bglev=scalar, background count level
%   I_scaling=scalar,   intensity scaling to generate random scatter data from
%   psfwd=1x2 vector,  of point spread function fwhm in x and y
%   dx=scalar,  reconstructed image resolution in x calculated from psfwd
%   dy=scalar,  reconstructed image resolution in y calculated from psfwd
%   newdata=1|0,   generate new data or recalculate
%--------------------------------------------------------------------------
%   HEADER END

%% function check
% assume worst
status=false;
% for batch process must return 'Data parentidx to childidx *' for each
% successful calculation
message='';
try
    % initialise counter
    data_idx=1;
    % number of data to process
    ndata=numel(selected_data);
    % loop through individual data
    while data_idx<=ndata
        % get the current data index
        current_data=selected_data(data_idx);
        
        % ---- Parameter Assignment ----
        % if it is not automated, we need manual parameter input/adjustment
        if askforparam
            % setup default options
            % default to create new data
            if find(strcmp(obj.data(current_data).datainfo.operator,'data_scanpos2img'))
                % overwrite existing data
                newdata=false;
                % signal data index in t channel
                signaldataidx=obj.data(current_data).datainfo.signaldataidx;
                % scan data index in t channel
                scandataidx=obj.data(current_data).datainfo.scandataidx;
                % split_roi option
                split_ROI=obj.data(current_data).datainfo.split_ROI;
                % background intensity level
                bglev=obj.data(current_data).datainfo.bglev;
                % random scatter point number scaling
                I_scaling=obj.data(current_data).datainfo.I_scaling;
                % point spread function fwhm 450nm
                psfwd=obj.data(current_data).datainfo.psfwd;
                psfsig = [psfwd,psfwd]/2.3548;  % sigma=FWHM/(2*sqrt(2*log(2)))
                % x,y grid resolution
                dx=obj.data(current_data).datainfo.dX;
                dy=obj.data(current_data).datainfo.dY;
            else
                % new data will need to be created
                newdata=true;
                % signal data index in t channel
                signaldataidx=1;
                % scan data index in t channel
                scandataidx=[4,5];
                % split_roi option
                split_ROI=true;
                % background intensity level
                bglev=500;
                % random scatter point number scaling
                I_scaling=1;
                % point spread function fwhm 450nm
                psfwd=0.45;
                psfsig = [psfwd,psfwd]/2.3548;  % sigma=FWHM/(2*sqrt(2*log(2)))
                % x,y grid resolution
                dx=psfsig(1)/3;
                dy=psfsig(2)/3;
            end
            
            % need user input/confirm some parameters
            prompt = {'signaldataindx (signal data index in t channel)',...
                'scandataidx (scan data index [scx,scy] in t channel)',...
                'split_ROI (1|0)',...
                'bglev (background intensity level, >=0)',...
                'I_scaling (random points num to intesntiy,>1e-3)',...
                'psfwd (psf fwhm in um >0.150um)',...
                'dx (auto calc from psfwd)',...
                'dy (auto calc from psfwd)',...
                'newdata (1|0)'};
            dlg_title = cat(2,'scanpos2img parameter for ',obj.data(current_data).dataname);
            num_lines = 1;
            def = {num2str(signaldataidx),num2str(scandataidx),num2str(split_ROI),num2str(bglev),num2str(I_scaling),num2str(psfwd),num2str(dx),num2str(dy),num2str(newdata)};
            set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
            set(0,'DefaultUicontrolForegroundColor','k');
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            set(0,'DefaultUicontrolBackgroundColor','k');
            set(0,'DefaultUicontrolForegroundColor','w');
            
            if ~isempty(answer)
                % get answer and check options
                % get number of t channel size
                chnum=obj.data(current_data).datainfo.data_dim(1);
                
                % check signal data index
                signaldataidx=round(str2double(answer{1}));
                if isempty(find(signaldataidx>chnum))||isempty(find(signaldataidx<1))
                    
                else
                    % one or two scandata idx is invalid
                    message=sprintf('%s\nsignal data index invalid. current t dim size %i.',message,chnum);
                    return;
                end
                
                % check scan data index
                scandataidx=round(str2num(answer{2}));
                if isempty(find(scandataidx>chnum))||isempty(find(scandataidx<1))
                    
                else
                    % one or two scandata idx is invalid
                    message=sprintf('%s\nscan data index invalid. current t dim size %i.',message,chnum);
                    return;
                end
                
                % check split roi option
                switch answer{3}
                    case {'1','true'}
                        split_ROI=true;
                    case {'0','false'}
                        split_ROI=false;
                    otherwise
                        message=sprintf('%s\nUnknown split_ROI answer %s entered.',message,answer{2});
                        return;
                end
                
                % make sure bglev background intensity level is >=0
                bglev=max(0,round(str2double(answer{4})));
                
                % make sure bglev background intensity level is >=1e-3
                I_scaling=max(1e-3,round(str2double(answer{5})));
                
                % make sure psfwd is reasonable >=150nm
                psfwd=max(0.15,str2double(answer{6}));
                % calculate psf sigma and dx and dy from psfwd
                psfsig = [psfwd,psfwd]/2.3548;  % sigma=FWHM/(2*sqrt(2*log(2)))
                dx=psfsig(1)/3;dy=psfsig(2)/3;  % x,y grid resolution
                
                % check if dx,dy is same as auto calculated
                inputdx=str2double(answer{7});
                inputdy=str2double(answer{8});
                if abs((inputdx-dx))>1e-5||abs((inputdy-dy))>1e-5
                    % make sure user specified overrides autocalculated
                    confirm=questdlg(sprintf('Are you sure you want to override auto calculated dx=%g, dy=%g to dx=%g, dy=%g?',dx,dy,inputdx,inputdy),'Double check dx dy','modal');
                    switch confirm
                        case 'Yes'
                            dx=inputdx;
                            dy=inputdy;
                        case 'Cancel'
                            message=sprintf('%s\nAction cancelled! Going back to double check dx and dy.',message);
                            return;
                    end
                end
                
                % get scan metainfo for easy access
                metainfo=obj.data(current_data).metainfo;
                
                % for multiple data ask for apply to all option
                if numel(selected_data)>1
                    askforparam=askapplyall('apply');
                end
            else
                % cancel clicked don't do anything to this data item
                metainfo=[];
            end
        else
            % user decided to apply same settings to rest or use default
            % assign parameters
            fname=defaultparam(1:2:end);
            fval=defaultparam(2:2:end);
            for fidx=1:numel(fname)
                val=char(fval{fidx});
                switch fname{fidx}
                    case 'newdata'
                        newdata=boolean(str2double(val));
                    case 'signaldataidx'
                        % signal data index in t channel
                        signaldataidx=str2double(val);
                    case 'scandataidx'
                        % scan data index in t channel
                        scandataidx=str2num(val);
                    case 'split_ROI'
                        % split_roi option
                        split_ROI=boolean(str2double(val));
                    case 'bglev'
                        % background intensity level
                        bglev=str2double(val);
                    case 'I_scaling'
                        % random scatter point number scaling
                        I_scaling=str2double(val);
                    case 'psfwd'
                        % point spread function fwhm 450nm
                        psfwd=str2double(val);
                        psfsig = [psfwd,psfwd]/2.3548;  % sigma=FWHM/(2*sqrt(2*log(2)))
                        % x,y grid resolution
                        dx=psfsig(1)/3;
                        dy=psfsig(2)/3;
                    case {'dx','dy'}
                        if ~isempty(val)
                            eval(sprintf('%s=%s;',fname{fidx},val));
                        end
                end
            end
            % get scan metainfo for easy access
            metainfo=obj.data(current_data).metainfo;
            % only use waitbar for user attention if we are in
            % automated mode
            if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
                % Report current estimate in the waitbar's message field
                done=data_idx/ndata;
                waitbar(done,waitbar_handle,sprintf('%3.1f%%',100*done));
            else
                % create waitbar if it doesn't exist
                waitbar_handle = waitbar(0,'Please wait...','Progress Bar','Calculating...',...
                    'CreateCancelBtn',...
                    'setappdata(gcbf,''canceling'',1)',...
                    'WindowStyle','normal',...
                    'Color',[0.2,0.2,0.2]);
                setappdata(waitbar_handle,'canceling',0);
            end
        end
        
        % ---- Data Calculation ----
        if isempty(metainfo)
            % decided to cancel action
            if numel(selected_data)>1
                askforparam=askapplyall('cancel');
                if askforparam==false
                    % quit if in automated mode
                    message=sprintf('%s\nAction cancelled!',message);
                    return;
                end
            else
                message=sprintf('%sAction cancelled!',message);
            end
        else
            % decided to process
            if newdata
                parent_data=current_data;
                % add new data
                obj.data_add(cat(2,'data_scanpos2img|',obj.data(parent_data).dataname),[],[]);
                % get new data index
                current_data=obj.current_data;
                % pass on datainfo
                obj.data(current_data).datainfo=obj.data(parent_data).datainfo;
                % pass on metadata info
                obj.data(current_data).metainfo=metainfo;
                % set data index
                obj.data(current_data).datainfo.data_idx=current_data;
                % set parent data index
                obj.data(current_data).datainfo.parent_data_idx=parent_data;
                T=obj.data(parent_data).datainfo.T;
                dT=obj.data(parent_data).datainfo.dT;
            else
                % get parent data index
                parent_data=obj.data(current_data).datainfo.parent_data_idx;
                T=obj.data(current_data).datainfo.T;
                dT=obj.data(current_data).datainfo.dT;
                if isempty(parent_data)
                    message=sprintf('%s\nMissing Parent Data. Check parent_data_idx field.',message);
                    return;
                end
            end
            %[ roiinfo ] = femtonics_scanline( obj.data(parent_data).metainfo );
            % calculate x boundary and bin edges
            xposdata=obj.data(parent_data).dataval(scandataidx(1),:,:,:,:);
            yposdata=obj.data(parent_data).dataval(scandataidx(2),:,:,:,:);
            xbound=[min(xposdata(:)),max(xposdata(:))];
            xedges=xbound(1)-dx:dx:xbound(2)+dx;
            imgx=diff(xedges)+xedges(1:end-1);imgx=imgx(:);
            % calculate y boundary and bin edges
            ybound=[min(yposdata(:)),max(yposdata(:))];
            yedges=ybound(1)-dy:dy:ybound(2)+dy;
            imgy=diff(yedges)+yedges(1:end-1);imgy=imgy(:);
            
            % initialise data holder to x,y,T
            recondata=zeros(numel(imgx),numel(imgy),obj.data(parent_data).datainfo.data_dim(5));
            % reconstruct image through each time frame
            % create waitbar if it doesn't exist
            waitbar_handle2 = waitbar(0,'Please wait...','Progress Bar','Calculating...',...
                'Name','Converting...',...
                'CreateCancelBtn',...
                'setappdata(gcbf,''canceling'',1)',...
                'WindowStyle','normal',...
                'Color',[0.2,0.2,0.2]);
            setappdata(waitbar_handle2,'canceling',0);
            barstep2=0;N_steps2=obj.data(parent_data).datainfo.data_dim(5);
            for tidx=1:N_steps2
                % get signal data slice
                sigdata=squeeze(obj.data(parent_data).dataval(signaldataidx,:,:,:,tidx))';
                % get x from scx
                xpos=squeeze(xposdata(:,:,:,:,tidx));
                % get y from scy
                ypos=squeeze(yposdata(:,:,:,:,tidx));
                % empty position data storage
                data=cell(numel(xpos),1);
                % generate psf
                for ptdataidx=1:numel(xpos)
                    % get mean position of psf
                    psfmu = [xpos(ptdataidx),ypos(ptdataidx)];
                    % make psf guasssian pdf
                    psfgm = gmdistribution(psfmu,psfsig);
                    % generate randome points
                    genpts=random(psfgm,round(max(1,I_scaling*(sigdata(ptdataidx)-bglev))));
                    % append points to list
                    data{ptdataidx}=genpts;
                end
                % make intensity distribution from point list data
                data=cell2mat(data);
                [Nphoton,~,~] = histcounts2(data(:,1),data(:,2),xedges,yedges);
                %{
                [Ndwell,Xedges,Yedges] = histcounts2(xposdata,yposdata,Xedges,Yedges);
                temp=Nphoton./Ndwell;
                temp(isnan(temp)|isinf(temp))=0;
                %}
                % assign to filterdata storage
                recondata(:,:,tidx)=Nphoton;
                % update waitbar
                % check waitbar
                if getappdata(waitbar_handle2,'canceling')
                    message=sprintf('%s\n%s calculation cancelled.',message,parameters.operator);
                    delete(waitbar_handle2);       % DELETE the waitbar; don't try to CLOSE it.
                    return;
                end
                % Report current estimate in the waitbar's message field
                done=tidx/N_steps2;
                if floor(100*done)>=barstep2
                    % update waitbar
                    waitbar(done,waitbar_handle2,sprintf('%g%%',barstep2));
                    barstep2=barstep2+1;
                end
            end
            % pass on information
            obj.data(current_data).datainfo.signaldataidx=signaldataidx;
            obj.data(current_data).datainfo.scandataidx=scandataidx;
            obj.data(current_data).datainfo.split_ROI=split_ROI;
            obj.data(current_data).datainfo.bglev=bglev;
            obj.data(current_data).datainfo.I_scaling=I_scaling;
            obj.data(current_data).datainfo.psfwd=psfwd;
            % pass on datavalue
            obj.data(current_data).dataval(1,:,:,1,:)=recondata;
            newsize=size(obj.data(current_data).dataval(1,:,:,1,:));
            obj.data(current_data).datainfo.operator='data_scanpos2img';
            obj.data(current_data).datainfo.bin_dim=[1,1,1,1,1];
            obj.data(current_data).datainfo.t=1;
            obj.data(current_data).datainfo.dt=1;
            obj.data(current_data).datainfo.X=imgx;
            obj.data(current_data).datainfo.dX=dx;
            obj.data(current_data).datainfo.Y=imgy;
            obj.data(current_data).datainfo.dY=dy;
            obj.data(current_data).datainfo.T=T;
            obj.data(current_data).datainfo.dT=dT;
            %redefine data type
            obj.data(current_data).datainfo.data_dim=newsize;
            obj.data(current_data).datatype=obj.get_datatype(current_data);
            obj.data(current_data).datainfo.last_change=datestr(now);
            message=sprintf('%s\nData %s to %s converted',message,num2str(parent_data),num2str(current_data));
            status=true;
        end
        % increment data index
        data_idx=data_idx+1;
    end
    
    %--------clean up------------------------
    % close waitbar if exist
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
     % close waitbar if exist
    if exist('waitbar_handle2','var')&&ishandle(waitbar_handle2)
        delete(waitbar_handle2);
    end
    %-------- error handle ----------------------
catch exception
    % delete waitbar if exist
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
    if exist('waitbar_handle2','var')&&ishandle(waitbar_handle2)
        delete(waitbar_handle2);
    end
    % output error message
    message=sprintf('%s\n%s',message,exception.message);
end