function dy = fnI(t,y,pT,gamma)

f = polyval(pT,t);

dy = -f-(gamma*y);           % ODE for I
end