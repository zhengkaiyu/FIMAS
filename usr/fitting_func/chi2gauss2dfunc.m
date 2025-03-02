function sse = chi2gauss2dfunc(p, x, y, f, sl)
% p = paramters (mx3 vector)
% x,y = independent variables
% f = data function value f(x,y)
% sl = saturation level
switch size(p,2)
    case 4
        FittedSurface = gauss2dsimplefunc(p,x,y);
    case 6
        FittedSurface = gauss2dgeneralfunc(p,x,y);
end
FittedSurface(FittedSurface>=sl) = sl;
ErrorVector = (FittedSurface - f);
ErrorVector = ErrorVector .^ 2;
sse = sum(ErrorVector(:));
end