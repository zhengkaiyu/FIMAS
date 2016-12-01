function [ datatype ] = get_datatype( obj, index )
%GET_DATATYPE return data type for raw data
%   parameter maps are not returned here
%   base on the data dimension we can determine data type excluding
%   parameter map type data [t/ch/p,X,Y,Z,T]

%% function complete
if nargin==1 || isempty(index)
    index=obj.current_data;
end

if isempty(obj.data(index).datainfo.data_dim)
    datatype='template';
else
    type_id=sum([16,8,4,2,1].*(obj.data(index).datainfo.data_dim>1));%conver to binary 0-15
    if isempty(obj.data(index).datainfo.operator)
        optype='';
        opname='';
    else
        temp=regexp(obj.data(index).datainfo.operator,'_','split');
        optype=temp{1};
        opname=temp{2};
    end
    switch opname
        case 'Phasor'
            switch type_id
                case {28}
                    datatype='RESULT_PHASOR_MAP';
                case {16,17}
                    datatype='RESULT_PHASOR';
            end
        otherwise
            switch type_id
                case {28,29,25,12,10,6,3,9,5,13,14,15,17,30,11,31}
                    switch optype
                        case 'op'
                            datatype='RESULT_IMAGE';
                        otherwise
                            datatype='DATA_IMAGE';
                    end
                case {16,8,4,2,1}    %'1D_trace'
                    switch optype
                        case 'op'
                            datatype='RESULT_TRACE';
                        otherwise
                            datatype='DATA_TRACE';
                    end
                case 0  %0D_Point
                    switch optype
                        case 'op'
                            datatype='RESULT_POINT';
                        otherwise
                            datatype='DATA_POINT';
                    end
                otherwise
                    datatype=[];%invalid
            end
    end
end