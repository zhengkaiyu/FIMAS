function [ status, message ]=display_metainfo( obj, data_idx, to_sort, output_to )
% display_metainfo display in file information in tables or text field
%   specify which data data_format and the file index
% Usage: display_metainfo( data_index, output_handle )
%   output_handle can be table,edit box or command line

%% function complete

%assume the worst
status = false;
message='empty';
try
    % avoide template which has no file info
    if ~isempty(obj.data(data_idx).metainfo)
        % initialise the variables
        persistent content row_idx; %#ok<TLEV>
        row_idx=1;
        content=[];
        info=[];
        % recursively pull out meta info
        temp=exhaust_disp(obj.data(data_idx).metainfo);
        % if output is not empty
        if ~isempty(content)
            % convert to string format
            info=cellfun(@(x)num2str(x),content,'UniformOutput',false);
        end
        if to_sort
            % sort list
            [~,f_order]=sort(info(:,1));
            info=info(f_order,:);
        end
        % clear temporary variables
        clear persistent content row_idx;
    else
        % no meta info
        info=[];
    end
    if isempty(output_to)
        % output just the message
        message=info;
    elseif ishandle(output_to)
        % if output is handle
        set(output_to,'Data',info);
    else
        % otherwise output to command line
        if ~isempty(info)
            %default output to pipe
            cellfun(@(x)fprintf(1,'%s\n',x),info');
        end
    end
    status = true;
catch exception
    message=sprintf('%s\n',exception.message);
end
%---------------------------------------------
    function val = exhaust_disp(var)
        val=[];
        if isstruct(var)
            if isempty(var)
                f_name=fieldnames(var);
                 for k=1:length(f_name)
                    content{row_idx,1}=f_name{k};
                    content{row_idx,2}=[];
                    row_idx=row_idx+1;
                end
            else
                for n=1:size(var,2)
                    f_name=fieldnames(var(n));
                    %content{row_idx,2}='------';
                    %row_idx=row_idx+1;
                    for k=1:length(f_name)
                        f_val=exhaust_disp(var(n).(f_name{k}));
                        content{row_idx,1}=f_name{k};
                        % put *void* into empty fields
                        if isempty(f_val)
                            f_val='*empty*';
                        end
                        %convert cell to matrix format
                        if iscell(f_val)
                            f_val=data2clip(f_val);
                        end
                        %don't display field that is too large
                        if (isnumeric(f_val))&&(numel(f_val)>10)
                            f_val=sprintf('matrix of size %d x %d',size(f_val,1),size(f_val,2));
                        end
                        content{row_idx,2}=f_val;
                        row_idx=row_idx+1;
                    end
                end
            end
        else
            if ischar(var)
                %remove everything after carridge return from string
                temp=find(double(var)>=10&double(var)<=13|double(var)==0,1,'first');
                if ~isempty(temp)
                    var(temp:end)=[];
                end
            end
            val=var;
        end
    end
end

