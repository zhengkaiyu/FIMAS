function sse = chi2gauss2dfunc(p, x, y, f, sl)
%CHI2GAUSS2DFUNC Summary of this function goes here
%   Detailed explanation goes here
FittedSurface = gauss2dfunc(p,x,y);
FittedSurface(FittedSurface>=sl) = sl;
ErrorVector = (FittedSurface - f);
ErrorVector = ErrorVector .^ 2;
sse = sum(ErrorVector(:));
end