function [ g, s ] = phasor_transform(t, I, omega)
% transform f(t) into a point (g,s) in 2D plane 
% using discrete version of phasor transform
% input: dependent variable t (mx1)
%        I=f(t) (mxn)
%        omega=2*pi*(1/duration)
% output: (g,s) coordinate for each f(t)

% total integral for normalisation
I_tot = trapz(t,I,1);

% g component
g = trapz(t,bsxfun(@times,I,cos(omega*t)),1)./I_tot;

% s component
s = trapz(t,bsxfun(@times,I,sin(omega*t)),1)./I_tot;
end