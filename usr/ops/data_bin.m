function [ status, message ] = data_bin( obj, selected_data, askforparam, defaultparam )
% DATA_BIN bin currently selected data in provided dimensions
%--------------------------------------------------------------------------
%   1. The process is irreversible, therefore new data holder will be created.
%
%   2. Data which does not fit into whole bins at the end will be discarded
%
%   3. Default mode is sum. nan* mode should be used if data contain nan
%
%   4. To collapse various dataitem of different size in binning dimension use Inf in that binning dimension
%
%---Batch process----------------------------------------------------------
%   Parameter=struct('selected_data','1','newdata','1','setbinsize','[1,1,1,1,1]','opmode','sum','calcmode','reduce');
%   selected_data=data index, 1 means previous generated data
%   newdata=0|1; for batch process it needs to be 1
%   setbinsize=1x5 vector of binning size >=1
%   opmode=sum|max|min|mean|median|nansum|nanmax|nanmin|nanmean|nanmedian
%   calcmode=same|reduce;   default is reduce
%--------------------------------------------------------------------------
%   HEADER END

%% function complete

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
            % 1. check for data operator
            if find(strcmp(obj.data(current_data).datainfo.operator,'data_bin'))
                % overwrite existing data
                newdata=false;
            else
                % new data will need to be created
                newdata=true;
            end
            % 2. check for bin dimension
            if isempty(obj.data(current_data).datainfo.bin_dim)
                % bin dimension don't exist need to get set it to full size
                setbinsize=obj.data(current_data).datainfo.data_dim;
            else
                % use current bin dimension
                setbinsize=obj.data(current_data).datainfo.bin_dim;
            end
            % 3. check for bin calculation mode
            if isfield(obj.data(current_data).datainfo,'operator_mode')
                % bin mode as specified
                opmode=obj.data(current_data).datainfo.operator_mode;
            else
                % default bin mode is sum
                opmode='sum';
            end
            % 4. check mode specified is correct selection
            switch opmode
                case {'mean','nanmean','sum','nansum','max','nanmax','min','nanmin','median','nanmedian'}
                    % valid ones
                otherwise
                    % if invalid operation proposed default to sum
                    opmode='sum';
            end
            % 5. check for bin calculation mode
            if isfield(obj.data(current_data).datainfo,'calculator_mode')
                % specified binning dim reduction
                calcmode=obj.data(current_data).datainfo.calculator_mode;
            else
                % default bin mode is data size reduction
                calcmode='reduce';
            end
            % need user input/confirm some parameters
            prompt = {'This is based on the current data (mean/sum/max/min/median and nan mode)',...
                'Enter t bin sizes',...
                'Enter X bin size',...
                'Enter Y bin size',...
                'Enter Z bin size',...
                'Enter T bin size',...
                'Calculation Mode (reduce/same)',...
                'New Data'};
            dlg_title = cat(2,'Data bin sizes for',obj.data(current_data).dataname);
            num_lines = 1;
            def = {opmode,num2str(setbinsize(1)),num2str(setbinsize(2)),num2str(setbinsize(3)),num2str(setbinsize(4)),num2str(setbinsize(5)),calcmode,num2str(newdata)};
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            if ~isempty(answer)
                newdata=str2double(answer{8})==1;
                % get bin sizes
                setbinsize=cellfun(@(x)str2double(x),answer(2:6))';
                if ~newdata
                    % if it is overwrite existing data we need to update
                    % existing bin_dim
                    obj.data(current_data).datainfo.bin_dim=setbinsize;
                end
                % calculation mode
                opmode=answer{1};
                calcmode=answer{7};
                % update opmode
                switch opmode
                    case {'mean','nanmean','sum','nansum','max','nanmax','min','nanmin','median','nanmedian'}
                        obj.data(current_data).datainfo.operator_mode=opmode;
                    otherwise
                        message=sprintf('%s\nUnknown binning mode %s entered. Use sum/mean/max/min/median or their nan version.',message,opmode);
                        return;
                end
                % update calmode
                switch calcmode
                    case {'reduce','same'}
                        if ~newdata
                            obj.data(current_data).datainfo.calculator_mode=calcmode;
                        end
                    otherwise
                        message=sprintf('%s\nUnknown calcmode mode %s entered. Use reduce or same.',message,calcmode);
                        return;
                end
                % for multiple data ask for apply to all option
                if numel(selected_data)>1
                    askforparam=askapplyall('apply');
                end
            else
                % cancel clicked don't do anything to this data item
                setbinsize=[];
            end
        else
            % user decided to apply same settings to rest or use default
            % assign parameters
            fname=defaultparam(1:2:end);
            fval=defaultparam(2:2:end);
            for fidx=1:numel(fname)
                switch fname{fidx}
                    case 'setbinsize'
                        setbinsize=str2num(fval{fidx});
                    case 'newdata'
                        newdata=logical(str2double(fval{fidx}));
                    case 'opmode'
                        opmode=char(fval{fidx});
                    case 'calcmode'
                        calcmode=char(fval{fidx});
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
                    'Progress Bar','Calculating...',...
                    'Name','Data Binning',...
                    'CreateCancelBtn',...
                    'setappdata(gcbf,''canceling'',1)',...
                    'WindowStyle','normal',...
                    'Color',[0.2,0.2,0.2]);
                setappdata(waitbar_handle,'canceling',0);
            end
        end
        
        % ---- Data Calculation ----
        if isempty(setbinsize)
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
                obj.data_add(cat(2,'data_bin|',obj.data(parent_data).dataname),[],[]);
                % get new data index
                current_data=obj.current_data;
                % pass on metadata info
                obj.data(current_data).metainfo=obj.data(parent_data).metainfo;
                % pass on datainfo
                obj.data(current_data).datainfo=obj.data(parent_data).datainfo;
                % set data index
                obj.data(current_data).datainfo.data_idx=current_data;
                % set parent data index
                obj.data(current_data).datainfo.parent_data_idx=parent_data;
                obj.data(current_data).datainfo.operator='data_bin';
                obj.data(current_data).datainfo.operator_mode=opmode;
                obj.data(current_data).datainfo.calculator_mode=calcmode;
            else
                % get parent data index
                parent_data=obj.data(current_data).datainfo.parent_data_idx;
                if isempty(parent_data)
                    message=sprintf('%s\nMissing Parent Data. Check parent_data_idx field.',message);
                    return;
                end
            end
            dim_size=obj.data(parent_data).datainfo.data_dim;
            % work out new data size
            binsize=setbinsize;
            binsize(setbinsize>dim_size)=dim_size(setbinsize>dim_size); % make sure bin<=dim
            newsize=floor(dim_size./binsize);% can only have full number bins
            switch obj.data(parent_data).datatype
                case 'DATA_SPC'
                    data_size=obj.data(parent_data).datainfo.data_dim;
                    ppl=data_size(2);
                    lpf=data_size(3);
                    ppf=ppl*lpf;
                    nframe=data_size(5);
                    binsize(binsize>data_size)=data_size(binsize>data_size); % make sure bin<=dim
                    tbin=binsize(1);
                    pbin=binsize(2);
                    lbin=binsize(3);
                    fbin=binsize(5);
                    newdatasize=ceil(data_size./binsize);% can only have full number bins
                    new_ppl=newdatasize(2);
                    new_lpf=newdatasize(3);
                    new_ppf=(new_ppl*new_lpf);
                    new_nframe=newdatasize(5);
                    
                    id=obj.data(parent_data).dataval(:,1);
                    %%
                    id=id-1;
                    pfid=mod(id,ppf);%pixel index in a frame
                    pid=mod(pfid,ppl)+1;
                    lid=floor(pfid/ppl)+1;
                    fid=floor(id/ppf)+1;
                    newp=((pid-1)-mod((pid-1),pbin))/pbin+1;
                    newl=((lid-1)-mod((lid-1),lbin))/lbin+1;
                    newf=((fid-1)-mod((fid-1),fbin))/fbin+1;
                    newid=((newl-1)*new_ppl+newp)+(newf-1)*new_ppf;
                    
                    if newdatasize(1)>1
                        [~,t_new]=hist(obj.data(parent_data).datainfo.t,obj.data(parent_data).datainfo.t(1:tbin:end));
                        dtime=obj.data(parent_data).dataval(:,2);
                        if new_ppl*new_lpf*new_nframe==1
                            temp=histc(dtime,t_new);
                        else
                            temp=hist3([dtime,newid],{t_new,1:1:new_ppl*new_lpf*new_nframe});
                        end
                    else
                        t_new=0;
                        temp=histc(newid,1:1:new_ppl*new_lpf*new_nframe);
                    end
                    newrawdata=reshape(temp,newdatasize(1),new_ppl,new_lpf,1,new_nframe);
                    
                    if ~isempty(newrawdata)
                        obj.data(current_data).dataval=newrawdata;
                        % recalculate dimension data
                        
                        if numel(t_new)>1
                            obj.data(current_data).datainfo.t=t_new;
                            obj.data(current_data).datainfo.dt=obj.data(current_data).datainfo.t(2)-obj.data(current_data).datainfo.t(1);
                        else
                            obj.data(current_data).datainfo.t=0;
                            obj.data(current_data).datainfo.dt=1;
                        end
                        if newdatasize(2)>1
                            [~,obj.data(current_data).datainfo.X]=hist(obj.data(parent_data).datainfo.X,obj.data(parent_data).datainfo.X(1:pbin:end));
                            obj.data(current_data).datainfo.dX=obj.data(current_data).datainfo.X(2)-obj.data(current_data).datainfo.X(1);
                        else
                            obj.data(current_data).datainfo.X=obj.data(parent_data).datainfo.X(1);
                            obj.data(current_data).datainfo.dX=1;
                        end
                        if newdatasize(3)>1
                            [~,obj.data(current_data).datainfo.Y]=hist(obj.data(parent_data).datainfo.Y,obj.data(parent_data).datainfo.Y(1:lbin:end));
                            obj.data(current_data).datainfo.dY=obj.data(current_data).datainfo.Y(2)-obj.data(current_data).datainfo.Y(1);
                        else
                            obj.data(current_data).datainfo.Y=obj.data(parent_data).datainfo.Y(1);
                            obj.data(current_data).datainfo.dY=1;
                        end
                        obj.data(current_data).datainfo.Z=0;
                        obj.data(current_data).datainfo.dZ=1;
                        if newdatasize(5)>1
                            [~,obj.data(current_data).datainfo.T]=hist(obj.data(parent_data).datainfo.T,obj.data(parent_data).datainfo.T(1:fbin:end));
                            obj.data(current_data).datainfo.dT=obj.data(current_data).datainfo.T(2)-obj.data(current_data).datainfo.T(1);
                        else
                            obj.data(current_data).datainfo.T=obj.data(parent_data).datainfo.T(1);
                            obj.data(current_data).datainfo.dT=1;
                        end
                        status=true;
                        message=sprintf('%s\nData %s to %s binned',message,num2str(parent_data),num2str(current_data));
                        %redefine data type
                        obj.data(current_data).datainfo.data_dim=newdatasize;
                        obj.data(current_data).datatype=obj.get_datatype(current_data);
                        obj.data(current_data).datainfo.last_change=datestr(now);
                    else
                        message=sprintf('%s\nData %s bin failed',message,num2str(parent_data));
                    end
                otherwise
                    if find(newsize==0)
                        message=sprintf('%s\nData %s bin failed. Bin size is too large',message,num2str(parent_data));
                    else
                        offset_size=newsize.*binsize;
                        %binning
                        temp=[binsize;newsize];
                        reshapesize=temp(:);
                        temp=obj.data(parent_data).dataval(1:offset_size(1),1:offset_size(2),1:offset_size(3),1:offset_size(4),1:offset_size(5));
                        temp=reshape(temp,reshapesize'); %#ok<NASGU>
                        switch obj.data(current_data).datainfo.calculator_mode
                            case 'reduce'
                                switch obj.data(current_data).datainfo.operator_mode
                                    case {'sum','nansum','mean','nanmean','median','nanmedian'}
                                        eval(cat(2,'obj.data(current_data).dataval=',...
                                            obj.data(current_data).datainfo.operator_mode,'(',...
                                            obj.data(current_data).datainfo.operator_mode,'(',...
                                            obj.data(current_data).datainfo.operator_mode,'(',...
                                            obj.data(current_data).datainfo.operator_mode,'(',...
                                            obj.data(current_data).datainfo.operator_mode,'(temp,1),3),5),7),9);'));
                                    case {'max','nanmax','min','nanmin'}
                                        eval(cat(2,'obj.data(current_data).dataval=',...
                                            obj.data(current_data).datainfo.operator_mode,'(',...
                                            obj.data(current_data).datainfo.operator_mode,'(',...
                                            obj.data(current_data).datainfo.operator_mode,'(',...
                                            obj.data(current_data).datainfo.operator_mode,'(',...
                                            obj.data(current_data).datainfo.operator_mode,'(temp,[],1),[],3),[],5),[],7),[],9);'));
                                end
                            case 'same'
                                
                        end
                        
                        obj.data(current_data).dataval=reshape(obj.data(current_data).dataval,newsize);
                        obj.data(current_data).datainfo.bin_dim=binsize;
                        status=true;
                        
                        % recalculate dimension data
                        if status==true
                            if ~isempty(obj.data(parent_data).datainfo.t)
                                obj.data(current_data).datainfo.t=nanmean(reshape(obj.data(parent_data).datainfo.t(1:offset_size(1)),[binsize(1),newsize(1)]),1);
                                if numel(obj.data(current_data).datainfo.t)>1
                                    obj.data(current_data).datainfo.dt=obj.data(current_data).datainfo.t(2)-obj.data(current_data).datainfo.t(1);
                                end
                            else
                                obj.data(current_data).datainfo.t=0;
                                obj.data(current_data).datainfo.dt=1;
                            end
                            if ~isempty(obj.data(parent_data).datainfo.X)
                                obj.data(current_data).datainfo.X=nanmean(reshape(obj.data(parent_data).datainfo.X(1:offset_size(2)),[binsize(2),newsize(2)]),1);
                                if numel(obj.data(current_data).datainfo.X)>1
                                    obj.data(current_data).datainfo.dX=obj.data(current_data).datainfo.X(2)-obj.data(current_data).datainfo.X(1);
                                end
                            else
                                obj.data(current_data).datainfo.X=0;
                                obj.data(current_data).datainfo.dX=1;
                            end
                            if ~isempty(obj.data(parent_data).datainfo.Y)
                                obj.data(current_data).datainfo.Y=nanmean(reshape(obj.data(parent_data).datainfo.Y(1:offset_size(3)),[binsize(3),newsize(3)]),1);
                                if numel(obj.data(current_data).datainfo.Y)>1
                                    obj.data(current_data).datainfo.dY=obj.data(current_data).datainfo.Y(2)-obj.data(current_data).datainfo.Y(1);
                                end
                            else
                                obj.data(current_data).datainfo.Y=0;
                                obj.data(current_data).datainfo.dY=1;
                            end
                            if ~isempty(obj.data(parent_data).datainfo.Z)
                                obj.data(current_data).datainfo.Z=nanmean(reshape(obj.data(parent_data).datainfo.Z(1:offset_size(4)),[binsize(4),newsize(4)]),1);
                                if numel(obj.data(current_data).datainfo.Z)>1
                                    obj.data(current_data).datainfo.dZ=obj.data(current_data).datainfo.Z(2)-obj.data(current_data).datainfo.Z(1);
                                end
                            else
                                obj.data(current_data).datainfo.Z=0;
                                obj.data(current_data).datainfo.dZ=1;
                            end
                            if ~isempty(obj.data(parent_data).datainfo.T)
                                obj.data(current_data).datainfo.T=nanmean(reshape(obj.data(parent_data).datainfo.T(1:offset_size(5)),[binsize(5),newsize(5)]),1);
                                if numel(obj.data(current_data).datainfo.T)>1
                                    obj.data(current_data).datainfo.dT=obj.data(current_data).datainfo.T(2)-obj.data(current_data).datainfo.T(1);
                                end
                            else
                                obj.data(current_data).datainfo.T=0;
                                obj.data(current_data).datainfo.dT=1;
                            end
                            message=sprintf('%s\nData %s to %s binned',message,num2str(parent_data),num2str(current_data));
                            %redefine data type
                            obj.data(current_data).datainfo.data_dim=newsize;
                            obj.data(current_data).datatype=obj.get_datatype(current_data);
                            obj.data(current_data).datainfo.last_change=datestr(now);
                        end
                    end
            end
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