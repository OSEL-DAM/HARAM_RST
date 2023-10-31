function out = LHS(mu,sigma,N,plotBool)
%% LATIN HYPERCUBE SAMPLING [LHS]
% This code is used to generate Ns number of random samples from computed
% PDF (probability density function) and CDF (cumulative distribution
% function) curves, given known mean and standard deviation values. Can run
% this multiple time when mu, sigma, and N are supplied vectors (Index
% cooresponds to specific LHS run.
%
% Inputs
%  mu: mean (postive number: scalar or vector)
%  sigma: standard deviation (number: scalar or vector)
%  N: Number of LHS samples, number of sample bands of equal probability (number: scalar)
%  plotBool: Bool to enable ploting of the CDF and PDF (scalar bool, default: false)

arguments
    mu double {mustBeNumeric,mustBeVector}
    sigma double {mustBePositive,mustBeVector,mustBeEqualSize(mu,sigma)}
    N (1,1) double {mustBePositive,mustBeInteger}
    plotBool (1,1) {mustBeNumericOrLogical} = false
end

out = zeros(N,numel(sigma));
for idx = 1:numel(sigma)
    x = mu(idx)-(3*sigma(idx)):0.01:mu(idx)+(3*sigma(idx));
    py = normpdf(x,mu(idx),sigma(idx)); % Requires SML Toolbox
    cy = normcdf(x,mu(idx),sigma(idx)); % Requires SML Toolbox
    out(:,idx)=x(1)+(x(end)-x(1))*rand(N,1);

    if plotBool
        figure(idx*2-1)
        plot(x,py);
        ylabel('p(\gamma)'); xlabel('\gamma');
        title("Probability Density Function","\mu = "+string(mu(idx))+", \sigma = "+string(sigma(idx)))

        figure(idx*2)
        plot(x,cy);
        ylabel('c(\gamma)'); xlabel('\gamma');
        title("Cumulative Distribution Function","\mu = "+string(mu(idx))+", \sigma = "+string(sigma(idx)))
    end % if plotBool
end % for idx = 1:numel(sigma)
end % function

% ---- Local Validation Functions ----
function mustBeEqualSize(a,b)
% Test for equal size
if ~isequal(size(a),size(b))
    eid = 'Size:notEqual';
    msg = 'mu and sigma must be the same size vector.';
    throwAsCaller(MException(eid,msg))
end % if ~isequal(size(a),size(b))
end % function mustBeEqualSize(a,b)
