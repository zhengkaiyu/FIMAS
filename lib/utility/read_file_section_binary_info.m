function section_info = read_file_section_binary_info(fid, offset, format)
% move to the start of the section
fseek(fid,offset,'bof');

if isstruct(format)
    % get the field name list
    field_name_list=fieldnames(format);

    % read each variable with specified format
    for n=1:numel(field_name_list)
        % workout typedef and size
        var_format=format.(field_name_list{n});
        if ischar(var_format)
            temp=regexp(var_format,'_','split');
            switch numel(temp)
                case 0
                    fprintf('invalid typedef for %s.\n',field_name_list{n});
                case 1
                    % non array
                    array_format=temp{1};
                    array_length=1;
                case 2
                    % array data
                    array_format=temp{1};
                    array_length=str2double(temp{2});
            end
            % read different data type
            switch array_format
                case {'short','ushort','long','ulong','float','int','uint','double'}
                    section_info.(field_name_list{n})=fread(fid,array_length,array_format);
                    %fprintf('%s = %f\n',field_name_list{n},section_info.(field_name_list{n}));
                case {'char','uchar'}
                    switch array_length
                        case 1
                            % single value
                            section_info.(field_name_list{n})=fread(fid,1,format.(field_name_list{n}));
                        otherwise
                            % arrays
                            section_info.(field_name_list{n})=char(fread(fid,array_length,array_format)');
                    end
                    %fprintf('%s = %s\n',field_name_list{n},section_info.(field_name_list{n}));
                otherwise
                    fprintf('unknown data type.\n');
            end
            
        elseif isstruct(var_format)
            % structured format need to do nested loop now
            section_info.(field_name_list{n}) = read_file_section_binary_info(fid, ftell(fid), var_format);
        end
    end
else
    fprintf('non-structured data.\n');
end

