function [datesCDS, survProbs, intensities] = bootstrapCDS(datesDF, zeroRates, datesCDS, spreadCDS, flag, recovery)
    % BOOTSTRAPCDS Calibrates survival probabilities and hazard rates from CDS market data.
    %
    % This function derives the term structure of credit risk by finding survival 
    % probabilities that equate the Present Value of the Premium Leg (fees paid) 
    % to the Protection Leg (potential loss coverage).
    %
    % INPUTS:
    %   datesDF:     Reference dates for the risk-free zero curve.
    %   zeroRates:   Zero-coupon rates corresponding to datesDF.
    %   datesCDS:    Maturity dates of the CDS instruments (including inception t0).
    %   spreadCDS:   CDS market quotes in basis points for each maturity.
    %   flag:        Calibration method (1=No Accrual, 2=With Accrual, 3=Jarrow-Turnbull).
    %   recovery:    Expected recovery rate (e.g., 0.40).
    %
    % OUTPUTS:
    %   datesCDS:    The adjusted business dates used for the bootstrap.
    %   survProbs:   Calibrated survival probabilities P(t_i > T) at each node.
    %   intensities: Piecewise constant hazard rates (lambda) for each interval.

    % 1. Date Adjustment and Discount Factor Retrieval
    % Adjusts input dates to business days following the specified convention.
    datesCDS = ConvertDates(datesCDS);
    t0 = datesCDS(1);
    
    % Bootstraps/interpolates discount factors from the zero curve at CDS maturities.
    % These factors represent the risk-free cost of money.
    discounts = fromdatetodiscount(t0, datesDF, zeroRates, datesCDS(2:end));
    
    n = length(spreadCDS);
    survProbs = zeros(n + 1, 1);
    survProbs(1) = 1.0; % Survival probability at inception (t0) is 1.0
    intensities = zeros(n, 1);
    
    % 2. Credit Parameter Setup
    S = spreadCDS(:) / 10000; % Convert basis points to decimal spreads
    LGD = 1 - recovery;       % Loss Given Default.

    switch flag
    case 1 % APPROXIMATION: No Accrual (Simplified Premium Leg calculation)
        for i = 1:n
            % Numerical root finding for the survival probability at node i+1.
            target = @(x) cds_equation(x, i, survProbs, datesCDS, S(i), discounts, LGD, false);
            survProbs(i+1) = fzero(target, [1e-8, survProbs(i)]);
            
            % Marginal intensity lambda: -log(P_end / P_start) / TimeFraction.
            d_curr = yearfrac(datesCDS(i), datesCDS(i+1), 3); % Actual/365
            intensities(i) = -log(survProbs(i+1) / survProbs(i)) / d_curr;
        end
        
    case 2 % EXACT: With Accrual (Includes premium accrued up to the default time)
        for i = 1:n
            target = @(x) cds_equation(x, i, survProbs, datesCDS, S(i), discounts, LGD, true);
            survProbs(i+1) = fzero(target, [1e-8, survProbs(i)]);
            
            d_curr = yearfrac(datesCDS(i), datesCDS(i+1), 3);
            intensities(i) = -log(survProbs(i+1) / survProbs(i)) / d_curr;
        end
        
    case 3 % Jarrow-Turnbull Logic (Direct Hazard Rate mapping)
        for i = 1:n
            dt = yearfrac(datesCDS(i), datesCDS(i+1), 3); 
            T_curr = yearfrac(datesCDS(1), datesCDS(i+1), 3); 
            
            % Average intensity implied by the spread for the total period.
            lambda_media_market = S(i) / LGD;
            
            if i == 1
                intensities(i) = lambda_media_market;
            else
                % Solves for marginal intensity by accounting for previous period areas.
                lambda_sum = sum(intensities(1:i-1) .* diff(yearfrac(datesCDS(1), datesCDS(1:i), 3)));
                intensities(i) = (lambda_media_market * T_curr - lambda_sum) / dt;
            end
            
            % Update survival probability based on the solved intensity.
            survProbs(i+1) = survProbs(i) * exp(-intensities(i) * dt);
        end
    end
end

% --- Support Function: CDS Equilibrium Equation (NPV = 0) ---
function diff_val = cds_equation(x, i, survProbs, datesCDS, current_S, df, LGD, useAccrual)
    p_curr = [survProbs(1:i); x];
    FeeLeg = 0;
    ContingentLeg = 0;
    
    for j = 1:i
        % Interval calculation for fee payments (Standard ACT/360 for CDS).
        delta = yearfrac(datesCDS(i), datesCDS(i+1), 2); 
        
        % Fee Leg: Value of the periodic payments made by the buyer.
        FeeLeg = FeeLeg + current_S * delta * df(j) * p_curr(j+1);
        
        % Accrual: Premium paid for the fraction of the period before default.
        if useAccrual
            FeeLeg = FeeLeg + current_S * 0.5 * delta * df(j) * (p_curr(j) - p_curr(j+1));
        end
        
        % Protection Leg: Value of the payment received if default occurs.
        ContingentLeg = ContingentLeg + LGD * df(j) * (p_curr(j) - p_curr(j+1));
    end
    
    % Return the difference (Market is fair when NPV = 0).
    diff_val = FeeLeg - ContingentLeg;
end