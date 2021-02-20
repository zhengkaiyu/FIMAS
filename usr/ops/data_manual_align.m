function [ status, message ] = data_manual_align( obj, selected_data, askforparam, defaultparam )
% DATA_MANUAL_ALIGN manually align X-Y drift in time series XYT/tXYT apply to current selected data.
%--------------------------------------------------------------------------
%  Manual adjust each frame by using wsad keys for x and y shift
%
%   The process is irreversible, therefore new data holder will be created.
%
%   Information on usage
%   1. Use w/s/a/d keys to shift in x and y direction
%   2. Use q/e to decrease or increase shift size
%   3. Use up and down arrow keys to cycle through frames
%   4. Press enter to confirm the final arrangements
%   5. Correction is memories for neighbouring frames
%   x. press ESC key to cancel
%--------------------------------------------------------------------------
%   HEADER END

%% function check
status=false;message='';
try
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
                % get host figure FIMAS
                hfig=findall(0,'Name','FIMAS');
                % get real underlying data size
                realval=axeshandle.UserData;
                datasize=size(realval);
                n_slices=datasize(3);
                shift_size=zeros(n_slices,2);
                % set to the first frame
                currentframe=1;
                surface.ZData=realval(:,:,currentframe);
                % manual key assignments
                keypressed='z';
                hfig.CurrentCharacter=keypressed;
                currentframe=1;
                shift_unit=1;%shift unit size in pixels
                while keypressed~=13&&keypressed~=27 %Enter
                    % find the last key pressed
                    buttonpressed=waitforbuttonpress;
                    if buttonpressed==1
                        keypressed=double(hfig.CurrentCharacter);
                        if ~isempty(keypressed)
                            switch keypressed
                                case {65,97} %A,a=shift left
                                    % shift current image left by 1 pixel
                                    shift_size(currentframe,1)=shift_size(currentframe,1)-shift_unit;
                                    surface.ZData=circshift(surface.ZData,[0,-shift_unit]);
                                case {68,100} %D,d=shift right
                                    % shift current image right by 1 pixel
                                    shift_size(currentframe,1)=shift_size(currentframe,1)+shift_unit;
                                    surface.ZData=circshift(surface.ZData,[0,shift_unit]);
                                case {87,119} %W,w=shift up
                                    % shift current image up by 1 pixel
                                    shift_size(currentframe,2)=shift_size(currentframe,2)-shift_unit;
                                    surface.ZData=circshift(surface.ZData,[-shift_unit,0]);
                                case {83,115} %S,s=shift down
                                    % shift current image down by 1 pixel
                                    shift_size(currentframe,2)=shift_size(currentframe,2)+shift_unit;
                                    surface.ZData=circshift(surface.ZData,[shift_unit,0]);
                                case {69,101} %E,e
                                    % increase step size by doubling
                                    shift_unit=shift_unit*2;
                                case {81,113} %Q,q
                                    % decrease step size (halves and no
                                    % less than 1pixel
                                    shift_unit=max(shift_unit/2,1);
                                case 31 % down arrow
                                    % cycle to the next frame in the stack by 1 frame, loop if end
                                    realval(:,:,currentframe)=surface.ZData;
                                    if currentframe==n_slices
                                        currentframe=1;
                                    else
                                        currentframe=currentframe+1;
                                    end
                                    surface.ZData=realval(:,:,currentframe);
                                case 30 % uparrow
                                    % cycle to the previous frame in the stack by 1 frame, loop if end
                                    realval(:,:,currentframe)=surface.ZData;
                                    if currentframe==1
                                        currentframe=n_slices;
                                    else
                                        currentframe=currentframe-1;
                                    end
                                    surface.ZData=realval(:,:,currentframe);
                                case 13
                                    % Enter
                                    
                                case 27
                                    % esc, cancelled
                                    
                                otherwise
                                    
                            end
                        else
                            keypressed=0;
                        end
                    end
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
            obj.data_add(cat(2,'manual_align|',obj.data(parent_data).dataname),obj.data(parent_data),[]);
            %interpolate new image according to drift parameter
            %This is fine for intensity based images
            nx = 1:size(obj.data(parent_data).dataval,3);
            ny = 1:size(obj.data(parent_data).dataval,2);
            current_data=obj.current_data;
            %create waitbar for user attention
            waitbar_handle = waitbar(0,'Please wait...',...
                'Name','Data Manual Alignment',...
                'Progress Bar','Calculating...',...
                'CreateCancelBtn',...
                'setappdata(gcbf,''canceling'',1)',...
                'WindowStyle','normal',...
                'Color',[0.2,0.2,0.2]);
            setappdata(waitbar_handle,'canceling',0);
            
            for slice_idx=1:n_slices
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
            message=sprintf('data manual-aligned interpolated for %g slices\n x-y shift data is saved in xyshift.dat\n',n_slices);
        case 'Discrete(SPC)'
            %add new data holder
            obj.data_add(cat(2,'manual_align|',obj.data(parent_data).dataname),obj.data(parent_data),[]);
            %round up the pixel size shift
            %This is needed for lifetime images
            %save shift information
            save('./xyshift.dat','shift_size','-ascii');
            %if isnew
            shift_size=fliplr(round(shift_size));
            %end
            current_data=obj.current_data;
            %create waitbar for user attention
            waitbar_handle = waitbar(0,'Please wait...',...
                'Name','Data Manual Alignment',...
                'Progress Bar','Calculating...',...
                'CreateCancelBtn',...
                'setappdata(gcbf,''normal'',1)',...
                'WindowStyle','modal',...
                'Color',[0.2,0.2,0.2]);
            setappdata(waitbar_handle,'canceling',0);
            for slice_idx=1:n_slices
                obj.data(current_data).dataval(:,:,:,:,slice_idx) = circshift(obj.data(parent_data).dataval(:,:,:,:,slice_idx),[0,shift_size(slice_idx,:),0,0]);
                
                %output some progress so we know it is doing things
                if getappdata(waitbar_handle,'canceling')
                    fprintf('Manual alignment calculation cancelled\n');
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
            message=sprintf('data manual-aligned discretly for %g slices\n x-y shift data is saved in xyshift.dat\n',n_slices);
        case 'No'
            %not satisfied with the estimation
            message=sprintf('calculation cancelled\n');
    end
catch exception
    message=exception.message;
end