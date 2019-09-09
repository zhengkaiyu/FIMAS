function res = chi2expfunc(lambda,t,y)
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