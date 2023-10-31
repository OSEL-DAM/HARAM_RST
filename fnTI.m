function dy = fnTI(t,y,pD,lambda,gamma)

dy = zeros(2,1);

g = polyval(pD,t);
dpD = polyder(pD);
dgdt = polyval(dpD,t);

dy(1) = -(lambda*y(1))-(g*y(2))+((y(1)/g)*dgdt);  % ODE for T
dy(2) = -y(1)-(gamma*y(2));           % ODE for I
end