function [VaR] = PlausibilityCheckVaR(alpha, weights, portfolioValue, riskMeasureTimeIntervalInDays, returns)
% Computes a parametric Gaussian VaR as a sanity check.
%
% This function uses the Variance-Covariance approach (Gaussian assumption)
% to provide a benchmark. It scales the 1-day risk to the desired horizon
% using the Square Root of Time rule.
%
% INPUTS:
%  - alpha:                          Confidence level (e.g., 0.95).
%  - weights:                        [N x 1] vector of portfolio weights.
%  - portfolioValue:                 Total monetary value of the portfolio.
%  - riskMeasureTimeIntervalInDays:  Time horizon for the VaR (T).
%  - returns:                        [obs x N] matrix of historical log-returns.
%
% OUTPUTS:
%  - VaR: The parametric T-day Value at Risk (monetary).

%% 1. Individual Asset Volatility
% Standard deviation of each asset (1-day)
sigma_1d = std(returns); % [1 x N]

%% 2. Individual Asset Risk (1-day Parametric VaR)
% Using the Gaussian quantile (z-score)
z_score = norminv(alpha); 
% Individual VaR in percentage for 1 day
individual_VaR_1d = sigma_1d * z_score; % [1 x N]

%% 3. Portfolio Correlation Structure
% Correlation matrix to account for diversification
C_matrix = corr(returns); % [N x N]

%% 4. Portfolio Risk Aggregation (1-day)
% weighted_risks represents the contribution of each asset to the portfolio VaR
weighted_risks = (weights(:) .* individual_VaR_1d'); % [N x 1]

% Portfolio 1-day VaR in percentage
% Formula: sqrt( w_v' * Corr * w_v )
portfolio_VaR_1d_pct = sqrt(weighted_risks' * C_matrix * weighted_risks);

%% 5. Time Scaling and Monetary Conversion
% Scale the 1-day VaR to the T-day horizon using sqrt(T)
VaR_T_pct = portfolio_VaR_1d_pct * sqrt(riskMeasureTimeIntervalInDays);

% Final monetary VaR
VaR = VaR_T_pct * portfolioValue;

end