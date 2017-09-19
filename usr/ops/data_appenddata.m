function [ status, message ] = data_appenddata( obj, selected_data )
% DATA_APPENDDATA combines currently selected data into a new data of larger
% size
%   The process is irreversible, therefore new data holder will be created.
%   Combined data size must match in the dimension wish to be appended

%% function complete

% assume worst
status=false;
try
    % get all selected data dimensions and check
    dim_check=arrayfun(@(x)obj.data(x).datainfo.data_dim,selected_data,'UniformOutput',false);
    dim_master=dim_check{1};
    % find any free dimension
    free_dim=obj.DIM_TAG(dim_master==1);
    if isempty(free_dim)
        free_dim={'T'};% if we are full suggest append in T
    end
    % ask append in which dimension
    % get binning information
    prompt = {sprintf('Append data\n%s in which dimension (t/X/Y/Z/T): ',sprintf('%s\n',obj.data(selected_data).dataname))};
    dlg_title = 'Append Dimension';
    num_lines = 1;
    def = free_dim(1);
    set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
    set(0,'DefaultUicontrolForegroundColor','k');
    answer = inputdlg(prompt,dlg_title,num_lines,def);
    set(0,'DefaultUicontrolBackgroundColor','k');
    set(0,'DefaultUicontrolForegroundColor','w');
    if isempty(answer)
        % action cancelled
        append_dim=[];
    else
        switch answer{1}
            case {'t','X','Y','Z','T'}
                append_dim=strfind(cell2mat(obj.DIM_TAG),answer{1});
            otherwise
                % invalid input default to 1st free_dim
                append_dim=strfind(cell2mat(obj.DIM_TAG),free_dim(1));
        end
    end
    if isempty(append_dim)
        message=sprintf('data append operation cancelled\n');
    else
        % check all non-appending dim has the same dimensions
        dim_check=cell2mat(cellfun(@(x)dim_master~=x,dim_check,'UniformOutput',false)');
        % find if there is any mismatch, should be all zero if matches
        [r,c,~]=find(dim_check(~append_dim));
        if isempty(r)
            % --- calculation part ---
            parent_data=selected_data(1);% treat the first one of selected as parent
            % add new data
            newname=sprintf('%s+',obj.data(selected_data).dataname);
            obj.data_add(cat(2,'data_append|(',newname(1:end-1),')'),[],[]);
            % get new data index
            current_data=numel(obj.data);
            obj.current_data=current_data;
            % pass on metadata info
            obj.data(current_data).metainfo=obj.data(parent_data).metainfo;
            % set parent data index
            obj.data(current_data).datainfo.parent_data_idx=selected_data;
            obj.data(current_data).datainfo.operator='data_append';
            obj.data(current_data).datainfo.bin_dim=[];
            obj.data(current_data).datainfo.operator_mode=obj.DIM_TAG{append_dim};
            % set new dimension
            new_dim_size=sum(cell2mat(arrayfun(@(x)obj.data(x).datainfo.data_dim(append_dim),selected_data,'UniformOutput',false)));
            obj.data(current_data).datainfo.data_dim=obj.data(parent_data).datainfo.data_dim;
            obj.data(current_data).datainfo.data_dim(append_dim)=new_dim_size;
            obj.data(current_data).datatype=obj.get_datatype;
            obj.data(current_data).dataval=cat(append_dim,obj.data(selected_data).dataval);
            % recalculate dimension data
            for dim_idx=1:numel(obj.DIM_TAG)
                dim=obj.DIM_TAG{dim_idx};
                if dim_idx==append_dim
                    obj.data(current_data).datainfo.(dim)=obj.data(selected_data(1)).datainfo.(dim);
                    for item_idx=2:numel(selected_data)
                        if obj.data(parent_data).datainfo.(cat(2,'d',dim))~=0
                            obj.data(current_data).datainfo.(cat(2,'d',dim))=obj.data(parent_data).datainfo.(cat(2,'d',dim));
                            if obj.data(selected_data(2)).datainfo.(dim)(1)>obj.data(selected_data(1)).datainfo.(dim)(end)
                                obj.data(current_data).datainfo.(dim)=[obj.data(current_data).datainfo.(dim);obj.data(selected_data(item_idx)).datainfo.(dim)];
                            else
                                obj.data(current_data).datainfo.(dim)=[obj.data(current_data).datainfo.(dim);obj.data(selected_data(item_idx)).datainfo.(dim)+obj.data(current_data).datainfo.(dim)(end)+obj.data(current_data).datainfo.(cat(2,'d',dim))];
                            end
                        else
                            obj.data(current_data).datainfo.(cat(2,'d',dim))=1;
                            obj.data(current_data).datainfo.(dim)=linspace(0,new_dim_size-1,new_dim_size);
                        end
                    end
                else
                    obj.data(current_data).datainfo.(dim)=obj.data(parent_data).datainfo.(dim);
                    obj.data(current_data).datainfo.(cat(2,'d',dim))=obj.data(parent_data).datainfo.(cat(2,'d',dim));
                end
            end
            % output message and status
            obj.data(current_data).datainfo.last_change=datestr(now);
            status=true;
            message=sprintf('%s appended into %s\n',sprintf('%s\n',...
                obj.data(selected_data).dataname),...
                obj.data(current_data).dataname);
        else
            % one of the data has mismatched dimension
            message=sprintf('data %s has mismatched %s dimensions\n',selected_data(r),obj.DIM_TAG{c});
        end
    end
catch exception
    message=exception.message;
end