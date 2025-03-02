function info = read_file_section_ascii_info(fid, offset, length, header, footer, field_namelist)

% move to the start of the section
fseek(fid,offset,'bof');

buffer=char(fread(fid,length,'char')');
startIdx=strfind(buffer,header);
if isempty(startIdx)
    info=[];
    error_msg=sprintf('!''%s'' NOT FOUND IN FILE INFO!',header);
    fprintf('%s\n',error_msg);
    return;
else
    if isempty(field_namelist)
        % whole ascii block
        endIdx = strfind(buffer, footer);
        if isempty(endIdx)
            endIdx=length;
        else
            endIdx=endIdx(1)+numel(footer)-1;
        end
        info=buffer(startIdx:endIdx);
        
    else
        field_namelist{end+1}=footer;
        for n=1:numel(field_namelist)-1
            info.(field_namelist{n})=cell2mat(regexp(buffer,sprintf('(?<=%s\\s*:)[ \\S]*',field_namelist{n}),'match'));
        end
    end
end
end

