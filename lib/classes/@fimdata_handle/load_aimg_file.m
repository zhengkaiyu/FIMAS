function [ status, message ] = load_aimg_file( obj, filename )
%load_aimg_file load ascii of images from exported Becker & Hickl programme
%   load exported bh ascii file of images tXY data

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
        set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
        set(0,'DefaultUicontrolForegroundColor','k');
        answer = inputdlg({'Enter t size:','Enter x size:','Enter y size:','Enter Z size:','Enter T size:'},...
            cat(2,'Data Size: ',num2str(numel(raw))),1,{'256','256','256','1','1'},options);
        set(0,'DefaultUicontrolBackgroundColor','k');
        set(0,'DefaultUicontrolForegroundColor','w');
        if isempty(answer)
            message=sprintf('%s\n','Import action cancelled');
        else
            t_size=str2double(answer{1});
            X_size=str2double(answer{2});
            Y_size=str2double(answer{3});
            Z_size=str2double(answer{4});
            T_size=str2double(answer{5});
            if numel(raw)==(t_size*X_size*Y_size*Z_size*T_size)%check size
                % create data holder
                obj.data(end+1)=obj.data(1);%add new data with template
                obj.current_data=numel(obj.data);%update current data index
                obj.data(end).datainfo.data_idx = obj.current_data;%data index
                obj.data(end).dataval=reshape(raw,t_size,X_size,Y_size,Z_size,T_size);  %copy over values
                obj.data(end).metainfo=metainfo;
                
                obj.data(end).datainfo.dt=1;
                obj.data(end).datainfo.dX=1;
                obj.data(end).datainfo.dY=1;
                obj.data(end).datainfo.dZ=1;
                obj.data(end).datainfo.dT=1;
                obj.data(end).datainfo.t=linspace(0,obj.data(end).datainfo.dt*(t_size-1),t_size);
                obj.data(end).datainfo.X=linspace(0,obj.data(end).datainfo.dX*(X_size-1),X_size);
                obj.data(end).datainfo.Y=linspace(0,obj.data(end).datainfo.dY*(Y_size-1),Y_size);
                obj.data(end).datainfo.Z=linspace(0,obj.data(end).datainfo.dZ*(Z_size-1),Z_size);
                obj.data(end).datainfo.T=linspace(0,obj.data(end).datainfo.dT*(T_size-1),T_size);
                
                obj.data(end).datainfo.data_dim=[t_size,X_size,Y_size,Z_size,T_size];
                obj.data(end).datatype=obj.get_datatype;
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
