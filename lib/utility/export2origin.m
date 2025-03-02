function export2origin(dataid,groupid,structdata)
%EXPORT2ORIGIN Summary of this function goes here
%   Detailed explanation goes here

% connect to origin and export data
originObj=actxserver('Origin.ApplicationSI');
originObj.Visible=1;
originObj.Execute('window -a;');
% structured fields
exportfnames=fieldnames(structdata);
% create a book
bookname=dataid;
originObj.Execute(sprintf('newbook name:=%s;',bookname));
for bookid=1:numel(exportfnames)
    % create sheet
    sheetname=sprintf('%s',exportfnames{bookid});
    originObj.Execute(sprintf('newsheet name:=%s;',sheetname));
    if strcmp(bookname,'temporaltrace')||strcmp(exportfnames{bookid},'temporaltrace')
        for catid=1:numel(groupid)
            colid=2*catid-1;
            colname='t';
            originObj.Execute(sprintf('wks.col%d.label$ = "%s";',colid,colname));
            originObj.Execute(sprintf('wks.col%d.type = %d;',colid,4));
            originObj.Execute(sprintf('wks.col%d.unit$ = "%s";',colid,'ms'));
            colid=2*catid;
            colname=groupid{catid};
            originObj.Execute(sprintf('wks.col%d.label$ = "%s";',colid,'df/f0'));
            originObj.Execute(sprintf('wks.col%d.comment$ = "%s";',colid,colname));
            originObj.Execute(sprintf('wks.col%d.type = %d;',colid,1));
        end
        invoke(originObj,'PutWorksheet',sprintf('[%s]%s!',bookname,sheetname),cell2matwpad(structdata.(exportfnames{bookid})));
    elseif strcmp(bookname,'rawspatialtrace')||strcmp(bookname,'fitspatialtrace')||strcmp(exportfnames{bookid},'rawspatialtrace')||strcmp(exportfnames{bookid},'fitspatialtrace')
        for catid=1:numel(groupid)
            colid=2*catid-1;
            colname='r';
            originObj.Execute(sprintf('wks.col%d.label$ = "%s";',colid,colname));
            originObj.Execute(sprintf('wks.col%d.type = %d;',colid,4));
            originObj.Execute(sprintf('wks.col%d.unit$ = "%s";',colid,'um'));
            colid=2*catid;
            colname=groupid{catid};
            originObj.Execute(sprintf('wks.col%d.label$ = "%s";',colid,'normalised'));
            originObj.Execute(sprintf('wks.col%d.comment$ = "%s";',colid,colname));
            originObj.Execute(sprintf('wks.col%d.type = %d;',colid,1));
        end
        invoke(originObj,'PutWorksheet',sprintf('[%s]%s!',bookname,sheetname),cell2matwpad(structdata.(exportfnames{bookid})));
    %{
elseif strncmp(bookname,'cluster_',8)||strncmp(exportfnames{bookid},'cluster_',8)
        originObj.Execute(sprintf('wks.col%d.label$="%s";',1,'parameter'));
        originObj.Execute(sprintf('wcol(1) = {%s};',['"spread mean",','"spread max",','"event count",','"area"']));
        tempdata=cell2matwpad(structdata.(exportfnames{bookid}));
        for colid=1:numel(groupid)
            originObj.Execute(sprintf('wks.col%d.label$="%s";',colid+1,groupid{colid}));
            datastr=sprintf('%f,',tempdata(:,colid));
            originObj.Execute(sprintf('wcol(%d) = {%s};',colid+1,datastr(1:end-1)));
        end
        %}
    else
        for colid=1:numel(groupid)
            originObj.Execute(sprintf('wks.col%d.label$="%s";',colid,groupid{colid}));
            originObj.Execute(sprintf('wks.col%d.type = %d;',colid,1));
        end
        invoke(originObj,'PutWorksheet',sprintf('[%s]%s!',bookname,sheetname),cell2matwpad(structdata.(exportfnames{bookid})));
    end
end
% close connection
release(originObj);