function [ axis_label, display_axis ] = get_displaydata( obj, data_index, display_dim )
%GET_DATATYPE return data type for raw data
%   parameter maps are not returned here
%   base on the data dimension we can determine data type excluding
%   parameter map type data [t,X,Y,Z,T]

%% function complete
if nargin==1 || isempty(data_index)
    %default values assigned if no input
    data_index=obj.current_data;
    display_dim=obj.data(data_index).datainfo.display_dim;
end

if data_index>1
    if isempty(display_dim)
        switch obj.data(data_index).datatype
            case 'RESULT_PHASOR'
                %determine parameters
                t_dur=obj.data(data_index).datainfo.t_duration*1e-9;
                lb=obj.data(data_index).datainfo.disp_lb*1e-9;
                ub=obj.data(data_index).datainfo.disp_ub*1e-9;
                rep_rate=1/t_dur;
                omega=2*pi*rep_rate;
                fix_component=obj.data(data_index).datainfo.fixed_comp*1e-9;
                tau_space_label=sort([lb,ub,fix_component]);
                t=linspace(0,t_dur,2^8)';
                tau=1./tau_space_label;
                I=exp(-t*tau);
                [g,s]=phasor_transform(t,I,omega);
                %g(1)=0.5435;s(1)=0.3549;
                display_axis{1}=[g;s];
                %longitudinal axis
                p=[0,linspace(0.1,1,10)];
                a=[p'*p;fliplr(1-p)];
                long_grid=zeros(2,size(a,1),size(a,2));
                for grid_point=1:1:numel(p)
                    tau=1./[ub,lb,fix_component];
                    bound_ratio=a(:,numel(p)-grid_point+1);
                    I=exp(-t*tau)*[bound_ratio';(1-p(grid_point)-bound_ratio)';repmat(p(grid_point),1,size(a,1))];
                    [g_longgrid,s_longgrid]=phasor_transform(t,I,omega);
                    long_grid(:,:,grid_point)=[g_longgrid;s_longgrid];
                end
                display_axis{2}=long_grid;
                axis_label=regexp(obj.data(data_index).datainfo.parameter_space,'[|]','split');
            case 'RESULT_PHASOR_MAP'
                axis_label={'g','s'};
                t_dur=obj.data(data_index).datainfo.t_duration*1e-9;
                lb=obj.data(data_index).datainfo.disp_lb*1e-9;
                ub=obj.data(data_index).datainfo.disp_ub*1e-9;
                rep_rate=1/t_dur;
                omega=2*pi*rep_rate;
                fix_component=obj.data(data_index).datainfo.fixed_comp*1e-9;
                tau_space_label=sort([lb,ub,fix_component]);
                t=linspace(0,t_dur,2^8)';
                tau=1./tau_space_label;
                I=exp(-t*tau);
                [g,s]=phasor_transform(t,I,omega);
                %g(1)=0.5435;s(1)=0.3549;
                display_axis{1}=[g;s];
                display_axis{2}={linspace(obj.data(data_index).datainfo.X_disp_bound(1),obj.data(data_index).datainfo.X_disp_bound(2),obj.data(data_index).datainfo.X_disp_bound(3)),...
                    linspace(obj.data(data_index).datainfo.Y_disp_bound(1),obj.data(data_index).datainfo.Y_disp_bound(2),obj.data(data_index).datainfo.Y_disp_bound(3))};
            otherwise
                axis_label=regexp(obj.data(data_index).datainfo.parameter_space,'[|]','split');
                display_axis={data_index};
        end
    else
        axis_label=obj.DIM_TAG(display_dim);%label for x-axis
        if isfield(obj.data(data_index).datainfo,'parameter_space')&&~isempty(obj.data(data_index).datainfo.parameter_space)
            display_axis=cellfun(@(x)obj.data(data_index).datainfo.(char(x)),obj.DIM_TAG(display_dim),'UniformOutput',false);
        else
            %display axis
            display_axis=cellfun(@(x)obj.data(data_index).datainfo.(char(x)),obj.DIM_TAG(display_dim),'UniformOutput',false);
        end
    end
end