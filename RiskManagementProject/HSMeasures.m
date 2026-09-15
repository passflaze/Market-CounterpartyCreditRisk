function [ES, VaR] = HSMeasures(alpha, weights, portfolioValue, riskMeasureTimeIntervalInDays, returns)
% Historical Simulation VaR and ES for a linear portfolio
%
% INPUT:
%   alpha  : confidence level (e.g. 0.99)
%   weights: column vector of portfolio weights
%   portfolioValue: current portfolio value
%   riskMeasureTimeIntervalInDays: risk horizon in days
%   returns: matrix of daily log-returns
%
% OUTPUT:
%   ES  : Expected Shortfall
%   VaR : Value at Risk

% Checks 
if size(weights,2) > 1
    weights = weights';
end

if abs(sum(weights) - 1) > 1e-10
    warning('Weights do not sum exactly to 1.');
end

% Historical portfolio daily returns
portReturns = returns * weights;   

% Convert returns into monetary losses
losses = - portfolioValue * portReturns;

% Sort losses in increasing order: from smallest losses (or gains) to greatest ones
lossesSorted = sort(losses,'ascend');

% Empirical VaR at level alpha
T = length(lossesSorted);
idx = ceil(alpha * T); %level alpha
VaR_1d = lossesSorted(idx+1);


% Historical ES = average loss beyond VaR
ES_1d = mean(lossesSorted(idx+1:end));

% Time scaling
timehorizon = sqrt(riskMeasureTimeIntervalInDays);
VaR = VaR_1d * timehorizon;
ES = ES_1d * timehorizon;

end