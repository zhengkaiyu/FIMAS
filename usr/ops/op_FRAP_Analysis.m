function [ result, message ] = op_FRAP_Analysis( data_handle, option, varargin )
%OP_FRAP_ANALYSIS does fitting of XT FRAP trace or traces
%   Using double exponential model here

result=[];message='';
parameters=struct('note','',...
    'operator','op_FRAP_Analysis',...
    'parameter_space',{'frac_bleached','frac_recover','tau1','tau2'},...
    'MaxFunEvals',1e4,...
    'MaxIter',1e4,...
    'TolFun',1e-6);

result=[];message='';
try
    current_data=data_handle.current_data;
    switch option
        case 'add_data'
            
        case 'modify_parameters'
            
            
        case 'calculate_data'
            
        otherwise
            
    end
    
    
catch exception
    message=exception.message;
end

    function res = expfitfun(lambda,t,y)
        X = zeros(m,n);
        for j = 1:n
            X(:,j) = exp(-lambda(j)*t);
        end
        if ~isempty(fft_FIR)
            X=ifft(fft_FIR.*fft(X,m,1),m,1);
        end
        coeff = X\y;
        z = X*coeff;
        res=(sum((z-y).^2));
        %res=sum(((z(meas_head:meas_tail).^2).*(y(meas_head:meas_tail)-z(meas_head:meas_tail))).^2);
    end


end

