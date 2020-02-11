function [ data, status, message ] = roi_calc( obj, roi_idx, parameter )
%ROI_CALC Summary of this function goes here
%   Detailed explanation goes here


%% function check

% asnanmeane worst
status=false;
message='';data=[];
try
    current_data=obj.current_data;
    
    % work out pixel indices
    if isempty(roi_idx)
        current_roi=obj.data(current_data).current_roi;
    else
        current_roi=roi_idx;
    end
    
    if find(current_roi==1)
        %all inclusive of other roi so ignore others
        pixel_idx=obj.data(current_data).roi(current_roi).idx;
        if isempty(pixel_idx)
            pixel_idx=1:1:numel(obj.data(current_data).datainfo.(char(obj.DIM_TAG(obj.data(current_data).datainfo.data_dim>1))));
        end
    else
        %roi
        pixel_idx=unique(cell2mat({obj.data(current_data).roi(current_roi).idx}'));
    end
    
    if ~isempty(pixel_idx)
        % find dimension with more than one point
        pos_dim_idx=obj.data(current_data).datainfo.data_dim>1;
        switch obj.data(current_data).datatype
            case 'DATA_SPC'
                message=sprintf('roi_calculation for spc data\n');
                switch parameter
                    case 'trace'
                        % asked for data trace to be calculated
                        status=true;
                        data=cell(2,3);
                        message=sprintf('roi trace calculated\n');
                        switch bin2dec(num2str(pos_dim_idx))%display decide on data dimension
                            case 17
                                % tT(10001)
                                
                            case 28
                                % tXY(11100)
                                % display in t dimension
                                display_dim=[true,false,false,false,false];
                                [ data{1,3}, data{1,2} ] = obj.get_displaydata( current_data, display_dim );
                                data_size=obj.data(current_data).datainfo.data_dim;
                                
                                % get pixel/line index
                                loc=ismember(obj.data(current_data).dataval(:,1),pixel_idx);
                                roidata=obj.data(current_data).dataval(loc,2);
                                % shrink data to XYT
                                [valdt,~]=histc(roidata,obj.data(current_data).datainfo.t);
                                clear p;
                                data{1,1}=reshape(valdt',[data_size(1),1,1,data_size(4),data_size(5)]);
                            case 29
                                % tXYT(11101)
                                % display in t dimension
                                display_dim=[true,false,false,false,false];
                                [ data{1,3}, data{1,2} ] = obj.get_displaydata( current_data, display_dim );
                                data_size=obj.data(current_data).datainfo.data_dim;
                                
                                % get pixel/line/frame index
                                [p,f]=ind2sub([data_size(2)*data_size(3),data_size(5)],obj.data(current_data).dataval(:,1));
                                loc=ismember(p,pixel_idx);
                                roidata=obj.data(current_data).dataval(loc,2);
                                f=f(loc);
                                % shrink data to XYT
                                [valdt,~]=hist3([f,roidata],{1:1:data_size(5),obj.data(current_data).datainfo.t});
                                clear f p;
                                data{1,1}=reshape(valdt',[data_size(1),1,1,data_size(4),data_size(5)]);
                                
                                % display in T dimension
                                display_dim=[false,false,false,false,true];
                                [ data{2,3}, data{2,2} ] = obj.get_displaydata( current_data, display_dim );
                                data{2,1}=squeeze(nanmean(data{1,1},1));
                            case 31
                                % tXYZT(11111)
                                
                            otherwise
                                status=false;
                                message=sprintf('does not know how to calculate roi trace for this data type yet\n');
                        end
                        
                    case 'histogram'
                        % histogram for all pixel intensity values
                        status=true;
                        message=sprintf('roi histogram calculated\n');
                        switch bin2dec(num2str(pos_dim_idx))%display decide on data dimension
                            case {1,2,4,8,16}
                                % T/Z/Y/X/t traces
                                
                                
                            case 17
                                % tT(10001)
                                
                            case 28
                                % tXY(11100)
                                
                            case 29
                                % tXYT(11101)
                                
                            case 31
                                % tXYZT(11111)
                                
                            otherwise
                                status=false;
                                message=sprintf('does not know how to calculate roi histogram for this data type yet\n');
                                
                        end
                    case 'dist2d'
                        
                    otherwise
                        message=sprintf('Unknown option %s for roi_calculation\n',parameter);
                end
            case 'RESULT_PHASOR_MAP'
                if obj.data(current_data).current_roi>1
                    parent_data=obj.data(current_data).datainfo.parent_data_idx;
                    datasize=obj.data(parent_data).datainfo.data_dim;
                    for roiidx=1:numel(current_roi)
                        roicoord=[];
                        % find location of phasor in the roi
                        switch obj.data(current_data).roi(current_roi(roiidx)).type
                            case 'impoly'
                                roicoord(:,1)=obj.data(current_data).roi(current_roi(roiidx)).coord(:,1);
                                roicoord(:,2)=obj.data(current_data).roi(current_roi(roiidx)).coord(:,2);
                            case 'imrect'
                                %{
                                xpt1=obj.data(current_data).roi(current_roi(roiidx)).coord(1,1);
                                xpt2=obj.data(current_data).roi(current_roi(roiidx)).coord(1,1)+obj.data(current_data).roi(current_roi(roiidx)).coord(1,3);
                                ypt1=obj.data(current_data).roi(current_roi(roiidx)).coord(1,2);
                                ypt2=obj.data(current_data).roi(current_roi(roiidx)).coord(1,2)+obj.data(current_data).roi(current_roi(roiidx)).coord(1,4);
                                roicoord=[xpt1,ypt1;xpt2,ypt1;xpt2,ypt2;xpt1,ypt2];
                                %}
                                roicoord=obj.data(current_data).roi(current_roi(roiidx)).coord;
                            case 'impoint'
                                xcoord=obj.data(current_data).roi(current_roi(roiidx)).coord(:,1);
                                ycoord=obj.data(current_data).roi(current_roi(roiidx)).coord(:,2);
                                nnn=floor(sqrt(numel(obj.data(current_data).roi(current_roi(roiidx)).idx)))-1;
                                dX=nnn*(obj.data(current_data).datainfo.X_disp_bound(2)-obj.data(current_data).datainfo.X_disp_bound(1))/obj.data(current_data).datainfo.X_disp_bound(3);
                                dY=nnn*(obj.data(current_data).datainfo.Y_disp_bound(2)-obj.data(current_data).datainfo.Y_disp_bound(1))/obj.data(current_data).datainfo.Y_disp_bound(3);
                                xpt1=xcoord-dX;
                                xpt2=xcoord+dX;
                                ypt1=ycoord-dY;
                                ypt2=ycoord+dY;
                                roicoord=[xpt1,ypt1;xpt2,ypt1;xpt2,ypt2;xpt1,ypt2];
                            case 'imellipse'
                                roicoord=obj.data(current_data).roi(current_roi(roiidx)).coord;
                        end
                        loc=inpolygon(obj.data(current_data).dataval(1,:)',obj.data(current_data).dataval(2,:)',roicoord(:,1),roicoord(:,2));
                        % original datamap size
                        ind{roiidx}=find(loc);
                    end
                    ind=unique(cell2mat(ind(:)));
                    if isempty(ind)
                        message=sprintf('Phasor map data is empty for ROI/s, nothing to show');
                        status=false;
                    else
                        temp=zeros(datasize(2),datasize(3));
                        temp(ind)=squeeze(sum(obj.data(parent_data).dataval(:,ind),1));
                        [ axis_label, disp_axis ] = obj.get_displaydata( parent_data, [false,true,true,false,false]);
                        global SETTING;
                        %colourlabel=current_roi*(255/numel(obj.data(current_data).roi));
                        display_data(temp,SETTING.panel(7).handle,'surf', disp_axis, axis_label,[datasize(4)>1,datasize(5)>1],current_roi);
                        %display_data(temp,[],'surf', disp_axis, axis_label,[datasize(4)>1,datasize(5)>1],[]);
                        data{1}=false(1,datasize(2),datasize(3));
                        data{1}(ind)=true;
                        message='mask';
                        status=true;
                    end
                else
                    message=sprintf('Phasor map for ROI of ALL does not plot');
                    status=false;
                end
            otherwise
                switch parameter
                    case 'trace'
                        % asked for data trace to be calculated
                        status=true;
                        data=cell(2,3);
                        message=sprintf('roi trace calculated\n');
                        switch bin2dec(num2str(pos_dim_idx))%display decide on data dimension
                            % 0(point)/9(XT)/12(XY)/13(XYT)/14(XYZ)/15(XYZT)/17(tT)/28(tXY)/29(tXYT)/30(tXYZ)/31
                            % (tXYZT) missing 31
                            case 0
                                display_dim=[false,false,false,false,false];
                                [ data{1,3}, data{1,2} ] = obj.get_displaydata( current_data, display_dim );
                                data{1,1}=squeeze(obj.data(current_data).dataval);
                            case 9
                                %XT(01001)
                                [~,I2,~,~,I5]=ind2sub(obj.data(current_data).datainfo.data_dim,pixel_idx);
                                display_dim=[false,true,false,false,false];
                                [ data{1,3}, data{1,2} ] = obj.get_displaydata( current_data, display_dim );
                                data{1,1}=squeeze(nanmean(obj.data(current_data).dataval(:,:,:,:,unique(I5)),5));
                                display_dim=[false,false,false,false,true];
                                [ data{2,3}, data{2,2} ] = obj.get_displaydata( current_data, display_dim );
                                data{2,1}=squeeze(nanmean(obj.data(current_data).dataval(:,unique(I2),:,:,:),2));
                            case 12
                                %XY(01100)
                                [~,I2,I3,~,~]=ind2sub(obj.data(current_data).datainfo.data_dim,pixel_idx);
                                display_dim=[false,true,false,false,false];
                                [ data{1,3}, data{1,2} ] = obj.get_displaydata( current_data, display_dim );
                                data{1,1}=squeeze(nanmean(obj.data(current_data).dataval(:,:,unique(I3),:,:),3));
                                display_dim=[false,false,true,false,false];
                                [ data{2,3}, data{2,2} ] = obj.get_displaydata( current_data, display_dim );
                                data{2,1}=squeeze(nanmean(obj.data(current_data).dataval(:,unique(I2),:,:,:),2));
                            case 13
                                % XYT(01101)
                                display_dim=[true,false,false,false,false];
                                [ data{1,3}, data{1,2} ] = obj.get_displaydata( current_data, display_dim );
                                dimsize=obj.data(current_data).datainfo.data_dim;
                                temp=reshape(obj.data(current_data).dataval,[dimsize(1),dimsize(2)*dimsize(3),dimsize(4),dimsize(5)]);
                                data{1,1}=nanmean(temp(:,pixel_idx,:),2);
                                display_dim=[false,false,false,false,true];
                                [ data{2,3}, data{2,2} ] = obj.get_displaydata( current_data, display_dim );
                                data{2,1}=squeeze(data{1,1});
                            case 14
                                % XYZ(01110)
                                % display Z in dt for consistency with XYZT data
                                display_dim=[false,false,false,true,false];
                                [ data{1,3}, data{1,2} ] = obj.get_displaydata( current_data, display_dim );
                                dimsize=obj.data(current_data).datainfo.data_dim;
                                temp=reshape(obj.data(current_data).dataval,[dimsize(1),dimsize(2)*dimsize(3),dimsize(4),dimsize(5)]);
                                data{1,1}=squeeze(nanmean(temp(1,pixel_idx,:,1),2));
                            case 15
                                % XYZT(01111)
                                % display Z in dt for consistency with XYZT data
                                display_dim=[false,false,false,true,false];
                                [ data{1,3}, data{1,2} ] = obj.get_displaydata( current_data, display_dim );
                                dimsize=obj.data(current_data).datainfo.data_dim;
                                temp=squeeze(reshape(obj.data(current_data).dataval,[dimsize(1),dimsize(2)*dimsize(3),dimsize(4),dimsize(5)]));
                                data{1,1}=nanmean(temp(pixel_idx,:,:),1);
                                display_dim=[false,false,false,false,true];
                                [ data{2,3}, data{2,2} ] = obj.get_displaydata( current_data, display_dim );
                                data{2,1}=data{1,1};
                            case 17
                                % tT(10001)
                                [I1,~,~,~,I5]=ind2sub(obj.data(current_data).datainfo.data_dim,pixel_idx);
                                display_dim=[true,false,false,false,false];
                                [ data{1,3}, data{1,2} ] = obj.get_displaydata( current_data, display_dim );
                                data{1,1}=squeeze(nanmean(obj.data(current_data).dataval(:,:,:,:,unique(I5)),5));
                                display_dim=[false,false,false,false,true];
                                [ data{2,3}, data{2,2} ] = obj.get_displaydata( current_data, display_dim );
                                data{2,1}=squeeze(nanmean(obj.data(current_data).dataval(unique(I1),:,:,:,:),1));
                            case 28
                                % tXY(11100)
                                display_dim=[true,false,false,false,false];
                                [ data{1,3}, data{1,2} ] = obj.get_displaydata( current_data, display_dim );
                                data{1,1}=squeeze(nanmean(obj.data(current_data).dataval(:,pixel_idx),2));
                                display_dim=[false,false,false,false,true];
                                [ data{2,3}, data{2,2} ] = obj.get_displaydata( current_data, display_dim );
                                data{2,1}=nanmean(data{1,1});
                            case 29
                                % tXYT(11101)
                                % display in t dimension
                                display_dim=[true,false,false,false,false];
                                [ data{1,3}, data{1,2} ] = obj.get_displaydata( current_data, display_dim );
                                dimsize=obj.data(current_data).datainfo.data_dim;
                                temp=reshape(obj.data(current_data).dataval,[dimsize(1),dimsize(2)*dimsize(3),dimsize(4),dimsize(5)]);
                                data{1,1}=nanmean(temp(:,pixel_idx,:),2);
                                % display in T dimension
                                display_dim=[false,false,false,false,true];
                                [ data{2,3}, data{2,2} ] = obj.get_displaydata( current_data, display_dim );
                                data{2,1}=squeeze(nanmean(data{1,1},1));
                            case 30
                                % tXYZ(11110)
                                % display in t dimension
                                display_dim=[true,false,false,false,false];
                                [ data{1,3}, data{1,2} ] = obj.get_displaydata( current_data, display_dim );
                                dimsize=obj.data(current_data).datainfo.data_dim;
                                temp=reshape(obj.data(current_data).dataval,[dimsize(1),dimsize(2)*dimsize(3),dimsize(4),dimsize(5)]);
                                data{1,1}=nanmean(temp(:,pixel_idx,:),2);
                                % display in Z dimension
                                display_dim=[false,false,false,true,false];
                                [ data{2,3}, data{2,2} ] = obj.get_displaydata( current_data, display_dim );
                                data{2,1}=squeeze(nanmean(data{1,1},1));
                            case 31
                                % tXYZT(11111)
                                
                            otherwise
                                status=false;
                                message=sprintf('does not know how to calculate roi trace for this data type yet\n');
                        end
                    case 'histogram'
                        % histogram for all pixel intensity values
                        status=true;
                        message=sprintf('roi histogram calculated\n');
                        switch bin2dec(num2str(pos_dim_idx))%display decide on data dimension
                            % 9(XT)/12(XY)/13(XYT)/14(XYZ)/15(XYZT)/17(tT)/28(tXY)/29(tXYT)/31
                            % (tXYZT) missing 15/31
                            case {1,2,4,8,16}
                                % T/Z/Y/X/t traces
                                fname=cat(2,char(obj.DIM_TAG(pos_dim_idx)),'_disp_bound');
                                maxval=nanmax(obj.data(current_data).dataval(:));
                                data{1}=linspace(obj.data(current_data).datainfo.(fname)(1),...
                                    obj.data(current_data).datainfo.(fname)(2),...
                                    obj.data(current_data).datainfo.(fname)(3));
                                [data{2},~]=histc(obj.data(current_data).dataval(:),data{1});
                            case 9
                                %XT(01001)
                                maxval=nanmax(obj.data(current_data).dataval(pixel_idx));
                                data{1}=linspace(obj.data(current_data).datainfo.t_disp_bound(1),...
                                    obj.data(current_data).datainfo.t_disp_bound(2),...
                                    obj.data(current_data).datainfo.t_disp_bound(3));
                                [data{2},~]=histc(obj.data(current_data).dataval(pixel_idx),data{1});
                            case 12
                                %XY(01100)
                                %maxval=nanmax(obj.data(current_data).dataval(pixel_idx));
                                data{1}=linspace(obj.data(current_data).datainfo.t_disp_bound(1),...
                                    obj.data(current_data).datainfo.t_disp_bound(2),...
                                    obj.data(current_data).datainfo.t_disp_bound(3));
                                [data{2},~]=histc(obj.data(current_data).dataval(pixel_idx),data{1});
                            case 13
                                % XYT(01101)
                                dimsize=obj.data(current_data).datainfo.data_dim;
                                temp=reshape(obj.data(current_data).dataval,[dimsize(1),dimsize(2)*dimsize(3),dimsize(4),dimsize(5)]);
                                temp=squeeze(temp(1,pixel_idx,1,:));
                                maxval=nanmax(temp(:));
                                data{1}=linspace(obj.data(current_data).datainfo.t_disp_bound(1),...
                                    obj.data(current_data).datainfo.t_disp_bound(2),...
                                    obj.data(current_data).datainfo.t_disp_bound(3));
                                data{4}='T';%display axis label
                                data{2}=obj.data(current_data).datainfo.T;%display axis
                                [data{3},~]=histc(temp,data{1},1);%display map
                            case 14
                                % XYZ(01110)
                                dimsize=obj.data(current_data).datainfo.data_dim;
                                temp=reshape(obj.data(current_data).dataval,[dimsize(1),dimsize(2)*dimsize(3),dimsize(4),dimsize(5)]);
                                temp=squeeze(temp(1,pixel_idx,:,1));
                                maxval=nanmax(temp(:));
                                data{1}=linspace(obj.data(current_data).datainfo.t_disp_bound(1),...
                                    obj.data(current_data).datainfo.t_disp_bound(2),...
                                    obj.data(current_data).datainfo.t_disp_bound(3));
                                data{4}='Z';%display axis label
                                data{2}=obj.data(current_data).datainfo.Z;%display axis
                                [data{3},~]=histc(temp,data{1},1);%display map
                            case 15
                                % XYZT(01111)
                                
                            case 17
                                % tT(10001)
                                maxval=nanmax(obj.data(current_data).dataval(pixel_idx));
                                data{1}=linspace(obj.data(1).datainfo.X_disp_bound(1).*maxval,...
                                    obj.data(1).datainfo.X_disp_bound(2).*maxval,...
                                    obj.data(1).datainfo.X_disp_bound(3));
                                [data{2},~]=histc(obj.data(current_data).dataval(pixel_idx),data{1});
                            case 28
                                % tXY(11100)
                                temp=squeeze(nanmean(obj.data(current_data).dataval(:,pixel_idx),1));
                                maxval=nanmax(temp(:));
                                data{1}=linspace(obj.data(1).datainfo.X_disp_bound(1).*maxval,...
                                    obj.data(1).datainfo.X_disp_bound(2).*maxval,...
                                    obj.data(1).datainfo.X_disp_bound(3));
                                [data{2},~]=histc(temp(:),data{1});
                            case 29
                                % tXYT(11101)
                                dimsize=obj.data(current_data).datainfo.data_dim;
                                temp=reshape(obj.data(current_data).dataval,[dimsize(1),dimsize(2)*dimsize(3),dimsize(4),dimsize(5)]);
                                temp=squeeze(nanmean(temp(:,pixel_idx,1,:),1));
                                maxval=nanmax(temp(:));
                                data{1}=linspace(obj.data(1).datainfo.X_disp_bound(1).*maxval,...
                                    obj.data(1).datainfo.X_disp_bound(2).*maxval,...
                                    obj.data(1).datainfo.X_disp_bound(3));
                                data{2}=obj.data(current_data).datainfo.T;
                                data{4}='T';%display axis label
                                [data{3},~]=histc(temp,data{1},1);
                            case 31
                                % tXYZT(11111)
                                
                            otherwise
                                status=false;
                                message=sprintf('does not know how to calculate roi histogram for this data type yet\n');
                        end
                    case 'dist2d'
                        
                    otherwise
                        message=sprintf('Unknown option %s for roi_calculation\n',parameter);
                end
        end
    else
        message=sprintf('no pixel to calculate for %s\n',parameter);
    end
catch exception
    % error handling
    message=[exception.message,data2clip(exception.stack)];
    errordlg(sprintf('%s\n',message));
end