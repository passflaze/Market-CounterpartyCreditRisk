function VaR = FullMonteCarloVaR(alpha, numberOfShares, numberOfPuts, stockPrice, strike, rate, dividendYield, volatility, TTMinYears, riskMeasureTimeIntervalInDays, returns)
% Calculates VaR using Full Revaluation approach

% 1. Initial Portfolio Value (V0)
[~, putPrice0] = blsprice(stockPrice, strike, rate, TTMinYears, volatility, dividendYield);

V0 = (numberOfShares * stockPrice) + (numberOfPuts * putPrice0);

% 2. Simulate "Tomorrow" Scenarios
% Update Time: T moves forward by the risk interval
T1 = TTMinYears - (riskMeasureTimeIntervalInDays / 365);

% Update Stock Price: Shock S0 with the historical returns
% Note: if interval > 1, returns should technically be multi-day 
% but standard practice is S1 = S0 * exp(returns * sqrt(dt))
S1 = stockPrice * exp(returns * sqrt(riskMeasureTimeIntervalInDays));

numScenarios = length(S1);
pnL = zeros(numScenarios, 1);

% 3. Full Revaluation Loop
for i = 1:numScenarios
    Si = S1(i);
    
    % Re-price Put for scenario i
    [~, putPriceI] = blsprice(Si, strike, rate, T1, volatility, dividendYield);
    
    % Scenario Portfolio Value and Profit/Loss
    Vi = (numberOfShares * Si) + (numberOfPuts * putPriceI);
    pnL(i) = Vi - V0;
end

% 4. Identify VaR
losses = -pnL;

sortedLosses = sort(losses, 'descend');
VaR = sortedLosses(floor((1-alpha) * numScenarios));

end