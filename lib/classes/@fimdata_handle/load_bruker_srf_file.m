function [ status, message ] = load_bruker_srf_file( obj, filename)
%load_bruker_srf_file load csv ascii file of bruker localisation microscope data
%   load exported csv ascii file of localisation XYZ

%% function complete

% assume we failed
status=false;
try
    [data_file,message]=fopen(filename,'r');%attempt to open file
    if data_file>=3 % successfully opened
        % read header
        buffer=fgetl(data_file);
        header=regexp(buffer,'[\s,\s]','split');
        info.header=header;
        fclose(data_file);% close file
        % read data segment
        val=csvread(filename,1,0);
        % image_id column
        image_ids=unique(val(:,1));
        info.n_image=numel(image_ids);
        % cycle column
        cycles=unique(val(:,2));
        info.n_cycle=numel(cycles);
        % zstep column
        zsteps=unique(val(:,3));
        info.n_zstep=numel(zsteps);
        % frame column
        frames=unique(val(:,4));
        info.n_frame=numel(frames);
        % accum column
        accums=unique(val(:,5));
        info.n_accum=numel(accums);
        % probe column
        probes=unique(val(:,6));
        info.n_probe=numel(probes);
        
        % valid column
        valid=find(val(:,28)==1);
        info.n_valid=numel(valid);
        
        X_pos=val(valid,16)/1000;%convert nm to um
        Y_pos=val(valid,17)/1000;%convert nm to um
        Z_pos=val(valid,18)/1000;%convert nm to um
        
        t_res=1;
        X_res=0.02;
        Y_res=0.02;
        Z_res=0.05;
        scaled=false;
        % ask for dimension resolution
        % get binning information
        prompt = {'X_res','Y_res','Z_res','scaled'};
        dlg_title = cat(2,'dimension resolutoin option for loading ',filename);
        num_lines = 1;
        def = {num2str(X_res),num2str(Y_res),num2str(Z_res),num2str(scaled)};
        set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
        set(0,'DefaultUicontrolForegroundColor','k');
        answer = inputdlg(prompt,dlg_title,num_lines,def);
        set(0,'DefaultUicontrolBackgroundColor','k');
        set(0,'DefaultUicontrolForegroundColor','w');
        if isempty(answer)
            message=sprintf('action cancelled\n');
            return;
        else
            X_res=str2double(answer{1});
            Y_res=str2double(answer{2});
            Z_res=str2double(answer{3});
            scaled=str2double(answer{4})==1;
        end
        t_scale=probes;
        X_scale=min(X_pos):X_res:max(X_pos);
        Y_scale=min(Y_pos):Y_res:max(Y_pos);
        Z_scale=min(Z_pos):Z_res:max(Z_pos);
        t_size=numel(t_scale);
        X_size=numel(X_scale);
        Y_size=numel(Y_scale);
        Z_size=numel(Z_scale);
        T_size=1;
        
        % create data holder
        obj.data(end+1)=obj.data(1);%add new data with template
        obj.current_data=numel(obj.data);%update current data index
        obj.data(end).datainfo.data_idx = obj.current_data;%data index
        obj.data(end).metainfo=info; %metadata info
        obj.data(end).dataval=zeros(t_size,X_size,Y_size,Z_size,T_size);
        for probe_id=1:t_size
            % go through probe individually
            currentprobeidx=find(val(valid,6)==probes(probe_id));
            for zslice=1:Z_size
                % go through each z slices
                currentzidx=currentprobeidx(Z_pos(currentprobeidx)>(Z_scale(zslice)-Z_res/2)&Z_pos(currentprobeidx)<=(Z_scale(zslice)+Z_res/2));
                [temp,~,~,binx,biny]=histcounts2(X_pos(currentzidx),Y_pos(currentzidx),[X_scale-X_res/2,X_scale(end)+X_res/2],[Y_scale-Y_res/2,Y_scale(end)+Y_res/2]);
                if scaled
                    for idx=1:numel(currentzidx)
                        if binx(idx)>0
                            %scaling using column 15
                            temp(binx(idx),biny(idx))=temp(binx(idx),biny(idx))+val(valid(currentzidx(idx)),15);
                        end
                    end
                end
                obj.data(end).dataval(probe_id,:,:,zslice,1)=temp;
            end
        end
        obj.data(end).datainfo.dt=t_res;
        obj.data(end).datainfo.dX=X_res;
        obj.data(end).datainfo.dY=Y_res;
        obj.data(end).datainfo.dZ=Z_res;
        obj.data(end).datainfo.dT=1;
        obj.data(end).datainfo.t=t_scale;
        obj.data(end).datainfo.X=X_scale;
        obj.data(end).datainfo.Y=Y_scale;
        obj.data(end).datainfo.Z=Z_scale;
        obj.data(end).datainfo.T=1;
        obj.data(end).datainfo.data_dim=[t_size,X_size,Y_size,Z_size,T_size];
        obj.data(end).datatype=obj.get_datatype;
        [~,obj.data(end).dataname,~]=fileparts(filename);
        obj.data(end).datainfo.scaled=scaled;
        obj.data(end).datainfo.last_change=datestr(now);
        status=true;
    else
        % failed to open file
        errordlg(cat(2,filename,message));
    end
catch exception%error handle
    message=sprintf('%s\n',exception.message);
end
