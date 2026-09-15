function VaR = DeltaNormalVaR(alpha, numberOfShares, numberOfPuts, stockPrice, strike, rate, dividendYield, volatility, TTMinYears, riskMeasureTimeIntervalInDays, returns, flag)
% Calculates Linear VaR using Delta-Normal approach
%
% INPUT: flag = 1 Normal Returns 
%        flag = 0 Historical simulation 

% 1. Calculate Put Delta (Black-Scholes)
[~, putDelta] = blsdelta(stockPrice, strike, rate, TTMinYears, volatility, dividendYield);

% 2. Calculate Portfolio Sensitivity (Dollar Delta)
% sensPort = Euro lost for 100% stock move
sensPort = (numberOfShares * stockPrice * 1) + (numberOfPuts * stockPrice * putDelta);

switch flag
    case 0
        %% --- Historical Simulation (Linearized) ---
        % Scale returns by sqrt of time (risk factor scaling)
        scalingFactor = sqrt(riskMeasureTimeIntervalInDays);
        losses = - sensPort * returns * scalingFactor;
        
        % Identify VaR from sorted distribution
        sortedLosses = sort(losses, 'descend');
        N = length(sortedLosses);
        % Using max(1,...) to avoid index 0 if N is small
        index_VaR = max(1, floor((1-alpha) * N)); 
        VaR = sortedLosses(index_VaR);
     
    case 1
        %% --- Parametric Normal ---
        % Estimating daily parameters from the provided returns
        mu_daily = mean(returns);
        sigma_daily = std(returns);

        % Linearized Loss parameters (1-day)
        % mu_L: expected loss (negative if profit)
        % sigma_L: dispersion of loss
        mu_L = -sensPort * mu_daily;
        sigma_L = abs(sensPort) * sigma_daily;

        % Time Scaling to the risk horizon (h days)
        h = riskMeasureTimeIntervalInDays;
        
        % Mean scales linearly with time
        mu_h = h * mu_L;
        % Volatility scales with the square root of time
        sigma_h = sqrt(h) * sigma_L;
    
        % Parametric VaR formula: Mean + Z_alpha * StdDev
        z_score = norminv(alpha);
        VaR = mu_h + z_score * sigma_h;
end
end