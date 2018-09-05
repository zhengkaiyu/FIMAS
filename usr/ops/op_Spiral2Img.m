function [ status, message ] = op_Spiral2Img( data_handle, option, varargin )
%op_Spiral2Img converts spiral/tornado linescan into standard XY images
% --- Function Library ---

parameters=struct('note','',...
    'operator','op_Spiral2Img',...
    'ref_scanline',[],...
    'bin_dim',[1,1,1,1,1],...
    'grid_interp_size',1,...
    'grid_interp','linear');

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
                    case {'DATA_IMAGE','RESULT_IMAGE'}
                        % check data dimension, we only take tXT
                        switch bin2dec(num2str(data_handle.data(current_data).datainfo.data_dim>1))
                            case {9,25,24}
                                %XT (01001), tXT (11001), tX (11000)
                                parent_data=current_data;
                                % add new data
                                data_handle.data_add(cat(2,'op_Spiral2Img|',data_handle.data(current_data).dataname),[],[]);
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
                                % pass on metadata info
                                data_handle.data(new_data).metainfo=data_handle.data(parent_data).metainfo;
                                message=sprintf('%s added\n',data_handle.data(new_data).dataname);
                                status=true;
                            otherwise
                                message=sprintf('only take tXT, XT, tX NON-SPC format data type\n');
                                errordlg(message,'Check selection','modal');
                                return;
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
                    case 'ref_scanline'
                        status=false;
                        % ask for ref .mat file or ref data item
                        orig_ref= data_handle.data(current_data).datainfo.ref_scanline;
                        set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
                        set(0,'DefaultUicontrolForegroundColor','k');
                        % ask to select dataitem
                        [s,v]=listdlg('ListString',{data_handle.data.dataname},...
                            'SelectionMode','single',...
                            'Name','op_Spiral2Img',...
                            'PromptString','Select scanref data item',...
                            'ListSize',[400,300]);
                        set(0,'DefaultUicontrolBackgroundColor','k');
                        set(0,'DefaultUicontrolForegroundColor','w');
                        if v
                            % check if scanline field exist
                            if isfield(data_handle.data(s).datainfo,'ScanLine')
                                data_handle.data(current_data).datainfo.ref_scanline=data_handle.data(s).datainfo.ScanLine;
                                message=sprintf('Scanline information loaded from %s\n',data_handle.data(s).dataname);
                            else
                                errordlg('Selected dataitem has now ScanLine information','Check selection','modal');
                            end
                        else
                            % didn't change
                            data_handle.data(current_data).datainfo.ref_scanline=orig_ref;
                        end
                    case 'grid_interp_size'
                        % ask to select dataitem
                        button = questdlg(sprintf('grid interpolation factor?\nChoose 1 for no interpolation'),'Grid Interpolation','1','2','3','1');
                        switch button
                            case ''
                                message=sprintf('%scancelled %s change\n',message,parameters);
                            otherwise
                                data_handle.data(current_data).datainfo.grid_interp_size=str2double(button);
                        end
                    case 'grid_interp'
                        % ask to select dataitem
                        button = questdlg('grid interpolation method?','Grid Interpolation','linear','cubic','spline','none');
                        switch button
                            case ''
                                message=sprintf('%scancelled %s change\n',message,parameters);
                            otherwise
                                data_handle.data(current_data).datainfo.grid_interp=char(button);
                        end
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
            for current_data=data_idx
                % go through each selected data
                parent_data=data_handle.data(current_data).datainfo.parent_data_idx;
                if isstruct(data_handle.data(current_data).datainfo.ref_scanline)
                    % has scanlin ref information
                    switch data_handle.data(parent_data).datatype
                        case {'DATA_IMAGE','RESULT_IMAGE'}%originated from 3D/4D traces_image
                            scaninfo=data_handle.data(current_data).datainfo.ref_scanline;
                            nscanpts=size(scaninfo.Data1,2);%get scanline info size
                            linescan_size=data_handle.data(parent_data).datainfo.data_dim(2);%get line scan X size
                            dwellpoint=downsample(scaninfo.Data1(1:2,:)',max(round(nscanpts/linescan_size),1));%downsize
                            dwellpoint=dwellpoint(1:linescan_size,:);%match size to linescan data
                            unit_len=data_handle.data(parent_data).datainfo.dX;
                            xlim=min(dwellpoint(:,1)):unit_len:max(dwellpoint(:,1));%get new x grid
                            xsize=numel(xlim);
                            ylim=min(dwellpoint(:,2)):unit_len:max(dwellpoint(:,2));%get new y grid
                            ysize=numel(ylim);
                            % parent dimension size
                            dim_size=data_handle.data(parent_data).datainfo.data_dim;
                            %initialise new 5D data
                            temp=zeros(dim_size(1),xsize,ysize,dim_size(4),dim_size(5));
                            [~,~,~,xbin,ybin]=histcounts2(dwellpoint(:,1),dwellpoint(:,2),[xsize,ysize]);
                            for pt_idx=1:linescan_size
                                temp(:,xbin(pt_idx),ybin(pt_idx),1,:)=temp(:,xbin(pt_idx),ybin(pt_idx),1,:)+data_handle.data(parent_data).dataval(:,pt_idx,:,1,:);
                            end
                            data_handle.data(current_data).dataval=[];
                            switch data_handle.data(current_data).datainfo.grid_interp_size
                                case 1
                                    data_handle.data(current_data).dataval=temp;
                                otherwise
                                    Tlim=data_handle.data(parent_data).datainfo.T;
                                    div=data_handle.data(current_data).datainfo.grid_interp_size;
                                    switch bin2dec(num2str(data_handle.data(current_data).datainfo.data_dim>1))
                                        case 9
                                            %XT (01001)
                                            F = griddedInterpolant({xlim,ylim,Tlim},squeeze(temp(1,:,:,1,:)),'spline');
                                            xlim=min(dwellpoint(:,1)):unit_len/div:max(dwellpoint(:,1));%get new x grid
                                            ylim=min(dwellpoint(:,2)):unit_len/div:max(dwellpoint(:,2));%get new y grid
                                            data_handle.data(current_data).dataval(1,:,:,1,:)=F({xlim,ylim,Tlim});
                                        case 25
                                            %tXT (11001)
                                            tlim=data_handle.data(parent_data).datainfo.t;
                                            F = griddedInterpolant({tlim,xlim,ylim,Tlim},squeeze(temp(:,:,:,1,:)),'spline');
                                            xlim=min(dwellpoint(:,1)):unit_len/div:max(dwellpoint(:,1));%get new x grid
                                            ylim=min(dwellpoint(:,2)):unit_len/div:max(dwellpoint(:,2));%get new y grid
                                            data_handle.data(current_data).dataval(:,:,:,1,:)=F({tlim,xlim,ylim,Tlim});
                                            data_handle.data(current_data).datainfo.t=tlim;
                                        case 24
                                            %tX (11000)
                                            tlim=data_handle.data(parent_data).datainfo.t;
                                            F = griddedInterpolant({tlim,xlim,ylim},squeeze(temp(:,:,:,1,1)),'spline');
                                            xlim=min(dwellpoint(:,1)):unit_len/div:max(dwellpoint(:,1));%get new x grid
                                            ylim=min(dwellpoint(:,2)):unit_len/div:max(dwellpoint(:,2));%get new y grid
                                            data_handle.data(current_data).dataval(:,:,:,1,1)=F({tlim,xlim,ylim});
                                            data_handle.data(current_data).datainfo.t=tlim;
                                    end
                                    %figure(10);mesh(X1,Y1,squeeze(mean(temp,5)),'FaceColor','interp','EdgeColor','none');view([0 90]);
                                    %figure(11);mesh(X2,Y2,squeeze(mean(V,3)),'FaceColor','interp','EdgeColor','none');view([0 90]);
                            end
                            % work out new data size
                            new_dim_size=size(data_handle.data(current_data).dataval);
                            dim_size(2:3)=new_dim_size(2:3);%only change x and y size
                            data_handle.data(current_data).datainfo.X=xlim;
                            data_handle.data(current_data).datainfo.dX=xlim(2)-xlim(1);
                            data_handle.data(current_data).datainfo.Y=ylim;
                            data_handle.data(current_data).datainfo.dY=ylim(2)-ylim(1);
                            data_handle.data(current_data).datainfo.data_dim=dim_size;
                            data_handle.data(current_data).datatype='DATA_IMAGE';
                            data_handle.data(current_data).datainfo.last_change=datestr(now);
                            status=true;
                            message=sprintf('%s spiral line scan converted to normal images\n',message);
                    end
                else
                    errordlg(sprintf('Load ScanLine information first.\nGo to the bottome of the datainfo table.\nChange the value in ref_scanline field to invoke list dialogue.\n'),'Check ref_scanline','modal');
                end
            end
            status=true;
    end
catch exception
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
    message=exception.message;
end