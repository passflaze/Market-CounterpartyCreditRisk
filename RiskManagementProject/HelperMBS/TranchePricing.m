function [TranchePrice] = TranchePricing(DefaultProb, Correlation, Ku, Kd, recovery, DiscountFactor, I, flag)
% Computes the fair price of an MBS mezzanine tranche.
%
% This function estimates the price of a tranche (as a percentage of its face value)
% using three different approaches based on the Vasicek One-Factor Model.
%
% INPUTS:
%   - DefaultProb:    Marginal probability of default (p) for each mortgage.
%   - Correlation:    Asset correlation (rho) between mortgages.
%   - Notional:       Total portfolio notional (used if absolute price is needed).
%   - Ku:             Detachment point (upper threshold of the tranche).
%   - Kd:             Attachment point (lower threshold of the tranche).
%   - recovery:       Average recovery rate (pi) of the mortgages.
%   - DiscountFactor: Risk-free discount factor B(0,T).
%   - I:              Number of mortgages in the portfolio.
%   - flag:           Method selector (1: Exact Binomial, 2: KL Approx, 3: LHP, 4: KL-Robust Method for Equity).
%
% OUTPUTS:
%   - TranchePrice:   Price of the tranche in relative terms [0, 1].
switch flag
    case 1 % FULL EXACT CALCULATION (Conditional Binomial)
        % Under the finite portfolio assumption (I), the number of defaults 'm'
        % follows a Binomial distribution B(I, p(y)) for every scenario 'y'.
        
        m = 0:I;
        % Vector of percentage losses for each possible number of defaults
        loss_m = LossTranche(m, I, Ku, Kd, recovery); 
    
        % Integrand: f(y) * sum_{m=0}^{I} [ P(M=m|y) * Loss(m) ]
        % We use arrayfun to ensure compatibility with quadgk's vectorization requirements.
        integrand = @(y) arrayfun(@(yi) ...
            sum(binopdf(m, I, p_cond(yi, DefaultProb, Correlation)) .* loss_m), y) .* normpdf(y);
    
        % Numerical integration over the systemic factor Y ~ N(0,1)
        expectedLoss = quadgk(integrand, -inf, inf);
    case 2 % KULLBACK-LEIBLER APPROXIMATION
        
        K_fun = @(z, p) z.*log(max(z,1e-10)./p) + (1-z).*log(max(1-z,1e-10)./(1-p));
    
        % 2. Define the pre-exponential term C_fun (Stirling Approximation)
        C_fun = @(z) sqrt(I ./ (2 * pi * max(z.*(1-z), 1e-10)));
    
        % 3. Define the INNER integral (with respect to the default fraction z)
        % This function must take a scenario y and return the expected loss E[L|y]
        inner_integral = @(y) arrayfun(@(yi) ...
            quadgk( @(z) C_fun(z) .* exp(-I * K_fun(z, p_cond(yi, DefaultProb, Correlation))) ...
            .* LossTranche(z, 1, Ku, Kd, recovery), 0, 1 ), y);
    
        % 4. Computation of the OUTER integral (with respect to the systemic factor y)
        integrand_y = @(y) inner_integral(y) .* normpdf(y);
        
        expectedLoss = quadgk(integrand_y, -inf, inf);
        
    case 3 % LARGE HOMOGENEOUS PORTFOLIO (LHP) HYPOTHESIS
        integrand = @(y) LossTranche(p_cond(y, DefaultProb, Correlation), 1, Ku, Kd, recovery) .* normpdf(y);
        expectedLoss = quadgk(integrand,-inf, inf); 
    case 4
        z_inf = 0.5 / I;

        K_fun = @(z, p) z.*log(max(z,1e-10)./p) + (1-z).*log(max(1-z,1e-10)./(1-p));
    
        % 2. Define the pre-exponential term C_fun (Stirling Approximation)
        C_fun = @(z) sqrt(I ./ (2 * pi * max(z.*(1-z), 1e-10)));
    
        % 3. Define the INNER integral (with respect to the default fraction z)
        % This function must take a scenario y and return the expected loss E[L|y]
        inner_integral = @(y) arrayfun(@(yi) ...
            quadgk( @(z) C_fun(z) .* exp(-I * K_fun(z, p_cond(yi, DefaultProb, Correlation))) ...
            .* LossTranche(z, 1, Ku, Kd, recovery), z_inf, 1 ), y);
    
        % 4. Computation of the OUTER integral (with respect to the systemic factor y)
        integrand_y = @(y) inner_integral(y) .* normpdf(y);
        
        expectedLoss = quadgk(integrand_y, -inf, inf);
end
% The price is the present value of the expected remaining principal
TranchePrice = DiscountFactor * (1 - expectedLoss);
end