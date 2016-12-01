function [ status, message ] = load_excel_file( obj, filename )
%load_excel_file reads interactively from user selection in eXcel sheet
%

%% function complete
status=false;

try
    %ask for trace or images
    dim_answer=questdlg(sprintf('What data type is it?\nt-traces/T-traces, 1st column = time.\nXy-images, cannot contain header'),...
        'Data Type Check','t-Traces','T-Traces','XY-Image','T-Traces');
    if ~isempty(dim_answer)
        %interactive loading
        [rawdata,rawheader]=xlsread(filename,-1);
        if ~isempty(rawdata)
            data_end_pos=numel(obj.data);%get current number of data
            obj.data(data_end_pos+1)=obj.data(1);%add new data with template
            data_end_pos=data_end_pos+1;%increment to new end position
            obj.current_data=data_end_pos;%update current data indeX
            obj.data(data_end_pos).datainfo.data_idx=data_end_pos;%data indeX
            switch dim_answer
                case 'T-Traces'%1D_T_trace or 2D_XT_image
                    %if trace assume first column is T
                    %copy over data values
                    obj.data(data_end_pos).dataval(1,:,1,1,:)=rawdata(:,2:end)';
                    X_size=size(rawdata,2)-1;
                    T_size=size(rawdata,1);
                    obj.data(data_end_pos).datainfo.dX=1;%dX
                    obj.data(data_end_pos).datainfo.dT=rawdata(2,1)-rawdata(1,1);%dT
                    %assign X
                    obj.data(data_end_pos).datainfo.X=1:obj.data(data_end_pos).datainfo.dX:X_size;
                    %assign gT
                    obj.data(data_end_pos).datainfo.T=rawdata(:,1);
                    %get data Dimension
                    obj.data(data_end_pos).datainfo.data_dim=[1,X_size,1,1,T_size];
                    obj.data(data_end_pos).datatype=obj.get_datatype;
                    %assign header to metainfo
                    for info_idx=1:X_size
                        info.(cat(2,'header',num2str(info_idx)))=sprintf('%s|',rawheader{:,info_idx+1});
                    end
                    obj.data(data_end_pos).metainfo=info;
                    %assign data name
                    obj.data(data_end_pos).dataname=filename;
                case 't-Traces'%1D_t_trace or 2D_tT_image
                    %if trace assume first column is t
                    %copy over data values
                    obj.data(data_end_pos).dataval(:,1,1,1,:)=rawdata(:,2:end);
                    T_size=size(rawdata,2)-1;
                    t_size=size(rawdata,1);
                    obj.data(data_end_pos).datainfo.dT=1;%dT
                    obj.data(data_end_pos).datainfo.dt=rawdata(2,1)-rawdata(1,1);%dt
                    %assign X
                    obj.data(data_end_pos).datainfo.T=1:obj.data(data_end_pos).datainfo.dT:T_size;
                    %assign dt
                    obj.data(data_end_pos).datainfo.t=rawdata(:,1);
                    %get data Dimension
                    obj.data(data_end_pos).datainfo.data_dim=[t_size,1,1,1,T_size];
                    obj.data(data_end_pos).datatype=obj.get_datatype;
                    %assign header to metainfo
                    for info_idX=1:T_size
                        info.(cat(2,'header',num2str(info_idX)))=sprintf('%s|',rawheader{:,info_idX+1});
                    end
                    obj.data(data_end_pos).metainfo=info;
                    %assign data name
                    obj.data(data_end_pos).dataname=filename;
                case 'XY-Image'
                    %if images assume first column is X, and first row is Y
                    %copy over data values
                    X_size=size(rawdata,1);
                    if X_size<=1
                        %swap X singleton with Y to have valid data type
                        X_size=size(rawdata,2);
                        Y_size=size(rawdata,1);
                        obj.data(data_end_pos).dataval(1,:,:,1,1)=rawdata';
                    else
                        Y_size=size(rawdata,2);
                        obj.data(data_end_pos).dataval(1,:,:,1,1)=rawdata;
                    end
                    obj.data(data_end_pos).datainfo.dX=1;%dX
                    obj.data(data_end_pos).datainfo.dY=1;%dY
                    %assign X
                    obj.data(data_end_pos).datainfo.X=1:obj.data(data_end_pos).datainfo.dX:X_size;
                    %assign y
                    obj.data(data_end_pos).datainfo.Y=1:obj.data(data_end_pos).datainfo.dY:Y_size;
                    %get data Dimension
                    obj.data(data_end_pos).datainfo.data_dim=[1,X_size>1,Y_size>1,1,1];
                    obj.data(data_end_pos).datatype=obj.get_datatype;
                    obj.data(data_end_pos).metainfo=dir(filename);
                    %assign data name
                    obj.data(data_end_pos).dataname=obj.data(data_end_pos).metainfo.name;
            end
            obj.data(data_end_pos).datainfo.last_change=datestr(now);%update data mod time
            status=true;
            message=sprintf('%s imported\n',filename);
        else
            message=sprintf('Wrong file? Action cancelled\n');
        end
    else
        message=sprintf('Unsure about data type? Action cancelled\n');
    end
catch eXception
    message=eXception.message;
end