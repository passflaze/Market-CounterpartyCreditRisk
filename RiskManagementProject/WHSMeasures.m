function [ES, VaR] = WHSMeasures(alpha, lambda, weights, portfolioValue, riskMeasureTimeIntervalInDays, returns)
% Weighted Historical Simulation VaR and ES
%
% INPUT:
%   alpha  : confidence level (e.g. 0.99)
%   lambda : exponential decay factor (e.g. 0.98)
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

[T, N] = size(returns);

if length(weights) ~= N
    error('Dimension mismatch: length(weights) must equal number of columns in returns.');
end

% Portfolio returns 
portReturns = returns * weights;   

% Scale to risk horizon
portReturnsHorizon = riskMeasureTimeIntervalInDays * portReturns;

% Convert into monetary losses
losses = - portfolioValue * portReturnsHorizon;   

% Exponential weights on historical scenarios 
% Oldest observation for t=1, most recent for t=T
scenarioWeights = (1 - lambda) * lambda.^(T-1:-1:0)';
scenarioWeights = scenarioWeights / sum(scenarioWeights);   % normalization


% Sort losses and reorder probabilities accordingly
[lossesSorted, idxSort] = sort(losses, 'ascend'); %returns ordered losses and original indexes
weightsSorted = scenarioWeights(idxSort);

% Weighted cumulative distribution
cumWeights = cumsum(weightsSorted);

% Weighted VaR
idxVaR = find(cumWeights >= alpha, 1, 'first');
VaR = lossesSorted(idxVaR);

% Weighted ES 
tailLosses = lossesSorted(idxVaR:end);
tailWeights = weightsSorted(idxVaR:end);

% Renormalize tail weights so they sum to 1
tailWeights = tailWeights / sum(tailWeights);

ES = sum(tailWeights .* tailLosses);

end