function [ status, message ] = load_atrc_file( obj, filename )
%load_atrc_file load ascii of traces from exported Becker & Hickl programme
%   load exported bh ascii file of t tracse data

%% function complete

% assume we failed
status=false;
try
    [data_file,message]=fopen(filename,'r');%attempt to open file
    if data_file>=3 % successfully opened
        % read header
        header_line=true;
        while header_line
            buffer=fgetl(data_file);
            if strfind(buffer,'*BLOCK')
                header_line=false;
            else
                val=regexp(buffer,'[\s:\s]','split');
                val=val(cellfun(@(x)~isempty(x),val));
                if ~isempty(val)
                    if numel(val)<2
                        val{2}='';
                    end
                    eval(cat(2,'metainfo.',val{1},'=''',val{2},''';'));
                end
            end
        end
        % read data block
        buffer=fread(data_file,'*char');% read file as charaters
        fclose(data_file);% close file
        val=regexp(buffer','[0-9]\d*','match');% seperate out each number
        raw=str2double(val);% conver to numbers
        % ask for size information
        options.Resize='on';options.WindowStyle='modal';options.Interpreter='tex';
        answer = inputdlg({'Enter t size:','Enter T size:'},...
            cat(2,'Data Size: ',num2str(numel(raw))),1,{'256','2'},options);
        if isempty(answer)
            message=sprintf('%s\n','Import action cancelled');
        else
            t_size=str2double(answer{1});
            T_size=str2double(answer{2});
            if numel(raw)==(t_size*T_size)%check size
                % create data holder
                obj.data(end+1)=obj.data(1);%add new data with template
                obj.current_data=numel(obj.data);%update current data index
                obj.data(end).datainfo.data_idx = obj.current_data;%data index
                obj.data(end).dataval=reshape(raw,t_size,1,1,1,T_size);  %copy over values
                obj.data(end).metainfo=metainfo;
                
                obj.data(end).datainfo.dt=1;
                obj.data(end).datainfo.dX=1;
                obj.data(end).datainfo.dY=1;
                obj.data(end).datainfo.dZ=1;
                obj.data(end).datainfo.dT=1;
                obj.data(end).datainfo.t=linspace(0,obj.data(end).datainfo.dt*(t_size-1),t_size);
                obj.data(end).datainfo.X=0;
                obj.data(end).datainfo.Y=0;
                obj.data(end).datainfo.Z=0;
                obj.data(end).datainfo.T=linspace(0,obj.data(end).datainfo.dT*(T_size-1),T_size);
                
                obj.data(end).datainfo.data_dim=[t_size,1,1,1,T_size];
                obj.data(end).datatype=obj.get_datatype();
                obj.data(end).dataname=metainfo.Title;
                obj.data(end).datainfo.last_change=datestr(now);
                status=true;
            else
                errordlg('Incorrect t_size or x_size or y_size or ch_size!  Check Configuration!','Wrong input type');
            end
        end
    else
        % failed to open file
        errordlg(cat(2,filename,message));
    end
    
catch exception%error handle
    message=sprintf('%s\n',exception.message);
end