function [ status, message ]= load_biorad_pic_file( obj, filename )
% load_biorad_pic_file reads standard  biorad image files
%   Load in biorad pic file with data and file info

%% function complete

% assume worst
status=false;
try
    % open file
    [fid,message]=fopen(filename,'r');
    if fid>=3 % successfully opened
        % --- find out file size ---
        fseek(fid,0,'eof');
        fend=ftell(fid);
        fseek(fid,0,'bof');
        
        % --- read header info ---
        % use _num_format to specify number of repeats
        header=struct('label',{'nX','nY','nPic',...
            'ramp1_min','ramp1_max','notes',...
            'data_format','N','filename',...
            'merged','color1','file_id',...
            'ramp2_min','ramp2_max','color2',...
            'edited','lens','mag_factor','dummy'},...
            'format',{'int16','int16','int16',...
            'int16','int16','int32',...
            'int16','int16','_32_uchar',...
            'int16','uint16','uint16',...
            'int16','int16','uint16',...
            'int16','int16','float32','_3_uint16'});
        % read file header
        for n=1:numel(header)
            temp_format=header(n).format;
            % -- check for format repeat patterns --
            rep=1;
            temp=regexp(temp_format,'_*_');%multiple units
            if (temp)%found repeating patterns
                rep=str2double(temp_format(temp(1)+1:temp(2)-1));%repetition number
                temp_format=temp_format(temp(2)+1:end);%format
            end
            % -- read file --
            temp=fread(fid,rep,temp_format);
            temp=temp(:)';%formatting
            if strfind(temp_format,'char')%if is of string type
                endpos=find(temp==0,1,'first');%find carriage return
                if ~isempty(endpos)%remove everything after carriage return
                    temp=temp(1:endpos-1);
                end
                temp=cat(2,header(n).label,' = ''',temp,''';');
            else
                temp=cat(2,header(n).label,' = [',num2str(temp),'];');
            end
            eval(cat(2,'info.',temp));
        end
        
        % --- check for file validity ---
        if info.file_id==12345  %right format
            % --- set gray pixel format ---
            switch info.data_format
                case 1
                    data_format='uint8';
                case 0
                    data_format='uint16';
                otherwise
                    data_format='uint8';
            end
            
            % --- read the data block ---
            data=fread(fid,info.nX*info.nY*info.nPic,data_format);
            
            % -- read tail notes --
            if info.notes~=0 %has tail notes
                Note_Flag=1;
                while (Note_Flag~=0)&&(ftell(fid)<fend)
                    temp=fread(fid,2,'int8'); %#ok<NASGU> skip 2 bytes
                    Note_Flag=fread(fid,1,'int32');
                    skip=fread(fid,4,'int8');%#ok<NASGU> skip 4 bytes
                    Note_Type=fread(fid,1,'int16'); %#ok<NASGU>
                    skip=fread(fid,4,'int8');%#ok<NASGU> skip 4 bytes
                    
                    % --- read 80 bytes of raw notes
                    temp=fread(fid,80,'int8');
                    % --- replace invalid characters
                    replace= temp<32|temp>126;
                    temp(replace)=32;
                    temp=char(temp');
                    % reorganise data
                    equal_sign=strfind(temp,'=');
                    if isempty(equal_sign)
                        % statement has no equal sign
                        space_sign=strfind(temp,' ');% find first space
                        temp=cat(2,temp(1:space_sign(1)-1),'=''',temp(space_sign(1)+1:end),'''');%turn to string
                    else
                        expression=temp(equal_sign+1:end);
                        val=str2double(expression);
                        if isnan(val)
                            % string expression
                            if strfind(expression,'>?@')% last characterset
                                temp=cat(2,'charset=''ignore''');
                            else
                                temp=cat(2,temp(1:equal_sign-1),'=''',expression,'''');
                            end
                        end
                    end
                    eval(cat(2,'info.',temp,';'));
                end
            end
            % close file
            fclose(fid);
            
            %% --- copy over data to object ---
            % add new data object
            data_end_pos=numel(obj.data);
            obj.data(data_end_pos+1)=obj.data(1);
            data_end_pos=data_end_pos+1;
            obj.current_data=data_end_pos;
            
            % set data index
            obj.data(data_end_pos).datainfo.data_idx=obj.current_data;
            % set data name
            [~,name,~]=fileparts(filename);
            obj.data(data_end_pos).dataname=cat(2,name,info.GUID);
            
            %% essential data dimension information
            % optical zoom
            obj.data(data_end_pos).datainfo.op_zoom=info.LENS_MAGNIFICATION;
            % digital zoom
            obj.data(data_end_pos).datainfo.dig_zoom=info.INFO_OBJECTIVE_ZOOM;
            % no lifetime info for this type of data
            obj.data(data_end_pos).datainfo.dt=[];
            obj.data(data_end_pos).datainfo.t=1;
            % get x-axis info
            if isfield(info,'AXIS_2')
                temp=regexp(info.AXIS_2,' ','split');
                obj.data(data_end_pos).datainfo.dX=str2double(temp{3});
                obj.data(data_end_pos).datainfo.X=linspace(str2double(temp{2}),...
                    info.nX*obj.data(data_end_pos).datainfo.dX,info.nX);
            else
                obj.data(data_end_pos).datainfo.dX=[];
                obj.data(data_end_pos).datainfo.X=1;
            end
            % get y/t-axis info
            if isfield(info,'AXIS_3')
                temp=regexp(info.AXIS_3,' ','split');
                obj.data(data_end_pos).datainfo.dY=str2double(temp{3});
                obj.data(data_end_pos).datainfo.Y=linspace(str2double(temp{2}),...
                    info.nY*obj.data(data_end_pos).datainfo.dY,info.nY);
            else
                obj.data(data_end_pos).datainfo.dY=[];
                obj.data(data_end_pos).datainfo.Y=1;
            end
            % get z/T-axis info
            if isfield(info,'AXIS_4')
                temp=regexp(info.AXIS_4,' ','split');
                val=abs(str2double(temp{3}));
                switch temp{4}
                    case 'Seconds'  %time lapse
                        obj.data(data_end_pos).datainfo.dT=info.INFO_FRAME_RATE;
                        obj.data(data_end_pos).datainfo.T=linspace(str2double(temp{3}),...
                            info.nPic*obj.data(data_end_pos).datainfo.dT,info.nPic);
                        data_size=[1,info.nX,info.nY,1,info.nPic];
                    case 'Microns'  %Z-stack
                        obj.data(data_end_pos).datainfo.dZ=val;
                        obj.data(data_end_pos).datainfo.Z=linspace(str2double(temp{3}),...
                            info.nPic*obj.data(data_end_pos).datainfo.dZ,info.nPic);
                        data_size=[1,info.nX,info.nY,info.nPic,1];
                end
            else
                obj.data(data_end_pos).datainfo.dZ=[];
                obj.data(data_end_pos).datainfo.Z=1;
                obj.data(data_end_pos).datainfo.dT=[];
                obj.data(data_end_pos).datainfo.T=1;
                data_size=[1,info.nX,info.nY,1,1];
            end
            
            %% set data type
            obj.data(data_end_pos).datainfo.data_dim=[1,...
                numel(obj.data(data_end_pos).datainfo.X),...
                numel(obj.data(data_end_pos).datainfo.Y),...
                numel(obj.data(data_end_pos).datainfo.Z),...
                numel(obj.data(data_end_pos).datainfo.T)];
            obj.data(data_end_pos).datatype=obj.get_datatype;
            
            % copy over file metainfo information
            obj.data(data_end_pos).metainfo=info;
            % -- resize to appropriate dimensions and copy over---
            obj.data(data_end_pos).dataval=reshape(data,data_size);
            % update data modify time
            obj.data(data_end_pos).datainfo.last_change=datestr(now);
            
            % return success status
            status=true;
        else
            % invalid biorad file
            message=sprintf('%s does not seem to be a valid biorad pic file',filename);
        end
    else
        % cannot read file
        message=sprintf('Read %s failed. Reason: %s',filename,message);
    end
catch exception%error handle
    message=sprintf('%s\n',exception.message);
end