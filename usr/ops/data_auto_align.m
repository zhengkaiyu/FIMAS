function [ status, message ] = data_auto_align( obj, selected_data, askforparam, defaultparam )
% DATA_AUTO_ALIGN automatically align X-Y drift in time series XYT/tXYT apply to current selected data.
%--------------------------------------------------------------------------
%   Based on Georgios D. Evangelidis ECC algorithm Interp method is accurate but cannot be used for FLIM data.  Only   discrete step shift can be applied to FLIM data at present
%
%   The process is irreversible, therefore new data holder will be created.
%
%   Information on usage
%   0. select the right panel before click calc(assuming gca)
%   1. draw the rectangle
%   2. adjust to right size
%   3. double click on the rectangle to process
%   x. press ESC key to cancel
%--------------------------------------------------------------------------
%   HEADER END

%% function complete
status=false;message='';
try
    isnew=1;
    parent_data=selected_data(1);
    if numel(selected_data)>1
        % Only select the first one
        warndlg(sprintf('This operation will only be apply to a single data item at one time.\nThe first selected item will be used.\nSaved xyshift.data can be applied to other data.'),...
            'Attention','modal');
    end
    answer=questdlg('Apply calculated xyshift or use new ROI',...
        'Calculation Mode','Existing','New','New');
    switch answer
        case 'New'
            axeshandle=obj.data(parent_data).datainfo.panel;
            %find surface plot
            surface=findobj(axeshandle,'Type','surface');
            if ~isempty(surface)
                %create a zoom at the region of interest to speed up auto alignment
                
                %get axis limit to make constraints for the zoom box
                px_lim=get(surface,'YData');%map axis is inverted
                py_lim=get(surface,'XData');%map axis is inverted
                
                %make constraint function for box
                fcn = makeConstrainToRectFcn('imrect',get(axeshandle,'XLim'),get(axeshandle,'YLim'));
                zoomhandle=imrect(axeshandle,'PositionConstraintFcn',fcn);
                
                %wait for zoom box creation
                position = wait(zoomhandle);
                
                if ~isempty(position)
                    %get pixel coordinate in the zoom box for alignment
                    xmin=position(1);ymin=position(2);w=position(3);h=position(4);
                    xv=[xmin,xmin,xmin+w,xmin+w,xmin];
                    yv=[ymin,ymin+h,ymin+h,ymin,ymin];
                    
                    [pixel_x,pixel_y]=meshgrid(py_lim,px_lim);%map axis is inverted
                    roi=inpolygon(pixel_x,pixel_y,xv,yv);
                    [row,col]=find(roi==1);
                    
                    %we can now clear out the roi as we have information already
                    delete(zoomhandle);clear zoomhandle;
                    
                    %get the 3D XYZT image inside roi
                    %sum over t if exist
                    val=squeeze(nansum(obj.data(parent_data).dataval(:,row(1):row(end),col(1):col(end),:),1));
                    
                    %------------- ECC algorithm ---------------
                    %initialise alignment process parameters
                    NoI = 5; % number of iterations
                    NoL = max(round(log10(size(val,1)*size(val,2)/4)-1),1);  % number of pyramid-levels
                    init=[0,0];%initial estimate of translation in x-y
                    n_slices=size(val,3);%total number of time series slices
                    
                    %check calculation parameters information
                    prompt = {'NoI (No of Iterations)= ',...
                        'NoL (No of Levels)= ',...
                        'init_x = ','init_y = '};
                    dlg_title = 'ECC algorithm parameters';
                    num_lines = 1;
                    def = {num2str(NoI),num2str(NoL),num2str(init(1)),num2str(init(2))};
                    set(0,'DefaultUicontrolBackgroundColor','w');
                    set(0,'DefaultUicontrolForegroundColor','k');
                    answer = inputdlg(prompt,dlg_title,num_lines,def);
                    set(0,'DefaultUicontrolBackgroundColor','k');
                    set(0,'DefaultUicontrolForegroundColor','w');
                    if ~isempty(answer)
                        NoI=str2double(answer{1});
                        NoL=str2double(answer{2});
                        init=str2double(answer(3:4));
                    end
                    
                    %initialise correlation matrix
                    final_warp=cell(1,n_slices);
                    final_warp=cellfun(@(x)zeros(2,1),final_warp,'UniformOutput',false);
                    
                    %create waitbar for user attention
                    waitbar_handle = waitbar(0,'Please wait...','Progress Bar','Calculating...',...
                        'CreateCancelBtn',...
                        'setappdata(gcbf,''canceling'',1)',...
                        'WindowStyle','normal',...
                        'Color',[0.2,0.2,0.2]);
                    setappdata(waitbar_handle,'canceling',0);
                    
                    %loop through stack to find x-y drifts
                    for slice_idx=2:n_slices
                        %get the correlation matrix between current and template frame
                        %template frame is the first slice
                        [~, final_warp{slice_idx}, ~]=ecc(val(:,:,slice_idx), val(:,:,1), NoL, NoI, 'translation', init);
                        
                        %output some progress so we know it is doing things
                        if getappdata(waitbar_handle,'canceling')
                            fprintf('NTC calculation cancelled\n');
                            delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
                            return;
                        end
                        % Report current estimate in the waitbar's message field
                        done=slice_idx/n_slices;
                        waitbar(done,waitbar_handle,sprintf('%3.1f%%',100*done));
                        fprintf('%g/%g analysed\n',slice_idx,n_slices);
                    end
                    delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
                    
                    %plot drift size for confirmation
                    x=1:1:n_slices;xx=x;
                    %get actual shift data
                    shift_size=cell2mat(final_warp(1:end))';
                    %get rid of out of bound shifts (more than 1/2 of the image pixel size due to poor estimate
                    %out_bound=(abs(shift_size(:,1))>numel(px_lim)/2|abs(shift_size(:,2))>numel(py_lim)/2);
                    %shift_size(out_bound,:)=[];x(out_bound)=[];
                    %respline the points missed
                    temp(:,1)=spline(x,shift_size(:,1),xx);
                    temp(:,2)=spline(x,shift_size(:,2),xx);
                    %reinitialise shift_size
                    shift_size=zeros(n_slices,2);
                    %smooth out noises use robust cubic spline
                    shift_size(:,1)=smooth(temp(:,1),0.05,'rlowess');
                    shift_size(:,2)=smooth(temp(:,2),0.05,'rlowess');
                else
                    %didn't draw the box
                    message=sprintf('action cancelled\n');
                    return;
                end
            else
                %no images to align
                message=sprintf('no image here to align\n');
                return;
            end
        case 'Existing'
            %load existing xyshift.dat
            [FileName,PathName,~]=uigetfile({'*.*','All Files'},'Get xyshift data file');
            shift_size=load(cat(2,PathName,filesep,FileName),'-ascii');
            %check size consistency
            if size(shift_size,2)==2
                n_slices=size(obj.data(parent_data).dataval,5);
                if size(shift_size,1)==n_slices
                    isnew=0;
                else
                    %row number inconsisten with data
                    message=sprintf('number of rows in xyshift data inconsistent with image data\n');
                    return;
                end
            else
                %too many columns, can only deal with x-y shift
                message=sprintf('xyshift data can only have two columns\n');
                return;
            end
        otherwise
            %not satisfied with the estimation
            message=sprintf('process cancelled\n');
            return;
    end
    
    %plot the information
    h=figure;
    plot(shift_size(:,2),'b-');%x
    hold all;plot(shift_size(:,1),'r-');%y
    xlabel('Frame #');ylabel('Shift (pixels)');
    legend(gca,'x correction','y correction','Location','NorthWest');
    
    %ask for processing confirmation
    answer = questdlg('Methods to Proceed with calculation?',...
        'Satisfied',...
        'Interp','Discrete(SPC)','No','Interp');
    pause(0.001);
    delete(h);%close information plot
    
    %apply correction as specified
    switch answer
        case 'Interp'
            %add new data holder
            obj.data_add(cat(2,'auto_align|',obj.data(parent_data).dataname),obj.data(parent_data),[]);
            %interpolate new image according to drift parameter
            %This is fine for intensity based images
            nx = 1:size(obj.data(parent_data).dataval,3);
            ny = 1:size(obj.data(parent_data).dataval,2);
            current_data=obj.current_data;
            %create waitbar for user attention
            waitbar_handle = waitbar(0,'Please wait...','Progress Bar','Calculating...',...
                'CreateCancelBtn',...
                'setappdata(gcbf,''canceling'',1)',...
                'WindowStyle','normal',...
                'Color',[0.2,0.2,0.2]);
            setappdata(waitbar_handle,'canceling',0);
            
            for slice_idx=2:n_slices
                obj.data(current_data).dataval(1,:,:,:,slice_idx) = spatial_interp(squeeze(obj.data(parent_data).dataval(1,:,:,:,slice_idx)),shift_size(slice_idx,:)', 'cubic','translation', nx, ny);
                
                %output some progress so we know it is doing things
                if getappdata(waitbar_handle,'canceling')
                    fprintf('NTC calculation cancelled\n');
                    delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
                    return;
                end
                % Report current estimate in the waitbar's message field
                done=slice_idx/n_slices;
                waitbar(done,waitbar_handle,sprintf('%3.1f%%',100*done));
                %printout some progress
                fprintf('%g/%g calculated\n',slice_idx,n_slices);
            end
            delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
            %save shift information
            save('./xyshift.dat','shift_size','-ascii');
            % pass on metadata info
            obj.data(current_data).metainfo=obj.data(parent_data).metainfo;
            status=true;
            message=sprintf('data auto-aligned interpolated for %g slices\n x-y shift data is saved in xyshift.dat\n',n_slices);
        case 'Discrete(SPC)'
            %add new data holder
            obj.data_add(cat(2,'auto_align|',obj.data(parent_data).dataname),obj.data(parent_data),[]);
            %round up the pixel size shift
            %This is needed for lifetime images
             %save shift information
            save('./xyshift.dat','shift_size','-ascii');
            %if isnew
                shift_size=-fliplr(round(shift_size));
            %end
            current_data=obj.current_data;
            %create waitbar for user attention
            waitbar_handle = waitbar(0,'Please wait...','Progress Bar','Calculating...',...
                'CreateCancelBtn',...
                'setappdata(gcbf,''normal'',1)',...
                'WindowStyle','modal',...
                'Color',[0.2,0.2,0.2]);
            setappdata(waitbar_handle,'canceling',0);
            for slice_idx=2:n_slices
                obj.data(current_data).dataval(:,:,:,slice_idx) = circshift(obj.data(parent_data).dataval(:,:,:,slice_idx),[0,shift_size(slice_idx,:),0]);
                
                %output some progress so we know it is doing things
                if getappdata(waitbar_handle,'canceling')
                    fprintf('NTC calculation cancelled\n');
                    delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
                    return;
                end
                % Report current estimate in the waitbar's message field
                done=slice_idx/n_slices;
                waitbar(done,waitbar_handle,sprintf('%3.1f%%',100*done));
                
                %printout some progress
                fprintf('%g/%g calculated\n',slice_idx,n_slices);
            end
            delete(waitbar_handle);       % DELETE the waitbar; don't try to CLOSE it.
           
            % pass on metadata info
            obj.data(current_data).metainfo=obj.data(parent_data).metainfo;
            obj.data(current_data).datainfo.last_change=datestr(now);
            status=true;
            message=sprintf('data auto-aligned discretly for %g slices\n x-y shift data is saved in xyshift.dat\n',n_slices);
        case 'No'
            %not satisfied with the estimation
            message=sprintf('calculation cancelled\n');
    end
catch exception
    message=exception.message;
end