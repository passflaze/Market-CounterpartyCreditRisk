function [Probability] = p_cond(yi, DefaultProb, Correlation)
% Computes the conditional default probability p(y) in the Vasicek model.
%
% INPUTS:
%   - yi:            Realization of the systemic risk factor (Standard Normal).
%   - DefaultProb:   Unconditional (marginal) default probability (p).
%   - Correlation:   Asset correlation (rho) between mortgages.
%
% OUTPUTS:
%   - Probability:   Conditional default probability p(yi).

%% 1. Threshold Calculation

C = norminv(DefaultProb);

%% 2. Conditional Probability Formula

numerator = C - sqrt(Correlation) * yi;
denominator = sqrt(1 - Correlation);

Probability = normcdf(numerator / denominator);

end