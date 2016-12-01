function [ status, message ] = data_arithmatic( obj, selected_data )
%data_arithmatic Summary of this function goes here
%   Detailed explanation goes here


status=false;
try
   obj.current_data
   
   
   
   
   
catch exception
    message=exception.message;
end

