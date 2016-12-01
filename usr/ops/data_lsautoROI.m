function [ status, message ] = data_lsautoROI( obj, selected_data )
%DATA_LSAUTOROI automatically find roi in a linescan image
%   Image must be in XT format
%   Apply to reference image is more reliable and you can copy and paste
%   roi to the reporter image afterwards

%% function check
% assume worst
status=false;message='';
try
    data_idx=1;% initialise counter
    askforparam=true;% always ask for the first one
    profile_dim='X';int_dim='T';%default XT images
    while data_idx<=numel(selected_data)
        % get the current data index
        current_data=selected_data(data_idx);
        obj.data_select(current_data);
        if askforparam
            % get axis information
            % get binning information
            prompt = {'Profile Dimension (t/X/Y/Z/T)',...
                'min_Peak Distance',...
                'min_Peak Height (factor of median of profile)',...
                'min_Peak Width',...
                'max_Peak Width',...
                'int Dimension (t/X/Y/Z/T)',...
                'int_interval'};
            dlg_title = cat(2,'Line Scan Auto ROI info',obj.data(current_data).dataname);
            num_lines = 1;
            peak_width_min=10*obj.data(current_data).datainfo.(cat(2,'d',profile_dim));
            peak_distance_min=peak_width_min*2;
            peak_width_max=(obj.data(current_data).datainfo.(profile_dim)(end)-obj.data(current_data).datainfo.(profile_dim)(1))/5;
            peak_height_min=1;
            int_interval=[obj.data(current_data).datainfo.(int_dim)(1),obj.data(current_data).datainfo.(int_dim)(end)];
            def = {profile_dim,...
                num2str(peak_distance_min),...
                num2str(peak_height_min),...
                num2str(peak_width_min),...
                num2str(peak_width_max),...
                int_dim,num2str(int_interval)};
            set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
            set(0,'DefaultUicontrolForegroundColor','k');
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            set(0,'DefaultUicontrolBackgroundColor','k');
            set(0,'DefaultUicontrolForegroundColor','w');
            if ~isempty(answer)
                % calculation mode
                profile_dim=answer{1};
                switch profile_dim
                    case {'t','X','Y','Z','T'}
                        
                    otherwise
                        message=sprintf('unknown dimension\n Use default X\n');
                        profile_dim='X';
                end
                peak_distance_min=str2double(answer{2});
                peak_height_min=str2double(answer{3});
                peak_width_min=str2double(answer{4});
                peak_width_max=str2double(answer{5});
                int_dim=answer{6};
                switch int_dim
                    case {'t','X','Y','Z','T'}
                        
                    otherwise
                        message=sprintf('unknown dimension entered\n Use default T\n');
                        int_dim='T';
                end
                int_interval=str2num(answer{7}); %#ok<ST2NM>
                int_interval=find(obj.data(current_data).datainfo.(int_dim)>=int_interval(1)&obj.data(current_data).datainfo.(int_dim)<=int_interval(end));
                % for multiple data ask for apply to all option
                if numel(selected_data)>1
                    % ask if want to apply to the rest of the data items
                    button = questdlg('Apply this setting to: ','Multiple Selection','Apply to Rest','Just this one','Apply to Rest') ;
                    switch button
                        case 'Apply to Rest'
                            askforparam=false;
                        case 'Just this one'
                            askforparam=true;
                        otherwise
                            % action cancellation
                            askforparam=false;
                    end
                end
            else
                % cancel clicked don't do anything to this data item
                profile_dim=[];
                message=sprintf('%s\nAutoROI cancelled for %s.',message,obj.data(current_data).dataname);
            end
        else
            % user decided to apply same settings to rest
            
        end
        
        if ~isempty(profile_dim)
            % ---- Calculation ----
            x=obj.data(current_data).datainfo.(profile_dim);
            y=obj.data(current_data).datainfo.(int_dim);
            temp=obj.data(current_data).dataval;
            partial_int_idx=strfind(cell2mat(obj.DIM_TAG),int_dim);
            profile_idx=strfind(cell2mat(obj.DIM_TAG),profile_dim);
            full_int_idx=setdiff([1,2,3,4,5],[partial_int_idx,profile_idx]);
            for int_idx=full_int_idx
                temp=mean(temp,int_idx);
            end
            temp=squeeze(temp);
            if profile_idx<partial_int_idx
                temp=mean(temp(:,int_interval),2);
            else
                temp=mean(temp(int_interval,:),1);
            end
            temp=smooth(x,temp,0.01,'rloess');
            temp=temp-mode(temp(:));
            temp=temp./max(temp);
            baseline=median(temp);
            min_peakh=peak_height_min*baseline;
            min_peakd=ceil(peak_distance_min/obj.data(current_data).datainfo.(cat(2,'d',profile_dim)));
            min_peakw=ceil(peak_width_min/obj.data(current_data).datainfo.(cat(2,'d',profile_dim)));
            max_peakw=ceil(peak_width_max/obj.data(current_data).datainfo.(cat(2,'d',profile_dim)));
            
            [~,peakpos]=findpeaks(temp,'minpeakheight',min_peakh,'minpeakdistance',min_peakd);
            if ~isempty(peakpos)
                for roi_idx=1:numel(peakpos)
                    sl=max((peakpos(roi_idx)-max_peakw),1);
                    sr=max((peakpos(roi_idx)-min_peakw),1);
                    baseline=mean(temp(sl:sr));
                    lb=find(temp(sl:sr)<=(temp(peakpos(roi_idx))+baseline)*0.37,1,'last');
                    if isempty(lb)
                        lb=0;
                    end
                    lb=lb+sl;
                    sl=min((peakpos(roi_idx)+min_peakw),numel(x));
                    sr=min((peakpos(roi_idx)+max_peakw),numel(x));
                    baseline=mean(temp(sl:sr));
                    rb=find(temp(sl:sr)<=(temp(peakpos(roi_idx))+baseline)*0.37,1,'first');
                    if isempty(rb)
                        rb=0;
                    end
                    rb=min(rb+sl,numel(x));
                    
                    dx=x(rb)-x(lb);
                    %if dx>=peak_width_min
                    %x-y coord is fliped in plotting
                    coord=[y(1),x(lb),y(end)-y(1),dx];
                    obj.roi_add('imrect',coord);
                    %end
                end
                message=sprintf('%s\n%g roi automatically added to %s\n',message,numel(lb),obj.data(current_data).dataname);
            else
                message=sprintf('%s\nno roi was added to %s\n',message,obj.data(current_data).dataname);
            end
        end
        % increment data index
        data_idx=data_idx+1;
    end
    status=true;
catch exception
    message=exception.message;
end
