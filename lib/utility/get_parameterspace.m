function [ ps_cell_str ] = get_parameterspace( ps_str )
%GET_PARAMETERSPACE Summary of this function goes here
%   Detailed explanation goes here
ps_cell_str={''};
if ischar(ps_str)
    ps_cell_str=regexp(ps_str,'\|','split');
end

end

