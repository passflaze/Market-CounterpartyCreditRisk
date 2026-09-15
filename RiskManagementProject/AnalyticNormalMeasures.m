function [ES, VaR] = AnalyticNormalMeasures(alpha, weights, portfolioValue, riskMeasureTimeIntervalInDays, returns)
% Calculates VaR and ES using the Variance-Covariance (Parametric) method
%
% INPUTS:
%   alpha: Confidence level (e.g., 0.95)
%   weights: Vector of weights (e.g., [1/3; 1/3; 1/3])
%   portfolioValue: Total notional (e.g., 10,000,000)
%   riskMeasureTimeIntervalInDays: Holding period (1 for daily)
%   returns: Matrix of historical log-returns [T x N]

%% 1. Portfolio Loss
% Portfolio returns are the weighted sum of individual asset returns
ptf_returns = returns * weights;

% Define Loss as -Return
ptf_loss = - ptf_returns;

% Mean and std dev of the Daily Loss
mu = mean(ptf_loss);
sigma = std(ptf_loss);

% Scaling for the Time Horizon (Square Root of Time Rule)
mu_h = mu * riskMeasureTimeIntervalInDays;
sigma_h = sigma * sqrt(riskMeasureTimeIntervalInDays);

%% 2. Calculate Value at Risk (VaR)
z = norminv(alpha);
% Correct Parametric VaR formula for Loss Distribution
VaR = portfolioValue * ( mu_h + sigma_h * z );

%% 3. Calculate Expected Shortfall (ES)
pdf_z = normpdf(z);
ES = portfolioValue * ( mu_h + sigma_h * (pdf_z / (1 - alpha)) );

end