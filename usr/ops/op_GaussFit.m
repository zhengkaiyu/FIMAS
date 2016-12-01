function [ result, messages ] = op_GaussFit( input_args )
%OP_GAUSSFIT Summary of this function goes here
%   Detailed explanation goes here
 %====================Gaussian fit========================
            [Estimates,flag]=fitcurve(guess,x,(tofit(k,:)));
            if (flag==0)|Estimates(1)<0|Estimates(2)<0
                Estimates=guess;
                guess=Infos.param_guess;
                guess(2)=t(k)*Infos.param_guess(2);
            else
                guess=Estimates;
            end
            %fill D-t vector
            Dt(k)=Estimates(2);
            %calculate error
            fitted(k,:)=(Estimates(1)/((4*pi*Estimates(2)).^1.5))*exp(-((x-Estimates(3)).^2)/(4*Estimates(2)));
            fitted(k,:)=fitted(k,:).*(fitted(k,:)<Infos.saturate)+Infos.saturate*(fitted(k,:)>=Infos.saturate);
            if ~isreal(fitted(k,:))
                dbstop
            end
            show_percentage_done(k,length(t),1);
            k=k+1;

end

