function [ status, message ] = op_rt( data_handle, option, varargin )
%OP_RT calculate rotational anisotropy r(t) from parallel and perpendicular
%polarised intensity data
%
%=======================================
%options     values    explanation
%=======================================


%table contents must all have default values
parameters=struct('note','',...
    'operator','op_rt',...
    'op_func','@dF_Ffunc',...
    'op_arg','',...
    'background',[],...
    'T_baseline',[]);

status=false;message='';
try
    data_idx=data_handle.current_data;%default to current data
    % get optional input if exist
    if nargin>2
        % get parameters argument
        usroption=varargin(1:2:end);
        % get value argument
        usrval=varargin(2:2:end);
        % loop through to assign input values
        for option_idx=1:numel(usroption)
            switch usroption{option_idx}
                case 'data_index'
                    % specified data indices
                    data_idx=usrval{option_idx};
            end
        end
    end
    
    switch option
        case 'add_data'
            for current_data=data_idx
                switch data_handle.data(current_data).datatype
                    case {'DATA_IMAGE'}
                        % check data dimension, we only take CT, CXT, CXYT,
                        % CXYZT, where C=channel locates in t dimension
                        switch bin2dec(num2str(data_handle.data(current_data).datainfo.data_dim>1))
                            case {17,25,29,31,1,9,13,15}
                                % multi detector channels
                                % tT (10001) / tXT (11001) / tXYT (11101) / tXYZT (11111)
                                % single detector channel
                                % T (00001) / XT (01001) / XYT (01101) / XYZT (01111)
                                parent_data=current_data;
                                % add new data
                                data_handle.data_add(cat(2,'op_Arithmatic|',data_handle.data(current_data).dataname),[],[]);
                                % get new data index
                                new_data=data_handle.current_data;
                                % copy over datainfo
                                data_handle.data(new_data).datainfo=data_handle.data(parent_data).datainfo;
                                % set data index
                                data_handle.data(new_data).datainfo.data_idx=new_data;
                                % set parent data index
                                data_handle.data(new_data).datainfo.parent_data_idx=parent_data;
                                % combine the parameter fields
                                data_handle.data(new_data).datainfo=setstructfields(data_handle.data(new_data).datainfo,parameters);%parameters field will replace duplicate field in data
                                data_handle.data(new_data).datainfo.parameter_space=regexp(parameters.op_func,'\w*(?=func)','match');
                                message=sprintf('%s%s added\n',message, data_handle.data(new_data).dataname);
                                status=true;
                            otherwise
                                message=sprintf('only take T, XT, XYT or XYZT data type\n',data_handle.data(current_data).dataname);
                        end
                end
            end
            % ---------------------
        case 'modify_parameters'
            current_data=data_handle.current_data;
            %change parameters from this method only
            for pidx=numel(varargin)/2
                parameters=varargin{2*pidx-1};
                val=varargin{2*pidx};
                switch parameters
                    case 'note'
                        data_handle.data(current_data).datainfo.note=num2str(val);
                        status=true;
                    case 'operator'
                        message=sprintf('%sUnauthorised to change %s\n',message,parameters);
                        status=false;
                    case 'op_func'
                        val=num2str(val);
                        data_handle.data(current_data).datainfo.op_func=val;
                        data_handle.data(current_data).datainfo.parameter_space=regexp(val,'\w*(?=func)','match');
                    case 'op_arg'
                        val=num2str(val);
                        data_handle.data(current_data).datainfo.op_arg=val;
                    case 'T_baseline'
                        
                    case 'background'
                        
                    otherwise
                        message=sprintf('%sUnauthorised to change %s\n',message,parameters);
                        status=false;
                end
                if status
                    message=sprintf('%s%s has changed to %s\n',message,parameters,val);
                end
            end
            % ---------------------
        case 'calculate_data'
            current_data=data_handle.current_data;
            parent_data=data_handle.data(current_data).datainfo.parent_data_idx;
            op=str2func(data_handle.data(current_data).datainfo.op_func);
            %evalc(cat(2,'data_handle.data(current_data).dataval = op(data_handle.data(parent_data).dataval,));
            %{
            
               I_para_2D=squeeze(sum(I_para_3D,1));
    I_perp_2D=squeeze(sum(I_perp_3D,1));
    I_tot_2D=I_para_2D+2*I_perp_2D;
    r_2D=(I_para_2D-I_perp_2D)./I_tot_2D;
            
            I_para_1D=sum(sum(I_para_3D,3),2)/(Infos.Px*Infos.Py);
I_perp_1D=sum(sum(I_perp_3D,3),2)/(Infos.Px*Infos.Py);
%=========G_factor Section===========
G_head=find(t>=Infos.t_Gstart,1,'first');
G_tail=find(t<=Infos.t_Gend,1,'last');
G_curve=I_para_1D./I_perp_1D;
G_curve=G_curve(G_head:G_tail);
%==clear invalid===
idx=find(isnan(G_curve));G_curve(idx)=[];
idx=find(isinf(G_curve));G_curve(idx)=[];
idx=find(G_curve==0);G_curve(idx)=[];
%==================
G=median(G_curve);
I_perp_1D=I_perp_1D*G;%I_perp_3D=I_perp_3D.*G_map;%modify G factor
%I_tot and steady state anisotropy=
I_tot_1D=I_para_1D+2*I_perp_1D;
D_1D=(I_para_1D-I_perp_1D);
r_1D=D_1D./I_tot_1D;
%===============re-calculate======================
G_3D=median(I_para_3D(G_head:G_tail,:,:),1)./median(I_perp_3D(G_head:G_tail,:,:),1);
G_map=repmat(G_3D,[Infos.Pt 1 1]);
I_perp_3D=I_perp_3D.*G_map;
I_tot_3D=I_para_3D+2*I_perp_3D;
D_3D=(I_para_3D-I_perp_3D);
            
            
            alpha_2D=zeros(Infos.Py,Infos.Px);
    tau_2D=zeros(Infos.Py,Infos.Px);
    theta_fit_2D=zeros(2,Infos.Py,Infos.Px);
    r_fit_2D=zeros(2,Infos.Py,Infos.Px);
    r_map_res=zeros(Infos.Py,Infos.Px);
            
         %=============Combined fitting===============
    for i=1:size(D_3D,2)
        for j=1:size(D_3D,3)
            val=max(I_tot_3D(fit_head:fit_tail,i,j));
            if (val>=1e2)
                %stage
                [temp1,res]=fast_fit_2([tau_1D],[t squeeze(I_tot_3D(:,i,j))],max(I_tot_3D(:,i,j)));
                alpha_2D(i,j)=temp1(1,1)/2;%fast_fit_2
                tau_2D(i,j)=temp1(1,2);
                %sim
                [temp1,res]=fast_fit_3([tau_2D(i,j) theta1_1D+tau_2D(i,j) theta2_1D+tau_2D(i,j)],[t I_para_3D(:,i,j) I_perp_3D(:,i,j)]);
                alpha_2D(i,j)=temp1(4);
                tau_2D(i,j)=temp1(1);
                theta_fit_2D(1:2,i,j)=temp1(2:3);
                r_fit_2D(1:2,i,j)=[temp1(5) temp1(6)];
                r_map_res(i,j)=res/alpha_2D(i,j);
            else
                alpha_2D(i,j)=nan;
                tau_2D(i,j)=nan;
                theta_fit_2D(1:2,i,j)=nan;
                r_fit_2D(1:2,i,j)=nan;
                r_map_res(i,j)=nan;
            end
        end
        disp(cat(2,'row ',num2str(i),' done'));
    end
            
            
tau_2D=1./tau_2D;
theta1_2D=1./squeeze(theta_fit_2D(2,:,:));%fast decay
r01_2D=squeeze(r_fit_2D(2,:,:));
theta2_2D=1./squeeze(theta_fit_2D(1,:,:));%slow decay
r02_2D=squeeze(r_fit_2D(1,:,:));
            
            %}
            Fluo_bg=1;
            Ref_bg=1;
            T_baseline=(data_handle.data(parent_data).datainfo.T>=0)&(data_handle.data(parent_data).datainfo.T<=10);
            data_handle.data(current_data).dataval=op(data_handle.data(parent_data).dataval,...
                1,2,T_baseline,Fluo_bg,Ref_bg);
            data_handle.data(current_data).datainfo.T=data_handle.data(parent_data).datainfo.T;
            
            data_handle.data(current_data).datainfo.data_dim=size(data_handle.data(current_data).dataval);
            data_handle.data(current_data).datatype=data_handle.get_datatype(current_data);
            data_handle.data(current_data).datainfo.data_dim=size(data_handle.data(current_data).dataval);
            data_handle.data(current_data).datainfo.dt=1;
            data_handle.data(current_data).datainfo.t=0;
            
            %{
        data_handle.data(current_data).dataval=op(data_handle.data(data_handle.data(current_data).datainfo.input_list(1)).dataval);
        data_handle.data(current_data).datainfo.T=data_handle.data(data_handle.data(current_data).datainfo.input_list(1)).datainfo.T;
        
            %}
            message=sprintf('%s calculated on %s\n',data_handle.data(current_data).datainfo.op_func,data_handle.data(current_data).dataname);
            status=true;
        otherwise
            
    end
catch exception
    message=exception.message;
end

    function [estimates,residue]=fast_fit_3(parameter,data)
        %simultaneous fitting of n-exponentials
        global Infos FIR meas_head meas_tail;
        parameter=parameter(:)';
        m = length(data(:,1));
        fft_FIR=repmat(fft(FIR),1,length(parameter));
        [estimates,val,flag] = fminsearch(@model1,parameter,optimset('Display','off','MaxFunEvals',1e4,'MaxIter',1e4,'TolFun',Infos.tol),data(:,1),data(:,2:end));
        if flag<=0
            estimates=nan(size(estimates));
            coeff=nan(size(coeff));
            disp 'no fit';
        end
        residue=model1(estimates,data(:,1),data(:,2:end));
        coeff=coeff*1.5;coeff(2:3,2)=-2*coeff(2:3,2)/coeff(1,2);
        estimates(2:3)=estimates(2:3)-estimates(1);
        estimates = horzcat(estimates,coeff(1:3,2)');
        
        function res=model1(p,t,y)
            X=exp(-t*p(1:3));X=ifft(fft_FIR.*fft(X,m,1),m,1);;
            coeff = X\y;
            coeff=coeff.*(coeff>=0);
            I=X*coeff;
            res=sum((diff(I(meas_head:meas_tail,:),1,2)./(I(meas_head:meas_tail,1)+2*I(meas_head:meas_tail,2))...
                -diff(y(meas_head:meas_tail,:),1,2)./(y(meas_head:meas_tail,1)+2*y(meas_head:meas_tail,2))).^2);
        end
    end

    function [estimates,residue]=fast_fit_2(parameter,data,bc)
        %quick fit of n-exponential fitting
        global Infos FIR meas_head meas_tail;
        parameter=parameter(:)';
        m = length(data(:,1));
        n = length(parameter);
        fft_FIR=repmat(fft(FIR),1,length(parameter));
        [estimates,val,flag] = fminsearch(@expfitfun,parameter,optimset('Display','off','MaxFunEvals',1e4,'MaxIter',1e4,'TolFun',Infos.tol),data(:,1),data(:,2));
        if flag<=0
            estimates=nan(size(estimates));
            coeff=nan(size(coeff));
            disp 'no fit';
        end
        residue=expfitfun(estimates,data(:,1),data(:,2));
        estimates = horzcat(coeff,estimates');
        
        function res = expfitfun(lambda,t,y)
            X = zeros(m,n);
            for k = 1:n
                X(:,k) = exp(-lambda(k)*t);
            end
            X=ifft(fft_FIR.*fft(X,m,1),m,1);
            coeff = X\y;
            coeff=coeff.*(coeff>=0);%constraint
            z = X*coeff;
            res=(sum((z(meas_head:meas_tail)-y(meas_head:meas_tail)).^2));
            %res=sum(((z(meas_head:meas_tail).^2).*(y(meas_head:meas_tail)-z(meas_head:meas_tail))).^2);
        end
    end
