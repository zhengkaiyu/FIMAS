function [ g, s ] = phasor_transform(t, I, omega)
I_tot=trapz(t,I,1);
g=trapz(t,bsxfun(@times,I,cos(omega*t)),1)./I_tot;
s=trapz(t,bsxfun(@times,I,sin(omega*t)),1)./I_tot;
end