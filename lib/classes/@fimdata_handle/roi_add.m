function [ status, message ] = roi_add( obj, type, position )
%ADD_roi Add new roi to data
%   create point or impoly(freehand) roi associated with current data
%   redraw is used when loading saved data so that all roi can be recreated

%% function complete
status=false;message='';
global SETTING;
try
    switch type
        case 'show'
            %recreate all saved roi for a data item
            current_data=obj.current_data;% find selected data
            if numel(obj.data(obj.current_data).roi)>1
                if isempty(obj.data(obj.current_data).roi(2).handle)||~isvalid(obj.data(obj.current_data).roi(2).handle)
                    obj.roi_add('redraw');
                end
                for roi_idx=2:numel(obj.data(current_data).roi)
                    set(obj.data(obj.current_data).roi(roi_idx).handle,'Visible','on');
                    set(obj.data(obj.current_data).roi(roi_idx).handle,'PickableParts','visible');
                end
            end
        case 'redraw'
            %recreate all saved roi for a data item
            current_data=obj.current_data;% find selected data
            switch obj.data(current_data).datatype
                case {'DATA_IMAGE','DATA_SPC'}
                    where_to=SETTING.panel(2).handle;
                case 'RESULT_IMAGE'
                    where_to=SETTING.panel(5).handle;
                case 'RESULT_PHASOR_MAP'
                    where_to=SETTING.panel(4).handle;
            end
            nroi=numel(obj.data(current_data).roi);
            if nroi>1
                for roi_idx=2:nroi
                    obj.data(current_data).roi(roi_idx).panel=where_to;
                    %end
                    
                    pos=obj.data(current_data).roi(roi_idx).coord; %#ok<NASGU>
                    tag=obj.data(current_data).roi(roi_idx).name;
                    xlimit=[min(obj.data(current_data).datainfo.Y),max(obj.data(current_data).datainfo.Y)];
                    ylimit=[min(obj.data(current_data).datainfo.X),max(obj.data(current_data).datainfo.X)];
                    switch obj.data(current_data).roi(roi_idx).type
                        case 'impolyline'
                            roitype='impoly';
                            fcn = makeConstrainToRectFcn(roitype,xlimit,ylimit);
                            eval(cat(2,'h=',roitype,'(where_to,pos,''Closed'',false,''PositionConstraintFcn'',fcn);'));
                        case {'imellipse','imrect'}
                            roitype=obj.data(current_data).roi(roi_idx).type;
                            coordmin=min(obj.data(current_data).roi(roi_idx).coord);
                            coordmax=max(obj.data(current_data).roi(roi_idx).coord);
                            pos=[coordmin,coordmax-coordmin];
                            fcn = makeConstrainToRectFcn(roitype,xlimit,ylimit);
                            eval(cat(2,'h=',roitype,'(where_to,pos,''PositionConstraintFcn'',fcn);'));
                        otherwise
                            roitype=obj.data(current_data).roi(roi_idx).type;
                            fcn = makeConstrainToRectFcn(roitype,xlimit,ylimit);
                            eval(cat(2,'h=',roitype,'(where_to,pos,''PositionConstraintFcn'',fcn);'));
                    end
                    obj.data(current_data).roi(roi_idx).handle=h;
                    set(obj.data(current_data).roi(roi_idx).handle,'Tag',tag);
                    setPositionConstraintFcn(obj.data(current_data).roi(roi_idx).handle,fcn);
                    set(obj.data(obj.current_data).roi(roi_idx).handle,'Visible','off');
                end
                
                % Ignore ALL roi which has no marking
                selected_roi=obj.data(current_data).current_roi(obj.data(current_data).current_roi>1);
                if ~isempty(selected_roi)
                    % if other roi are selected, mark colour white
                    cellfun(@(x)setColor(x,'w'),{obj.data(current_data).roi(selected_roi).handle});
                    %otherwise set it to blue
                    cellfun(@(x)setColor(x,'w'),{obj.data(current_data).roi(~selected_roi).handle});
                end
            end
        case 'copy'
            % get current data
            current_data=obj.current_data;
            % clear existing placeholder
            obj.roi_placeholder=[];
            % get selected roi index
            current_roi=obj.data(current_data).current_roi;
            current_roi=current_roi(current_roi>1);% ignore template ALL
            num_roi=numel(current_roi);% get number of selected rois
            % initialise roi placeholder
            obj.roi_placeholder=cell(1,num_roi);
            % copy all the positions
            obj.roi_placeholder=obj.data(current_data).roi(current_roi);
            % output info
            message=sprintf('%s\n%g ROI copied.',message,num_roi);
        case 'paste'
            % get current data and roi
            current_data=obj.current_data;
            current_roi=obj.data(current_data).current_roi;
            % get output panel handle
            where_to=obj.data(current_data).datainfo.panel;
            % set old roi to blue colour
            if current_roi>1
                % ignore if current roi is template whose index is 1
                % change colour of the current one to blue
                setColor(obj.data(current_data).roi(current_roi).handle,'b');
            end
            % if we have thing to paste
            if ~isempty(obj.roi_placeholder)
                % update current_roi point to end
                current_roi=length(obj.data(current_data).roi);
                num_roi=length(obj.roi_placeholder);
                % paste each roi
                for m=1:num_roi
                    % create new roi by append to the end
                    obj.data(current_data).roi(current_roi+m)=obj.roi_placeholder(m);
                    % assign auto name
                    obj.data(current_data).roi(end).name=regexprep(obj.roi_placeholder(m).name,'ROI\d*-',cat(2,'ROI',num2str(current_data),'-'));
                    obj.data(current_data).roi(end).handle=[];
                    % assign handle properties
                    obj.data(current_data).roi(end).coord=obj.roi_placeholder(m).coord;
                    obj.data(current_data).roi(end).panel=where_to;
                    % create roi handle
                    switch obj.data(current_data).roi(end).type
                        case 'impolyline'
                            roitype='impoly';
                            eval(cat(2,'obj.data(current_data).roi(end).handle=',roitype,'(where_to,obj.roi_placeholder(m).coord,''Closed'',false);'));
                        case {'imellipse','imrect'}
                            roitype=obj.data(current_data).roi(end).type;
                            coordmin=min(obj.roi_placeholder(m).coord);
                            coordmax=max(obj.roi_placeholder(m).coord);
                            eval(cat(2,'obj.data(current_data).roi(end).handle=',roitype,'(where_to,[coordmin,coordmax-coordmin]);'));
                        otherwise
                            roitype=obj.data(current_data).roi(end).type;
                            eval(cat(2,'obj.data(current_data).roi(end).handle=',roitype,'(where_to,obj.roi_placeholder(m).coord);'));
                    end
                    % make constrain function to the plot area
                    fcn = makeConstrainToRectFcn(roitype,get(where_to,'XLim'),get(where_to,'YLim'));
                    setPositionConstraintFcn(obj.data(current_data).roi(end).handle,fcn);
                    % change colour to white
                    setColor(obj.data(current_data).roi(end).handle,'w');
                    % add call back to print back current position
                    obj.data(current_data).roi(end).handle.addNewPositionCallback(@(p)fprintf('y = %g; x = %g\n',p));
                end
                obj.data(current_data).current_roi=current_roi+1:current_roi+num_roi;
                message=sprintf('%s\n%g ROI pasted',message,num_roi);
                status=true;
            end
        case {'impoint','imrect','impoly','imellipse'}
            % get current data and roi
            current_data=obj.current_data;
            % get plot handle
            where_to=obj.data(current_data).datainfo.panel;
            if ~isempty(where_to)
                for current_roi=obj.data(current_data).current_roi
                    if current_roi>1
                        % ignore template whoes index is 1
                        % change colour of the current one to blue
                        setColor(obj.data(current_data).roi(current_roi).handle,'b');
                    end
                end
                % make constrain function to the plot area
                fcn = makeConstrainToRectFcn(type,get(where_to,'XLim'),get(where_to,'YLim')); %#ok<NASGU>
                % create roi handle
                if isempty(position)
                    eval(cat(2,'h=',type,'(where_to,''PositionConstraintFcn'',fcn);'));
                else
                    eval(cat(2,'h=',type,'(where_to,position,''PositionConstraintFcn'',fcn);'));
                end
                if ~isempty(h)
                    % copy template from 'ALL'
                    obj.data(current_data).roi(end+1)=obj.data(current_data).roi(1);
                    % update current roi index
                    current_roi=numel(obj.data(current_data).roi);
                    %assign auto name
                    obj.data(current_data).roi(current_roi).name=cat(2,'ROI',num2str(current_data),'-',num2str(current_roi));
                    % assign handle
                    obj.data(current_data).roi(current_roi).handle=h;
                    obj.data(current_data).roi(current_roi).coord=h.getPosition;
                    obj.data(current_data).roi(current_roi).panel=get(where_to,'Tag');
                    % set handle name
                    set(obj.data(current_data).roi(current_roi).handle,'Tag',obj.data(current_data).roi(current_roi).name);
                    % change colour to white
                    setColor(obj.data(current_data).roi(current_roi).handle,'w');
                    % add call back to print back current position
                    obj.data(current_data).roi(current_roi).handle.addNewPositionCallback(@(p)fprintf('y = %g; x = %g\n',p));
                    % clear temporary handle
                    clear h;
                    obj.data(current_data).roi(current_roi).panel=where_to;
                    obj.data(current_data).roi(current_roi).type=type;
                    obj.data(current_data).current_roi=current_roi;
                    [~,rmess]=obj.roi_select(current_roi);
                    message=sprintf('%s\n%s\n%s ROI added.',message,rmess,type);
                    status=true;
                else
                    %if cancelled new roi return previous one to white
                    
                    for current_roi=obj.data(current_data).current_roi
                        if current_roi>1
                            % ignore template whoes index is 1
                            % change colour of the current one to blue
                            setColor(obj.data(current_data).roi(current_roi).handle,'w');
                        end
                    end
                    message=sprintf('%s\nAdd %s ROI cancelled.',message,type);
                end
            else
                message=sprintf('%s\no panel assigned to this data.',message);
            end
        case 'impolyline'
            % get current data and roi
            current_data=obj.current_data;
            % get plot handle
            where_to=obj.data(current_data).datainfo.panel;
            if ~isempty(where_to)
                for current_roi=obj.data(current_data).current_roi
                    if current_roi>1
                        % ignore template whoes index is 1
                        % change colour of the current one to blue
                        setColor(obj.data(current_data).roi(current_roi).handle,'b');
                    end
                end
                % make constrain function to the plot area
                fcn = makeConstrainToRectFcn('impoly',get(where_to,'XLim'),get(where_to,'YLim')); %#ok<NASGU>
                % create roi handle
                if isempty(position)
                    eval(cat(2,'h=impoly(where_to,''Closed'',false,''PositionConstraintFcn'',fcn);'));
                else
                    eval(cat(2,'h=impoly(where_to,position,''Closed'',false,''PositionConstraintFcn'',fcn);'));
                end
                if ~isempty(h)
                    % copy template from 'ALL'
                    obj.data(current_data).roi(end+1)=obj.data(current_data).roi(1);
                    % update current roi index
                    current_roi=numel(obj.data(current_data).roi);
                    %assign auto name
                    obj.data(current_data).roi(current_roi).name=cat(2,'ROI',num2str(current_data),'-',num2str(current_roi));
                    % assign handle
                    obj.data(current_data).roi(current_roi).handle=h;
                    obj.data(current_data).roi(current_roi).coord=h.getPosition;
                    obj.data(current_data).roi(current_roi).panel=get(where_to,'Tag');
                    % set handle name
                    set(obj.data(current_data).roi(current_roi).handle,'Tag',obj.data(current_data).roi(current_roi).name);
                    % change colour to white
                    setColor(obj.data(current_data).roi(current_roi).handle,'w');
                    % add call back to print back current position
                    obj.data(current_data).roi(current_roi).handle.addNewPositionCallback(@(p)fprintf('y = %g; x = %g\n',p));
                    % clear temporary handle
                    clear h;
                    obj.data(current_data).roi(current_roi).panel=where_to;
                    obj.data(current_data).roi(current_roi).type=type;
                    obj.data(current_data).current_roi=current_roi;
                    [~,rmess]=obj.roi_select(current_roi);
                    message=sprintf('%s\n%s\n%s ROI added.',message,rmess,type);
                    status=true;
                else
                    %if cancelled new roi return previous one to white
                    
                    for current_roi=obj.data(current_data).current_roi
                        if current_roi>1
                            % ignore template whoes index is 1
                            % change colour of the current one to blue
                            setColor(obj.data(current_data).roi(current_roi).handle,'w');
                        end
                    end
                    message=sprintf('%s\nAdd %s ROI cancelled',message,type);
                end
            else
                message=sprintf('%s\nno panel assigned to this data.',message);
            end
        otherwise
            message=sprintf('%s\nUnknown roi type.',message);
    end
catch exception
    message=sprintf('%s\n%s',message,exception.message);
end