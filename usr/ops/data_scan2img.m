function [ status, message ] = data_scan2img( obj, selected_data, askforparam, defaultparam )
%data_Scan2Img Transform femtonics scan data to images
%--------------------------------------------------------------------------
%
%
%---Batch process----------------------------------------------------------
%   Parameter=struct('selected_data','1','reconstruction','auto','split_ROI','1','collapse_dim','0','histbinsize','0','opmode','sum','ref_dataindex','');
%   selected_data=data index, 1 means previous generated data
%   reconstruction=none|polar|cart|line|point|auto, reconstrution dimension
%   split_ROI=1|0,   reconstruct whole image or split ROI and reconstruct
%   collapse_dim=0|1|2, in which dimension do we do the operation
%   histbinsize=scalar of binning size >=0
%   opmode=sum|max|min|mean|median|nansum|nanmax|nanmin|nanmean|nanmedian
%   ref_dataindex=data index which has the scanline info
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
            reconstruction='auto';
            split_ROI=true;
            collapse_dim=0;
            histbinsize=0;
            opmode='sum';
            ref_dataindex=current_data;
            % need user input/confirm some parameters
            prompt = {'reconstruction (none|polar|cart|line|point|auto)',...
                'split_ROI (1|0)',...
                'collapse_dim (0|1|2)',...
                'histbinsize',...
                'opmode (sum|max|min|mean|median|nan*)',...
                'ref_dataindex'};
            dlg_title = cat(2,'Data bin sizes for',obj.data(current_data).dataname);
            num_lines = 1;
            def = {reconstruction,num2str(split_ROI),num2str(collapse_dim),num2str(histbinsize),opmode,num2str(ref_dataindex)};
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            if ~isempty(answer)
                % get answer and check options
                switch answer{1}
                    case {'none','polar','cart','line','point','auto'}
                        reconstruction=answer{1};
                    otherwise
                        message=sprintf('%s\nUnknown reconstruction mode %s entered.',message,answer{1});
                        return;
                end
                switch answer{2}
                    case {'1','true'}
                        split_ROI=true;
                    case {'0','false'}
                        split_ROI=false;
                    otherwise
                        message=sprintf('%s\nUnknown split_ROI answer %s entered.',message,answer{2});
                        return;
                end
                switch answer{3}
                    case {'0','1','2'}
                        collapse_dim=str2double(answer{3});
                    otherwise
                        message=sprintf('%s\nUnknown collapse_dim answer %s entered.',message,answer{3});
                        return;
                end
                histbinsize=round(max(0,str2double(answer{4})));
                switch answer{5}
                    case {'mean','nanmean','sum','nansum','max','nanmax','min','nanmin','median','nanmedian'}
                        opmode=answer{5};
                    otherwise
                        message=sprintf('%s\nUnknown binning mode %s entered. Use sum/mean/max/min/median or their nan version.',message,answer{5});
                        return;
                end
                ref_dataindex=round(max(1,str2double(answer{6})));
                if isempty(obj.data(ref_dataindex).metainfo.ScanLine)
                    ref_dataindex=[];
                    message=sprintf('%s\ndata(%s) has no scanline info.',answer{6});
                    return;
                else
                    metainfo=obj.data(ref_dataindex).metainfo;
                end
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
                    case 'reconstruction'
                        switch val
                            case {'none','polar','cart','line','point','auto'}
                                reconstruction=val;
                            otherwise
                                %default
                                reconstruction='auto';
                        end
                    case 'split_ROI'
                        switch val
                            case {'true','1'}
                                split_ROI=true;
                            case {'false','0'}
                                split_ROI=false;
                            otherwise
                                split_ROI=true;
                        end
                    case 'collapse_dim'
                        switch val
                            case {'0','1','2'}
                                collapse_dim=str2double(val);
                            otherwise
                                collapse_dim=0;
                        end
                    case 'histbinsize'
                        histbinsize=round(max(0,str2double(val)));
                    case 'opmode'
                        switch val
                            case {'mean','nanmean','sum','nansum','max','nanmax','min','nanmin','median','nanmedian'}
                                opmode=val;
                            otherwise
                                opmode='mean';
                        end
                    case 'ref_dataindex'
                        if isempty(val)
                            % self select
                            ref_dataindex=current_data;
                        else
                            ref_dataindex=round(max(1,str2double(val)));
                        end
                        % check for scan info
                        if isempty(obj.data(ref_dataindex).metainfo.ScanLine)
                            ref_dataindex=[];
                            metainfo=[];
                        else
                            metainfo=obj.data(ref_dataindex).metainfo;
                        end
                end
            end
            % only use waitbar for user attention if we are in
            % automated mode
            if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
                % Report current estimate in the waitbar's message field
                done=data_idx/ndata;
                waitbar(done,waitbar_handle,sprintf('%3.1f%%',100*done));
            else
                % create waitbar if it doesn't exist
                waitbar_handle = waitbar(0,'Please wait...',...
                    'Name','Data Scan 2 Image',...
                    'Progress Bar','Calculating...',...
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
            scanchannel=false;
            % check for scan data Scx and Scy
            if scanchannel
                % have Scx and Scy data for real time scanner feedback
            else
                % only have pattern line info
                [calcinfo]=femtonics_scanline(metainfo);
            end
            %first check if we need to split8into new roi data
            npattern=size(calcinfo.roixint,1);
            for patternidx=1:npattern
                % go through each pattern
                if split_ROI
                    roiexist=cellfun(@(x)~isempty(x),calcinfo.roitime(patternidx,:));
                    nroi=numel(find(roiexist));
                    for roiidx=1:nroi
                        % go through each roi in each pattern
                        % add new data
                        obj.data_add(sprintf('data_scan2img|Pattern#%g/ROI#%g|%s',patternidx,roiidx,obj.data(current_data).dataname),[],[]);
                        % get new data index
                        new_data=obj.current_data;
                        % set parent data index
                        obj.data(new_data).datainfo=obj.data(current_data).datainfo;
                        % set data index
                        obj.data(new_data).datainfo.data_idx=new_data;
                        % set parent data index
                        obj.data(new_data).datainfo.parent_data_idx=current_data;
                        obj.data(new_data).datainfo.operator='data_scan2img';
                        
                        subsetxidx=calcinfo.roixint{patternidx,roiidx};
                        subsettidx=calcinfo.roitint{patternidx,roiidx};
                        obj.data(new_data).dataval=obj.data(current_data).dataval(:,subsetxidx,:,:,subsettidx);
                        % redifine X
                        switch calcinfo.roitype{patternidx,roiidx}
                            case 'spiral'
                                % need spiral to polar or cart or stay as
                                % line
                                obj.data(new_data).datainfo.X=1:1:numel(subsetxidx);
                            case 'square'
                                obj.data(new_data).datainfo.X=calcinfo.roipos{patternidx,roiidx};
                        end
                        obj.data(new_data).datainfo.dX=obj.data(new_data).datainfo.X(2)-obj.data(new_data).datainfo.X(1); 
                        % redefine T
                        obj.data(new_data).datainfo.T=calcinfo.roitime{patternidx,roiidx};
                        obj.data(new_data).datainfo.dT=obj.data(new_data).datainfo.T(2)-obj.data(new_data).datainfo.T(1);
                        % new data dim
                        obj.data(new_data).datainfo.data_dim(2)=numel(obj.data(new_data).datainfo.X);
                        obj.data(new_data).datainfo.data_dim(5)=numel(obj.data(new_data).datainfo.T);
                        %redefine data type
                        obj.data(new_data).datatype=obj.get_datatype(new_data);
                        % pass on metadata info
                        obj.data(new_data).metainfo=obj.data(current_data).metainfo;
                        obj.data(new_data).datainfo.last_change=datestr(now);
                        message=sprintf('%s\nData %s to %s transformed.',message,num2str(current_data),num2str(new_data));
                    end
                else
                    
                    
                end
            end
            status=true;
        end
        % increment data index
        data_idx=data_idx+1;
    end
    % close waitbar if exist
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
catch exception
    % error handle
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
    message=sprintf('%s\n%s',message,exception.message);
end