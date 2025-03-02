function sse = chi2gauss1dfunc( p, x, f, sl )
% p = paramters (mx3 vector)
% x = independent variable
% f = data function value f(x)
% sl = saturation level
FittedCurve = gauss1dfunc(p,x);
FittedCurve(FittedCurve>=sl) = sl;
ErrorVector = (FittedCurve - f);
ErrorVector = ErrorVector .^ 2;
sse = sum(ErrorVector(:));
end