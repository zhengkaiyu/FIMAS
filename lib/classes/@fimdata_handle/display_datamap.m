function [ status, message ] = display_datamap( obj, fig_handle, varargin )
% display_datamap
% Input Argument:
%   fig_handle: is the handle object of GUI, if empty create new figure with
%               appropriate subplots positions
% Optional Input Argument:
%   data_idx: is the index of the data for plotting, if empty
%               current_data will be automatically selected
%   T_idx:
%   Z_idx:
%   notify:

%% function check
status=false;message='';
try
    % --- initialise parameters ---
    Pages=[];Slices=[];Parameters=[];
    notify=true;% default to notify pages and slices list
    % default to current data
    data_idx=obj.current_data(1);
    % get optional input if exist
    if nargin>2
        % get parameters argument
        parameters=varargin(1:2:end);
        % get value argument
        val=varargin(2:2:end);
        % loop through to assign input values
        for param_idx=1:numel(parameters)
            switch parameters{param_idx}
                case 'data_idx'
                    data_idx=val{param_idx};
                case 'P_idx'
                    % if specified parameter index
                    Parameters=val{param_idx};
                case 'T_idx'
                    % if specified T Page
                    Pages=val{param_idx};
                case 'Z_idx'
                    % if specify Z slice
                    Slices=val{param_idx};
                case 'notify'
                    notify=val{param_idx};
            end
        end
    end
    % get size of the data
    data_size=obj.data(data_idx).datainfo.data_dim;
    % Check for data existance
    if ~isempty(data_size)
        % There is data to plot
        if isempty(Pages)
            % not specified get default value
            Pages=1:1:data_size(5);% default to all T Page
        end
        if isempty(Slices)
            % not specified get default value
            Slices=1:1:data_size(4);% default to all Z slices
        end
        if isempty(Parameters)
            Parameters=1:1:data_size(1);% default to all parameter indices
        end
        
        % initialise figure handles if not specified
        if isempty(fig_handle)
            fig_handle=figure(997); % high enough to avoid existing figures
            fig_handle.PANEL_DATA_dt=subplot(fig_handle,5,4,[1,2]);
            fig_handle.PANEL_DATA_gT=subplot(5,4,[13,14]);
            fig_handle.PANEL_DATA_MAP=subplot(5,4,[5,6,9,10]);
            fig_handle.PANEL_RESULT_parameter=subplot(5,4,[3,4]);
            fig_handle.PANEL_RESULT_map=subplot(5,4,[7,8,11,12]);
            fig_handle.PANEL_RESULT_gT=subplot(5,4,[15,16]);
            fig_handle.PANEL_aux=subplot(5,4,[17]);
            notify=false; % reset notify as there will be no suitable output
        end
        % ------------------------------
        % --- Raw data plotting ---
        % depending on data type we have to do different things
        % avoid using nansum for raw data to increase speed
        switch obj.data(data_idx).datatype
            case 'DATA_SPC'
                % find dimension with more than one point
                pos_dim_idx=obj.data(data_idx).datainfo.data_dim>1;
                switch bin2dec(num2str(pos_dim_idx))%display decide on data dimension
                    case 28 %tXY
                        p=ind2sub(data_size(2)*data_size(3),obj.data(data_idx).dataval(:,1));
                        valimg=hist(p,1:1:data_size(2)*data_size(3));
                        valimg=reshape(valimg,[data_size(2),data_size(3),data_size(4),data_size(5)]);
                        clear p;
                        % --- 1D plot in dt ---
                        % choose t dim
                        %{
                        display_dim=[true,false,false,false,false];
                        % get display axis and label
                        [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                        valdt=double(reshape(valdt,[data_size(1),data_size(4),data_size(5)]));
                        display_data(valdt(:,1,Pages(1)),fig_handle.PANEL_DATA_dt,'line',disp_axis,axis_label,[data_size(4)>1,data_size(5)>1],data_idx);
                        set(fig_handle.PANEL_DATA_dt,'UserData',valdt);
                        %}
                        % --- 3D plot in XYZ ---
                        % tXYT(11101)
                        display_dim=[false,true,true,false,false];% plot XY
                        % get display options
                        [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                        obj.data(data_idx).datainfo.panel=fig_handle.PANEL_DATA_MAP;
                        % plot selected slices and pages
                        valimg=double(valimg);
                        display_data(valimg(:,:,Slices(1),Pages(1)),fig_handle.PANEL_DATA_MAP,'surf', disp_axis, axis_label,[data_size(4)>1,data_size(5)>1],[]);
                        set(fig_handle.PANEL_DATA_MAP,'UserData',valimg);
                        %end
                        % set Z and T options
                        if notify
                            %set Z slice options
                            set(fig_handle.MENU_DATA_Z,'String',obj.data(data_idx).datainfo.Z);
                            set(fig_handle.MENU_DATA_Z,'Value',Slices(1));
                            %set T page options
                            set(fig_handle.MENU_DATA_T,'String',obj.data(data_idx).datainfo.T);
                            set(fig_handle.MENU_DATA_T,'Value',Pages(1));
                        end
                        
                        % --- 1D plot in gT ---
                        display_dim=[false,false,true,false,false];%chose T dim
                        [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                        val=sum(valimg,1);
                        display_data(val(:,:),fig_handle.PANEL_DATA_gT,'line',disp_axis,axis_label,[data_size(4)>1,data_size(5)>1],data_idx);
                        set(fig_handle.PANEL_DATA_gT,'UserData',val);
                        
                        % set current data output panel handle
                        obj.data(data_idx).datainfo.panel=fig_handle.PANEL_DATA_MAP;
                    case 29 %tXYT
                        % get pixel/line/frame index
                        %[p,l,f]=ind2sub([data_size(2),data_size(3),data_size(5)],obj.data(data_idx).dataval(:,1));
                        [p,f]=ind2sub([data_size(2)*data_size(3),data_size(5)],obj.data(data_idx).dataval(:,1));
                        framenum=1:1:data_size(5);
                        % shrink data to XYT
                        %valimg=zeros(data_size(2),data_size(3),data_size(4),data_size(5),'uint16');
                        valimg=zeros(data_size(2)*data_size(3),data_size(4),data_size(5),'uint16');
                        %valdt=zeros(data_size(1),data_size(5),'uint16');
                        valimg(:,1,:)=hist3([p,f],{1:1:data_size(2)*data_size(3),framenum});
                        %{
                        for frame_ind=framenum
                            inframe=find(f==frame_ind);
                            valimg(:,:,1,frame_ind)=hist3([p(inframe),l(inframe)],{1:1:data_size(2),1:1:data_size(3)});
                            [valdt(:,frame_ind),~]=histc(obj.data(data_idx).dataval(inframe,2),obj.data(data_idx).datainfo.t);
                        end
                        %}
                        %clear f p l;
                        valimg=reshape(valimg,[data_size(2),data_size(3),data_size(4),data_size(5)]);
                        clear p f;
                        
                        % --- 1D plot in dt ---
                        % choose t dim
                        %{
                        display_dim=[true,false,false,false,false];
                        % get display axis and label
                        [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                        valdt=double(reshape(valdt,[data_size(1),data_size(4),data_size(5)]));
                        display_data(valdt(:,1,Pages(1)),fig_handle.PANEL_DATA_dt,'line',disp_axis,axis_label,[data_size(4)>1,data_size(5)>1],data_idx);
                        set(fig_handle.PANEL_DATA_dt,'UserData',valdt);
                        %}
                        % --- 3D plot in XYZ ---
                        % tXYT(11101)
                        display_dim=[false,true,true,false,false];% plot XY
                        % get display options
                        [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                        obj.data(data_idx).datainfo.panel=fig_handle.PANEL_DATA_MAP;
                        % plot selected slices and pages
                        valimg=double(valimg);
                        display_data(valimg(:,:,Slices(1),Pages(1)),fig_handle.PANEL_DATA_MAP,'surf', disp_axis, axis_label,[data_size(4)>1,data_size(5)>1],[]);
                        set(fig_handle.PANEL_DATA_MAP,'UserData',valimg);
                        %end
                        % set Z and T options
                        if notify
                            %set Z slice options
                            set(fig_handle.MENU_DATA_Z,'String',obj.data(data_idx).datainfo.Z);
                            set(fig_handle.MENU_DATA_Z,'Value',Slices(1));
                            %set T page options
                            set(fig_handle.MENU_DATA_T,'String',obj.data(data_idx).datainfo.T);
                            set(fig_handle.MENU_DATA_T,'Value',Pages(1));
                        end
                        
                        % --- 1D plot in gT ---
                        display_dim=[false,false,false,false,true];%chose T dim
                        [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                        val=reshape(sum(sum(valimg,1),2),[1,data_size(4),data_size(5)]);
                        display_data(val(:,Slices(1),:),fig_handle.PANEL_DATA_gT,'line',disp_axis,axis_label,[data_size(4)>1,data_size(5)>1],data_idx);
                        set(fig_handle.PANEL_DATA_gT,'UserData',val);
                        
                        % set current data output panel handle
                        obj.data(data_idx).datainfo.panel=fig_handle.PANEL_DATA_MAP;
                    otherwise
                end
                status=true;
            case 'DATA_IMAGE'    %nD image data
                % --- 1D plot in dt ---
                % choose t dim
                display_dim=[true,false,false,false,false];
                % get display axis and label
                [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                % reduce dimension to singleton for summation
                val=reshape(obj.data(data_idx).dataval,[data_size(1),prod(data_size(2:3)),data_size(4),data_size(5)]);
                % reduce XYZ dimension to t-T
                val=reshape(sum(val,2),[data_size(1),data_size(4),data_size(5)]);
                %plot the T(1) and save t-T to userdata
                display_data(val(:,Slices(1),Pages(1)),fig_handle.PANEL_DATA_dt,'line',disp_axis,axis_label,[data_size(4)>1,data_size(5)>1],data_idx);
                set(fig_handle.PANEL_DATA_dt,'UserData',val);
                
                % --- 1D plot in gT ---
                display_dim=[false,false,false,false,true];%chose T dim
                [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                val=reshape(sum(val,1),[1,data_size(4),data_size(5)]);
                display_data(val(:,Slices(1),:),fig_handle.PANEL_DATA_gT,'line',disp_axis,axis_label,[data_size(4)>1,data_size(5)>1],data_idx);
                set(fig_handle.PANEL_DATA_gT,'UserData',val);
                
                % --- 3D plot in XYZ ---
                % find dimension with more than one point
                pos_dim_idx=obj.data(data_idx).datainfo.data_dim>1;
                switch bin2dec(num2str(pos_dim_idx))%display decide on data dimension
                    case {12,9,17,5}
                        % 2D data
                        % XY(01100)/XT(01001)/tT(10001)/YT(00101)
                        display_dim=pos_dim_idx;% plot 2D
                        % shrink data to 2D
                        val=squeeze(obj.data(data_idx).dataval);
                        % no Z or T seq
                        data_size(4)=1;data_size(5)=1;
                    case 28
                        % tXY(11100)
                        display_dim=[false,true,true,false,false];%  plot XY
                        % reduce t dim to get intensity XY data
                        val=squeeze(sum(obj.data(data_idx).dataval,1));
                    case 25
                        % tXT(11001)
                        % most likly CXT data
                        display_dim=[true,true,false,false,false]; % plot tX
                        % get 3D value
                        val=reshape(obj.data(data_idx).dataval,[data_size(1),data_size(2),data_size(4),data_size(5)]);
                    case 11
                        % XZT(01011)
                        % most likely XCT
                        display_dim=[false,true,false,false,true];% plot XT
                        % reduce to get intensity XT data and swap Z-T
                        val=permute(squeeze(obj.data(data_idx).dataval),[1,3,2]);
                        % plot XT
                        data_size(5)=1; % we are plot T, Tseq is false
                    case 14
                        % XYZ(01110)
                        display_dim=[false,true,true,false,false];% plot XY
                        % select the right Z slice
                        val=squeeze(obj.data(data_idx).dataval);
                    case 13
                        % XYT(01101)
                        display_dim=[false,true,true,false,false];% plot XY
                        % select the right T Pages
                        val=reshape(obj.data(data_idx).dataval,[data_size(2),data_size(3),data_size(4),data_size(5)]);
                    case 29
                        % tXYT(11101)
                        display_dim=[false,true,true,false,false];% plot XY
                        % shrink data to XYT
                        val=reshape(sum(obj.data(data_idx).dataval,1),[data_size(2),data_size(3),data_size(4),data_size(5)]);
                    case 30
                        % tXYZ(11110)
                        % most likely CXYZ data
                        display_dim=[false,true,true,false,false];% plot XY
                        % shrink data to XYZ
                        val=squeeze(sum(obj.data(data_idx).dataval,1));
                    case 15
                        % XYZT(01111)
                        display_dim=[false,true,true,false,false];% plot XY
                        % select the right Z slices and T Pages
                        val=squeeze(obj.data(data_idx).dataval);
                    case 31
                        % tXYZT(11111)
                        display_dim=[false,true,true,false,false];% plot XY
                        % select the right Z slices and T Pages
                        val=squeeze(sum(obj.data(data_idx).dataval,1));
                    otherwise
                        val=[];
                end
                %if ~isempty(val)
                % get display options
                [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                obj.data(data_idx).datainfo.panel=fig_handle.PANEL_DATA_MAP;
                % plot selected slices and pages
                display_data(val(:,:,Slices(1),Pages(1)),fig_handle.PANEL_DATA_MAP,'surf', disp_axis, axis_label,[data_size(4)>1,data_size(5)>1],[]);
                set(fig_handle.PANEL_DATA_MAP,'UserData',val);
                %end
                % set Z and T options
                if notify
                    %set Z slice options
                    set(fig_handle.MENU_DATA_Z,'String',obj.data(data_idx).datainfo.Z);
                    set(fig_handle.MENU_DATA_Z,'Value',Slices(1));
                    %set T page options
                    set(fig_handle.MENU_DATA_T,'String',obj.data(data_idx).datainfo.T);
                    set(fig_handle.MENU_DATA_T,'Value',Pages(1));
                end
                % set current data output panel handle
                obj.data(data_idx).datainfo.panel=fig_handle.PANEL_DATA_MAP;
                status=true;
            case 'DATA_TRACE'
                % find dimension with more than one point
                display_dim=obj.data(data_idx).datainfo.data_dim>1;
                switch find(display_dim)
                    case 1%dt
                        [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                        display_data(squeeze(obj.data(data_idx).dataval),fig_handle.PANEL_DATA_dt,'line',disp_axis,axis_label,[false,false],data_idx);
                    case 5%gT
                        [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                        display_data(squeeze(obj.data(data_idx).dataval),fig_handle.PANEL_DATA_gT,'line',disp_axis,axis_label,[false,false],data_idx);
                    case {2,3,4}%X/Y/Z
                        [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                        display_data(squeeze(obj.data(data_idx).dataval),fig_handle.PANEL_DATA_dt,'line',disp_axis,axis_label,[false,false],data_idx);
                end
            case 'DATA_POINT'
                % find dimension with more than one point
                message=sprintf('val = %g\n',squeeze(obj.data(data_idx).dataval));
                %--------------------------------------------------------
                %---------------------------------------------------------
            case 'RESULT_IMAGE'
                % --- 1D plot in gT ---
                display_dim=[false,false,false,false,true];%chose T dim
                [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                val=reshape(obj.data(data_idx).dataval,[data_size(1),data_size(2)*data_size(3),data_size(4),data_size(5)]);
                val=reshape(sum(val,2),[data_size(1),1,1,data_size(4),data_size(5)]);
                display_data(val(Parameters(1),:,:,Slices(1),:),fig_handle.PANEL_RESULT_gT,'line',disp_axis,axis_label,[data_size(4)>1,data_size(5)>1],data_idx);
                set(fig_handle.PANEL_RESULT_gT,'UserData',val);
                
                % --- 3D plot in XYZ ---
                % find dimension with more than one point
                pos_dim_idx=obj.data(data_idx).datainfo.data_dim>1;
                val_scalemap=[];
                % get display options
                [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                switch bin2dec(num2str(pos_dim_idx))%display decide on data dimension
                    
                    case 12
                        % XY(01100)
                        % colour scale map from ancester
                        display_dim=pos_dim_idx;% plot 2D
                        % shrink data to 2D
                        val=(obj.data(data_idx).dataval);
                        % no Z or T seq
                        data_size(4)=1;
                        val_scalemap=obj.generate_colourmap(fig_handle.PANEL_RESULT_MAP);
                    case {12,9,17,5}
                        % 2D data    %tT(10001)
                        % XT(01001)/YT(00101)
                        display_dim=pos_dim_idx;% plot 2D
                        % shrink data to 2D
                        val=squeeze(obj.data(data_idx).dataval);
                        % no Z or T seq
                        data_size(4)=1;data_size(5)=1;
                    case 28
                        % tXY(11100)
                        display_dim=[false,true,true,false,false];%  plot XY
                        % reduce t dim to get intensity XY data
                        val=(sum(obj.data(data_idx).dataval,1));
                        % colour scale map from ancester
                        val_scalemap=obj.generate_colourmap(fig_handle.PANEL_RESULT_MAP);
                    case 25
                        % tXT(11001)
                        % most likly CXT data
                        display_dim=[true,true,false,false,false]; % plot tX
                        % get 3D value
                        val=reshape(obj.data(data_idx).dataval,[data_size(1),data_size(2),data_size(4),data_size(5)]);
                        % colour scale map from ancester
                        val_scalemap=obj.generate_colourmap(fig_handle.PANEL_RESULT_MAP);
                    case 11
                        % XZT(01011)
                        % most likely XCT
                        display_dim=[false,true,false,false,true];% plot XT
                        % reduce to get intensity XT data and swap Z-T
                        val=permute(squeeze(obj.data(data_idx).dataval),[1,3,2]);
                        % plot XT
                        data_size(5)=1; % we are plot T, Tseq is false
                    case 14
                        % XYZ(01110)
                        display_dim=[false,true,true,false,false];% plot XY
                        % select the right Z slice
                        val=(obj.data(data_idx).dataval);
                    case 13
                        % XYT(01101)
                        display_dim=[false,true,true,false,false];% plot XY
                        % select the right T Pages
                        val=reshape(obj.data(data_idx).dataval,[data_size(1),data_size(2),data_size(3),data_size(4),data_size(5)]);
                    case 29
                        % tXYT(11101)
                        display_dim=[false,true,true,false,false];% plot XY
                        % shrink data to XYT
                        val=reshape(sum(obj.data(data_idx).dataval,1),[data_size(1),data_size(2),data_size(3),data_size(4),data_size(5)]);
                        % colour scale map from ancester
                        val_scalemap=obj.generate_colourmap(fig_handle.PANEL_RESULT_MAP);
                    case 30
                        % tXYZ(11110)
                        % most likely CXYZ data
                        display_dim=[false,true,true,false,false];% plot XY
                        % shrink data to XYZ
                        val=(sum(obj.data(data_idx).dataval,1));
                        % colour scale map from ancester
                        val_scalemap=obj.generate_colourmap(fig_handle.PANEL_RESULT_MAP);
                    case 15
                        % XYZT(01111)
                        display_dim=[false,true,true,false,false];% plot XY
                        % select the right Z slices and T Pages
                        val=(obj.data(data_idx).dataval);
                end
                [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                
                % plot selected slices and pages
                % check for mod_surf or surf
                if isempty(val_scalemap)
                    display_data(val(:,:,:,Slices(1),Pages(1)),fig_handle.PANEL_RESULT_MAP,'surf', disp_axis, axis_label,[data_size(4)>1,data_size(5)>1],[]);
                    set(fig_handle.PANEL_RESULT_MAP,'UserData',val);
                else
                    display_data({val(Parameters(1),:,:,Slices(1),Pages(1)),val_scalemap(1,:,:,Slices(1),Pages(1),1:3)},fig_handle.PANEL_RESULT_MAP,'mod_surf', disp_axis, axis_label,[data_size(4)>1,data_size(5)>1],[]);
                    set(fig_handle.PANEL_RESULT_MAP,'UserData',{val,val_scalemap});
                end
                
                % set Z and T options
                if notify
                    %set Z slice options
                    set(fig_handle.MENU_RESULT_Z,'String',obj.data(data_idx).datainfo.Z);
                    set(fig_handle.MENU_RESULT_Z,'Value',Slices(1));
                    %set T page options
                    set(fig_handle.MENU_RESULT_T,'String',obj.data(data_idx).datainfo.T);
                    set(fig_handle.MENU_RESULT_T,'Value',Pages(1));
                    %set T page options
                    pstr=get_parameterspace(obj.data(data_idx).datainfo.parameter_space);
                    set(fig_handle.MENU_PARAMETER,'String',pstr);
                    set(fig_handle.MENU_PARAMETER,'Value',Parameters(1));
                end
                % set current data output panel handle
                obj.data(data_idx).datainfo.panel=fig_handle.PANEL_RESULT_MAP;
                status=true;
            case 'RESULT_TRACE'
                % find dimension with more than one point
                display_dim=obj.data(data_idx).datainfo.data_dim>1;
                switch find(display_dim)
                    case 1%dt
                        [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                        display_data(squeeze(obj.data(data_idx).dataval),fig_handle.PANEL_RESULT_param,'line',disp_axis,axis_label,[false,false],data_idx);
                    case 5%gT
                        [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                        display_data(squeeze(obj.data(data_idx).dataval),fig_handle.PANEL_RESULT_gT,'line',disp_axis,axis_label,[false,false],data_idx);
                    case {2,3,4}%X/Y/Z
                        [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                        display_data(squeeze(obj.data(data_idx).dataval),fig_handle.PANEL_RESULT_param,'line',disp_axis,axis_label,[false,false],data_idx);
                end
            case 'RESULT_POINT'
                display_dim=[];
                [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                display_data(squeeze(obj.data(data_idx).dataval),fig_handle.PANEL_RESULT_param,'scatter',disp_axis,axis_label,[false,false],data_idx);
            case 'RESULT_PHASOR'
                display_dim=[];
                pos_dim_idx=obj.data(data_idx).datainfo.data_dim>1;
                % get display options
                [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                switch bin2dec(num2str(pos_dim_idx))%display decide on data dimension
                    case {16}
                        % 0D data    %t(10000)
                        display_dim=pos_dim_idx;% plot 2D
                        % shrink data to 2D
                        val=obj.data(data_idx).dataval;
                        % no Z or T seq
                        data_size(4)=1;data_size(5)=1;
                        display_data(val(:,:,:,1,1),fig_handle.PANEL_RESULT_param,'phasor_scatter',disp_axis,axis_label,[data_size(4)>1,data_size(5)>1],data_idx);
                        set(fig_handle.PANEL_RESULT_param,'UserData',val);
                        obj.data(data_idx).datainfo.panel=fig_handle.PANEL_RESULT_param;
                        
                        % --- 1D plot in gT ---
                        display_dim=[false,false,false,false,true];%chose T dim
                        d1dval=reshape(obj.data(data_idx).dataval,[data_size(1),data_size(2)*data_size(3),data_size(4),data_size(5)]);
                        d1dval=reshape(sum(d1dval,2),[data_size(1),1,1,data_size(4),data_size(5)]);
                        bary_val = cart2bary(squeeze(d1dval),disp_axis{1});
                        [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                        bary_val=reshape(bary_val,[3,1,1,1,data_size(5)]);
                        display_data(bary_val(:,:,:,1,1),fig_handle.PANEL_RESULT_gT,'line',{[1,2,3]},axis_label,[false,false],data_idx);
                        set(fig_handle.PANEL_RESULT_gT,'UserData',bary_val);
                    case {17}
                        % 1D data    %tT(10001)
                        display_dim=pos_dim_idx;% plot 2D
                        % shrink data to 2D
                        val=obj.data(data_idx).dataval;
                        % no Z or T seq
                        data_size(4)=1;data_size(5)=size(val,5);
                        % plot selected slices and pages
                        display_data(val(:,:,:,Slices(1),Pages(1)),fig_handle.PANEL_RESULT_param,'phasor_scatter',disp_axis,axis_label,[data_size(4)>1,data_size(5)>1],data_idx);
                        set(fig_handle.PANEL_RESULT_param,'UserData',val);
                        obj.data(data_idx).datainfo.panel=fig_handle.PANEL_RESULT_param;
                        
                        % --- 1D plot in gT ---
                        display_dim=[false,false,false,false,true];%chose T dim
                        d1dval=reshape(obj.data(data_idx).dataval,[data_size(1),data_size(2)*data_size(3),data_size(4),data_size(5)]);
                        d1dval=reshape(sum(d1dval,2),[data_size(1),1,1,data_size(4),data_size(5)]);
                        bary_val = cart2bary(squeeze(d1dval),disp_axis{1});
                        [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                        bary_val=reshape(bary_val,[3,1,1,1,data_size(5)]);
                        display_data(bary_val(Parameters(1),:,:,Slices(1),:),fig_handle.PANEL_RESULT_gT,'line',disp_axis,axis_label,[data_size(4)>1,data_size(5)>1],data_idx);
                        set(fig_handle.PANEL_RESULT_gT,'UserData',bary_val);
                end
                % set Z and T options
                if notify
                    %set Z slice options
                    set(fig_handle.MENU_RESULT_Z,'String',obj.data(data_idx).datainfo.Z);
                    set(fig_handle.MENU_RESULT_Z,'Value',Slices(1));
                    %set T page options
                    set(fig_handle.MENU_RESULT_T,'String',obj.data(data_idx).datainfo.T);
                    set(fig_handle.MENU_RESULT_T,'Value',Pages(1));
                    %set T page options
                    pstr=get_parameterspace(obj.data(data_idx).datainfo.parameter_space);
                    set(fig_handle.MENU_PARAMETER,'String',pstr);
                    set(fig_handle.MENU_PARAMETER,'Value',Parameters(1));
                end
                status=true;
            case 'RESULT_PHASOR_MAP'
                display_dim=[];
                pos_dim_idx=obj.data(data_idx).datainfo.data_dim>1;
                % get display options
                [ axis_label, disp_axis ] = obj.get_displaydata( data_idx, display_dim );
                
                display_dim=pos_dim_idx;% plot 2D
                % shrink data to 2D
                val=obj.data(data_idx).dataval;
                % no Z or T seq
                data_size(4)=1;data_size(5)=size(val,5);
                % plot selected slices and pages
                display_data(val(:,:,:,Slices(1),Pages(1)),fig_handle.PANEL_RESULT_param,'phasor_map',disp_axis,axis_label,[data_size(4)>1,data_size(5)>1],data_idx);
                set(fig_handle.PANEL_RESULT_param,'UserData',val);
                obj.data(data_idx).datainfo.panel=fig_handle.PANEL_RESULT_param;
                % set Z and T options
                if notify
                    %set Z slice options
                    set(fig_handle.MENU_RESULT_Z,'String',obj.data(data_idx).datainfo.Z);
                    set(fig_handle.MENU_RESULT_Z,'Value',Slices(1));
                    %set T page options
                    set(fig_handle.MENU_RESULT_T,'String',obj.data(data_idx).datainfo.T);
                    set(fig_handle.MENU_RESULT_T,'Value',Pages(1));
                    %set T page options
                    pstr=get_parameterspace(obj.data(data_idx).datainfo.parameter_space);
                    set(fig_handle.MENU_PARAMETER,'String',pstr);
                    set(fig_handle.MENU_PARAMETER,'Value',Parameters(1));
                end
        end
        %enable roi related to current data
        obj.roi_add('show');
        message=sprintf('data displayed\n%s',message);
    else
        % no data size indicate no data
        message=sprintf('no data to display\n');
    end
catch exception
    % error handling
    message=[exception.message,data2clip(exception.stack)];
    errordlg(sprintf('%s\n',message));
end