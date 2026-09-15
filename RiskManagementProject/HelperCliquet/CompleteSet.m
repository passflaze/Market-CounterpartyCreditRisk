function [spread_6y, pp_model] = CompleteSet(tenors, spreads_bps, targetTenor, plotFlag)
% Interpolates CDS spreads using a Cubic Spline.
%
% INPUTS:
%   tenors      - Vector of market maturities in years (e.g., [1; 2; 3; 4; 5; 7])
%   spreads_bps - Vector of corresponding CDS spreads in basis points
%   targetTenor - The specific year to estimate (e.g., 6)
%   plotFlag    - Binary flag: 1 to display the chart, 0 to skip
%
% OUTPUTS:
%   spread_6y   - The estimated spread at the targetTenor
%   pp_model    - The Piecewise Polynomial structure for further evaluations

% 1. Create the Cubic Spline Interpolant
% This uses the 'not-a-knot' end condition to ensure C2 continuity
pp_model = spline(tenors, spreads_bps);

% 2. Evaluate the spline at the desired target year
spread_6y = ppval(pp_model, targetTenor);

% 3. Conditional Visualization
if plotFlag == 1
    % Generate a high-resolution grid for smooth plotting
    t_fine = linspace(min(tenors), max(tenors), 200);
    s_fine = ppval(pp_model, t_fine);

    figure('Color', 'w');
    hold on;
    
    % Plot the continuous spline curve
    plot(t_fine, s_fine, 'b-', 'LineWidth', 2, 'DisplayName', 'Cubic Spline Curve');
    
    % Plot the original market data points
    plot(tenors, spreads_bps, 'ko', 'MarkerFaceColor', [0.3 0.3 0.3], ...
         'MarkerSize', 8, 'DisplayName', 'Market Quotes (ISP)');
    
    % Highlight the interpolated target point
    plot(targetTenor, spread_6y, 'rs', 'MarkerSize', 12, ...
         'MarkerFaceColor', 'r', 'DisplayName', sprintf('Estimated %gy Point', targetTenor));

    % Aesthetics and Labeling
    grid on;
    xlabel('Tenor (Years)', 'FontSize', 12);
    ylabel('CDS Spread (bps)', 'FontSize', 12);
    title(['CDS Spread Curve Interpolation - ISP (Feb 2008)'], 'FontSize', 14);
    legend('Location', 'southeast', 'FontSize', 10);
         
    hold off;
end
end