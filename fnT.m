function dy = fnT(t,y,pI,pD,lambda)

If = polyval(pI,t);

g = polyval(pD,t);
dpD = polyder(pD);
dgdt = polyval(dpD,t);

dy = -(lambda*y)-(g*If)+((y/g)*dgdt);  % ODE for T