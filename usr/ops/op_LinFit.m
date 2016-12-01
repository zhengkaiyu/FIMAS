function [ output_args ] = op_LinFit( input_args )
%OP_LINFIT Summary of this function goes here
%   Detailed explanation goes here
 %==================Linear fit======================
        if ~isempty(fitrange)
            if (diff(fitrange)>2)
                
                [p,S]=robustfit(t(fitrange(1):fitrange(end))',Dt(fitrange(1):fitrange(end)));
                f = polyval(flipud(p),t);
                residue=f(fitrange(1):fitrange(end))'-Dt(fitrange(1):fitrange(end));
                subplot(Infos.plot_size(1),Infos.plot_size(2),4);%fitted
                plot(t,f,'k','LineWidth',2);
                title(cat(2,'D=',num2str(p(2)),' se=',num2str(S.se(2))));
                S1D_plot(5,t(fitrange(1):fitrange(end)),residue,[],'residue');
                D_temp(n,1:4)=[p(2) S.se(2) -S.coeffcorr(1,2) fitrange(end)-fitrange(1)];%D_estimate,goodness of fit,degree of freedom
            end
        else
            disp 'no fit/need more points for robustfit';
        end

end

