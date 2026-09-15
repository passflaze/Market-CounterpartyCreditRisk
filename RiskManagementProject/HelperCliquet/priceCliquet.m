function [CliquetPrice, CVA, CliquetRiskyPrice] = priceCliquet(Notional, sigma, t0, payment_dates, B, lambdas, R)
% Vectorized pricing of a Sum-of-Calls Cliquet with CVA

% Ensure payment_dates is a column vector for consistency
payment_dates = payment_dates(:);
numLegs = length(payment_dates);

% Create a vector of start dates: [t0, t1, t2, ..., tn-1]
start_dates = [t0; payment_dates(1:end-1)];

% Vectorized calculation of time intervals (tau)
tau = yearfrac(start_dates, payment_dates, 3);

% Vectorized Forward Rates
f = -log(B(2:end) ./ B(1:end-1)) ./ tau;

% Vectorized Black-Scholes tranche values (ATM: S=1, K=1)
tranches = blsprice(1, 1, f, tau, sigma);

% Total Risk-Free Price
CliquetPrice = sum(tranches) * Notional;

% Marginal Probabilities of Default
PD_marginal = 1 - exp(-lambdas(:) .* tau);

% Expected Exposure (EE): sum of residual future tranches
ee_sums = flip(cumsum(flip(tranches)));

% For CVA, EE at time ti is the sum of tranches from i+1 to n
EE = [ee_sums(2:end); 0] * Notional;

% CVA = (1 - Recovery) * Sum(Expected Exposure * Marginal PD)
CVA = (1 - R) * sum(EE .* PD_marginal);

% Final Adjustment
CliquetRiskyPrice = CliquetPrice - CVA;

end