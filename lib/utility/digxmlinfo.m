function metainfo=digxmlinfo(xmltext) %#ok<STOUT>
% initialise levels
level=1;
% initialise end tag counter index
idxendtag=1;
% make the root parent name
parentnames{level}='metainfo';
evalc([parentnames{level},'=[];']);

% search end token </tag> like close bracket
[headertext,sectendidx,~]=regexp(xmltext,'</(\w+)>','tokens');
% end token should be section names
sectendnames=cellfun(@(x)x{1},headertext,'UniformOutput',false);
% total number of sections
nsections=numel(sectendidx);
% search section start using pattern <tag( fname=fval)*></tag> or <tag></tag>
[headertext,~,~,~,~,~,contenttext]=regexp(xmltext,'<(\w+)( ([^= ]+)="([^"]+)")*>|>).*?</\1>','tokens');
clear xmltext;
% ignore contenttext first empty field
contenttext(1)=[];
% section header name
sectstartnames=cellfun(@(x)x{1},headertext,'UniformOutput',false);
% get all the unique section names for a counter field
uniquesectnames=unique(sectstartnames,'stable');
for idxfield=1:numel(uniquesectnames)
    counter.(uniquesectnames{idxfield})=0;
end

% loop through all sections and figure out how to assign them
for idxsect=1:nsections
    % auto increment levels
    level=level+1;
    % get current section name as field name
    fname=sectstartnames{idxsect};
    % increment section counter
    counter.(fname)=counter.(fname)+1;
    % matched the current first end tag mark it off
    if strcmp(sectendnames{idxendtag},fname)
        % remove incremented levels so we go back up one parent level
        level=level-1;
        % make current node name
        nodename=[fname,'(',num2str(counter.(fname)),').'];
        temprootname=[rootname,nodename];
        % move to next end tag
        idxendtag=idxendtag+1;
    else
        % some parent nodes
        % this is not a leaf node
        if strcmp(sectendnames{idxendtag},parentnames{level-1})
            % closed off matched last parent so we move back up one level
            level=level-1;
            % move to next end tag
            idxendtag=idxendtag+1;
        end
        % assign current parent name
        parentnames{level}=fname;
        % make current parent root name
        temp=cellfun(@(x,l)[x,'(',num2str(counter.(x)),')'],parentnames(2:level),num2cell(2:1:level),'UniformOutput',false);
        rootname=sprintf('%s.',parentnames{1},temp{:});
        temprootname=rootname;
    end
    % read leaf node header properties
    readrootprop(headertext{idxsect}{2},temprootname);
    % read contenttext parameters
    readsubsectionprop(contenttext{idxsect},temprootname);
end
    function readrootprop(val,rname)
        fprops=regexp(val,'([^= ]+)="([^"]+)"','tokens');
        % assign all parent root properties
        for idx=1:numel(fprops)
            % get rid of funny characters
            fprops{idx}{1}=regexprep(fprops{idx}{1},'\W*','_');
            fval=readvalues(fprops{idx}{2});
            evalc([rname,fprops{idx}{1},'=',fval,';']);
        end
    end

    function readsubsectionprop(val,rname)
        % <tag (fname="fval")* /> type of xml
        fprops=regexp(val,'<(\w+)( ([^= ]+)="([^"]+)")*[ />|/>]','tokens');
        % assign all the properies in the subsectoin
        for idx=1:numel(fprops)
            subfields=regexp(fprops{idx}{2},'([^= ]+)="([^"]+)"','tokens');
            for idxsub=1:numel(subfields)
                % get rid of funny characters
                subfields{idxsub}{1}=regexprep(subfields{idxsub}{1},'\W*','_');
                fval=readvalues(subfields{idxsub}{2});
                evalc([rname,fprops{idx}{1},'(',num2str(idx),').',subfields{idxsub}{1},'=',fval,';']);
            end
        end
    end

    function fval=readvalues(val)
        % distinguish numeric or text values
        temp=str2double(val);
        if isnan(temp)
            % not a numeric value
            fval=['''',val,''''];
        else
            fval=num2str(temp);
        end
    end
end
