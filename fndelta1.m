function dy = fndelta1(t,y,pT,pI,lambda)

f = polyval(pT,t);
dpT = polyder(pT);
dfdt = polyval(dpT,t);

If = polyval(pI,t);

dy = ((If/f)*y^2)+((lambda+(dfdt/f))*y);  % ODE for delta
end