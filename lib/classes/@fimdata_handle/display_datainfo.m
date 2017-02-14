function [ message ] = display_datainfo( obj, data_idx, output_to )
%DISP_DATAINFO display file indata_formation in tables or text field
%   specify which data data_format and the file index

%% function complete

if data_idx>=1
    f_name=fieldnames(obj.data(data_idx).datainfo);
    content=cell(length(f_name)-3,2);%add two base field and minus 5 dims
    content{1,1}='dataname';
    content{1,2}=obj.data(data_idx).dataname;
    content{2,1}='datatype';
    content{2,2}=obj.data(data_idx).datatype;
    f_idx=0;o_idx=3;
    while f_idx<length(f_name)
        f_idx=f_idx+1;
        switch f_name{f_idx}
            %case {'t','X','Y','Z','T'}
            %not to display
            case {''}
                
            otherwise
                f_val=obj.data(data_idx).datainfo.(f_name{f_idx});%field_value
                if isnumeric(f_val)
                    content{o_idx,1}=f_name{f_idx};%field name
                    if numel(f_val)>10
                        content{o_idx,2}=sprintf('matrix of size %d x %d',size(f_val,1),size(f_val,2));
                    else
                        content{o_idx,2}=f_val;
                    end
                    o_idx=o_idx+1;
                else
                    if islogical(f_val)
                        content{o_idx,1}=f_name{f_idx};%field name
                        content{o_idx,2}=f_val;
                    else
                        content{o_idx,1}=f_name{f_idx};%field name
                        if ishandle(f_val)
                            % problem with matlab root object
                            if f_val~=0
                                content{o_idx,2}=sprintf('handle of %s type',f_val.Type);
                            else
                                content{o_idx,2}=f_val;
                            end
                        else
                            if iscell(f_val)
                                content{o_idx,2}=char(f_val)';
                            else
                                if isa(f_val,'matlab.graphics.axis.Axes')
                                    if f_val.isvalid
                                        content{o_idx,2}=f_val.Tag;
                                    else
                                        content{o_idx,2}=[];
                                    end
                                else
                                    if isstruct(f_val)
                                        content{o_idx,2}=sprintf('structured data');
                                    else
                                        content{o_idx,2}=f_val;
                                    end
                                end
                            end
                        end
                        o_idx=o_idx+1;
                    end
                end
        end
    end
    info=cellfun(@(x)num2str(x),content,'UniformOutput',false);
else
    info=[];
end
if isempty(output_to)
    %default output to pipe
    cellfun(@(x)fprintf(1,'%s\n',x),info');
    message=info;
else
    set(output_to,'data',info);
end
end