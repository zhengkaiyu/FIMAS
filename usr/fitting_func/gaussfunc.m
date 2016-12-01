function f = gaussfunc( p, x )
f = ((p(1)/((4*pi*p(2)).^1.5))*exp(-((x-p(3)).^2)/(4*p(2))));
end