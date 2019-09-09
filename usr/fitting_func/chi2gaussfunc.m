function sse = chi2gaussfunc( p, x, f, sl )
% p = paramters (1x3 vector)
% x = independent variable
% f = data function value f(x)
% sl = saturation level
FittedCurve = gaussfunc(p,x);
FittedCurve(FittedCurve>=sl) = sl;
ErrorVector = (FittedCurve - f);
ErrorVector = ErrorVector .^ 2;
sse = sum(ErrorVector(:));
end