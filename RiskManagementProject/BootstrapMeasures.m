function [ES, VaR] = BootstrapMeasures(alpha, weights, portfolioValue, riskMeasureTimeIntervalInDays, returnsSelected, simulations)
% BOOTSTRAPMEASURES Computes VaR and ES using a Bootstrap resampling method.
%
% This function generates synthetic scenarios by resampling historical returns 
% with replacement, calculates portfolio losses, and derives risk measures.
%
% INPUTS:
%  - alpha: Confidence level (e.g., 0.95).
%  - weights: [N x 1] vector of portfolio weights.
%  - portfolioValue: Current total monetary value of the portfolio.
%  - riskMeasureTimeIntervalInDays: Holding period (T) for scaling.
%  - returnsSelected: [Obs x N] matrix of historical log-returns.
%  - simulations: Number of Bootstrap iterations (e.g., 200).

%% 1. Resampling Logic (Bootstrap)
rng(5); % Set seed for reproducibility

% Get the number of available historical observations
numObs = size(returnsSelected, 1);

% Generate random indices with replacement (Bootstrap sampling)
% We pick 'simulations' number of days from the history at random
random_idx = randi(numObs, simulations, 1);

% Create the bootstrap returns matrix [simulations x N]
returns_bootstrap = returnsSelected(random_idx, :);

%% 2. Portfolio Returns and Losses Calculation
% Matrix multiplication: [simulations x N] * [N x 1] = [simulations x 1]
portReturns = returns_bootstrap * weights;

% Monetary Losses: L = -V0 * r_p
Losses = -portfolioValue * portReturns;

%% 3. Sorting and Quantile Estimation
% Sort losses from largest to smallest
Losses_sorted = sort(Losses, 'descend');

% Calculate the index for the VaR quantile based on the number of simulations
idx = floor((1 - alpha) * simulations);
if idx < 1, idx = 1; end % Safety floor

% 1-Day VaR (monetary)
VaR_1d = Losses_sorted(idx);

% 1-Day Expected Shortfall (Mean of losses exceeding VaR)
ES_1d = mean(Losses_sorted(1:idx));

%% 4. Time Scaling (Square Root of Time Rule)
% Scale from 1-day to T-days using sqrt(T)
timeFactor = sqrt(riskMeasureTimeIntervalInDays);

VaR = VaR_1d * timeFactor;
ES = ES_1d * timeFactor;

end