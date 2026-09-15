function [Loss] = LossTranche(m, I, Ku, Kd, recovery)
% Computes the loss of a specific tranche as a percentage of its face value.
%
% This function implements the piecewise linear loss function for a synthetic 
% CDO/MBS tranche. It maps the number of defaults in a portfolio of size 'I' 
% to the loss incurred by the mezzanine layer defined by [Kd, Ku].
%
% INPUTS:
%   - m:        Vector/Scalar of the number of defaults [0 to I].
%   - I:        Total number of mortgages in the portfolio.
%   - Ku:       Detachment point (upper bound, e.g., 0.09).
%   - Kd:       Attachment point (lower bound, e.g., 0.05).
%   - recovery: Average recovery rate per mortgage (e.g., 0.20).
%
% OUTPUTS:
%   - Loss:     Loss as a percentage of the tranche's thickness [0 to 1].

%% 1. Convert number of defaults to portfolio loss
% Portfolio loss fraction (z) accounts for the recovery rate: 
% if a mortgage defaults, we only lose (1 - recovery) of its value.
z = (m ./ I); 

%% 2. Adjust Attachment/Detachment points for Recovery
% Since z is the fraction of defaulted NOTIONAL, we need to find the 
% default thresholds that correspond to the capital losses Kd and Ku.
% Formula: Portfolio_Loss = Default_Fraction * (1 - Recovery)
d = Kd / (1 - recovery);
u = Ku / (1 - recovery);

%% 3. Piecewise Linear Payoff (Min-Max Logic)
% The tranche starts losing money after 'd' defaults and is wiped out at 'u'.
% We calculate the loss relative to the total thickness (u - d).

% Step 1: Calculate defaults exceeding the attachment point
term1 = max(z - d, 0);

% Step 2: Cap the loss at the detachment point (u - d is the max tranche loss)
% Step 3: Normalize by the tranche thickness to get a percentage [0, 1]
Loss = min(term1, u - d) ./ (u - d);

end