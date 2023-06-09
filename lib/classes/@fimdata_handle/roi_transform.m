function [ status, message ] = roi_transform( obj )
%find roi index and transform image data into indexed data
%% function check
status=false;
% get current data index as it will be the parent data
parent_data=obj.current_data;
% get current roi
parent_roi=obj.data(parent_data).current_roi;
[result,success,message]=obj.roi_calc([],'transform');
if success
    % calculated fine
    switch message
        case 'indexed'
            obj.data_add(cat(2,obj.data(parent_data).dataname,'/',...
                obj.data(parent_data).roi(parent_roi).name),result{1},[]);
            current_data=obj.current_data;
            obj.data(current_data).datainfo.parent_data_idx=parent_data;
            dim=char(result{1,3});
            for ndim=1:numel(dim)
                obj.data(current_data).datainfo.(dim(ndim))=cell2mat(result{1,2}(ndim));
                obj.data(current_data).datainfo.(cat(2,'d',dim(ndim)))=obj.data(parent_data).datainfo.(cat(2,'d',dim(ndim)));
            end
            obj.data(current_data).datainfo.parent_data_idx=parent_data;
            obj.data(current_data).datatype=obj.get_datatype(current_data);
             %update data last change date
            obj.data(current_data).datainfo.last_change=datestr(now);
            obj.data_select(parent_data);
            status=true;
            message=sprintf('ROI transformed. %s \n',message);
        case 'mask'
            obj.data_add(cat(2,obj.data(parent_data).dataname,'/',...
                obj.data(parent_data).roi(parent_roi).name),result{1},[]);
            current_data=obj.current_data;
            obj.data(current_data).datainfo.parent_data_idx=parent_data;
            obj.data(current_data).datainfo.X=obj.data(parent_data).datainfo.X;
            obj.data(current_data).datainfo.dX=obj.data(parent_data).datainfo.dX;
            obj.data(current_data).datainfo.Y=obj.data(parent_data).datainfo.Y;
            obj.data(current_data).datainfo.dY=obj.data(parent_data).datainfo.dY;
            obj.data(current_data).datatype=obj.get_datatype(current_data);
            %update data last change date
            obj.data(current_data).datainfo.last_change=datestr(now);
            obj.data_select(parent_data);
            status=true;
            message=sprintf('ROI mask saved. %s \n',message);
        otherwise
            if ~isempty(result{1,3})
                trace_dim=cellfun(@(x)~isempty(x),strfind(obj.DIM_TAG,char(result{1,3})));
                result_size=size(result{1,1});
                switch numel(result_size)
                    case 3
                        result{1,1}=reshape(result{1,1},[result_size(1),1,1,result_size(2),result_size(3)]);
                        result_size=[result_size(1),1,1,result_size(2),result_size(3)];
                    case 2
                        result{1,1}=reshape(result{1,1},[result_size(1),1,1,1,result_size(2)]);
                        result_size=[result_size(1),1,result_size(2),1,1];
                    otherwise
                        
                end
                obj.data_add(cat(2,obj.data(parent_data).dataname,'/',...
                    obj.data(parent_data).roi(parent_roi).name),result{1,1},[]);
                current_data=obj.current_data;
                dim=char(result{1,3});
                switch dim
                    case 'Z'
                        
                    case 'T'
                        
                end
                obj.data(current_data).datainfo.(dim)=cell2mat(result{1,2});
                obj.data(current_data).datainfo.(cat(2,'d',dim))=obj.data(parent_data).datainfo.(cat(2,'d',dim));
                if result_size(5)>1
                    obj.data(current_data).datainfo.T=obj.data(parent_data).datainfo.T;
                    obj.data(current_data).datainfo.dT=obj.data(parent_data).datainfo.dT;
                end
                obj.data(current_data).datainfo.parent_data_idx=parent_data;
                obj.data(current_data).datatype=obj.get_datatype(current_data);
            end
            %update data last change date
            obj.data(current_data).datainfo.last_change=datestr(now);
            
            if ~isempty(result{2,3})
                result_size=size(result{2,1});
                dim=char(result{2,3});
                switch dim
                    case 'Z'
                        result{2,1}=reshape(result{2,1},[1,1,1,result_size(1),1]);
                    case 'T'
                        result{2,1}=reshape(result{2,1},[1,1,1,1,result_size(1)]);
                        
                end
                obj.data_add(cat(2,obj.data(parent_data).dataname,'/',...
                    obj.data(parent_data).roi(parent_roi).name),result{2,1},[]);
                current_data=obj.current_data;
                obj.data(current_data).datainfo.(dim)=cell2mat(result{2,2});
                obj.data(current_data).datainfo.(cat(2,'d',dim))=obj.data(parent_data).datainfo.(cat(2,'d',dim));
                obj.data(current_data).datainfo.parent_data_idx=parent_data;
                obj.data(current_data).datatype=obj.get_datatype(current_data);
            end            
            %update data last change date
            obj.data(current_data).datainfo.last_change=datestr(now);
            obj.data_select(parent_data);
            status=true;
            message=sprintf('ROI transformed. %s \n',message);
    end
else
    % got calculation error
    message=sprintf('Transforming ROI failed. %s \n',message);
end