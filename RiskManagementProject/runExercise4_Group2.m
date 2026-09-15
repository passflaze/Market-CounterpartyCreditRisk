% Exercise 4 - Group2

% ADD TO PATH: HelperMBS

clc;
close all;
clear all;
warning('off', 'MATLAB:quadgk:minStepSize');

formatDate = 'dd/mm/yyyy'; 
[datesCurveInput, ratesCurveInput] = readExcelData('ExcelData\MktData_CurveBootstrap.xls', formatDate);
[BootstrapDates, BootstrapDiscounts, BootstrapZeroRates] = bootstrap(datesCurveInput, ratesCurveInput);

%%

DefaultProb = 0.05;
Correlation = 0.4;
Ku = 0.09;
Kd = 0.05; 
recovery = 0.2;
I = 400;
flag = 1; % for exact binomial
TrancheNotional = 1e9 * (Ku-Kd);

RefDate_es4 = datenum(datetime(2008, 2, 15));
SettlementDate_es4 = datenum( datetime(2008, 2, 19) );
EndDate_es4 = datenum( datetime(2011, 2, 19) );

DiscountFactor = fromdatetodiscount(SettlementDate_es4, BootstrapDates, BootstrapZeroRates, EndDate_es4);


%% I = 400

price_exact = TranchePricing(DefaultProb, Correlation, Ku, Kd, recovery, DiscountFactor, I, 1);
price_LHP = TranchePricing(DefaultProb, Correlation, Ku, Kd, recovery, DiscountFactor, I, 3);
price_KL = TranchePricing(DefaultProb, Correlation, Ku, Kd, recovery, DiscountFactor, I, 2);


% Displaying results
fprintf('\n--- Tranche Pricing Results for I = %d ---\n', I);
fprintf('Exact Price:   %.4f%%\n', price_exact);
fprintf('LHP Price:     %.4f%%\n', price_LHP);
fprintf('KL Price:      %.4f%%\n', price_KL);

% Calculate and print the relative error as requested in the case study
rel_err_LHP = (abs(price_exact - price_LHP) / price_exact) * 100;
fprintf('Relative Error (LHP vs Exact): %.4f%%\n', rel_err_LHP);

%% I = (10, 2*10^4) - Mezzanine Tranche

I_grid = round(logspace(1, log10(2e4), 25));

% Initialize price vectors
price_exact = nan(size(I_grid));
price_LHP   = nan(size(I_grid));
price_KL    = nan(size(I_grid));

fprintf('Starting Mezzanine Tranche study...\n');

for j = 1:length(I_grid)
    I_current = I_grid(j);
    
    % 1. LHP Solution (always computable)
    price_LHP(j) = TranchePricing(DefaultProb, Correlation, Ku, Kd, recovery, DiscountFactor, I_current, 3);
    
    % 2. Exact Solution (only if I is not too large)
    price_exact(j) = TranchePricing(DefaultProb, Correlation, Ku, Kd, recovery, DiscountFactor, I_current, 1);
   
    % 3. KL Solution (to be implemented in your switch case flag=2)
    price_KL(j) = TranchePricing(DefaultProb, Correlation, Ku, Kd, recovery, DiscountFactor, I_current, 2);
end

% Plotting
figure('Color', 'w', 'Name', 'Tranche Pricing Convergence');
% Use semilogx for a logarithmic scale on the x-axis (I)
semilogx(I_grid, price_LHP * 100, 'r--', 'LineWidth', 1.5, 'DisplayName', 'LHP Solution');
hold on;
semilogx(I_grid, price_exact * 100, 'bo-', 'LineWidth', 1.2, 'MarkerSize', 4, 'DisplayName', 'Exact Solution');
semilogx(I_grid, price_KL * 100, 'g^-', 'LineWidth', 1.2, 'MarkerSize', 4, 'DisplayName', 'KL Approximation');

grid on;
xlabel('Number of Mortgages (I) - Log Scale');
ylabel('Tranche Price (% of Face Value)');
title('Mezzanine Tranche Price: Exact vs KL vs LHP');
legend('Location', 'best');

% Axis formatting
set(gca, 'XMinorGrid', 'on');

%% I = (10, 2*10^4) - EQUITY TRANCHE; ADEQUATE KL PRICING

Ku_eq = 0.05; Kd_eq = 0.00;

% Reuse the same I_grid
price_E_exact = nan(size(I_grid));
price_E_LHP   = nan(size(I_grid));
price_E_KL    = nan(size(I_grid));
price_E_KL_rob= nan(size(I_grid));

fprintf('Starting Equity Tranche study...\n');

for j = 1:length(I_grid)
    I_curr = I_grid(j);
    
    price_E_exact(j) = TranchePricing(DefaultProb, Correlation, Ku_eq, Kd_eq, recovery, DiscountFactor, I_curr, 1);
    price_E_LHP(j)   = TranchePricing(DefaultProb, Correlation, Ku_eq, Kd_eq, recovery, DiscountFactor, I_curr, 3);
    price_E_KL(j)    = TranchePricing(DefaultProb, Correlation, Ku_eq, Kd_eq, recovery, DiscountFactor, I_curr, 2);
    price_E_KL_rob(j)= TranchePricing(DefaultProb, Correlation, Ku_eq, Kd_eq, recovery, DiscountFactor, I_curr, 4);
end

% Plotting Equity Results
figure('Color', 'w', 'Name', 'Equity Tranche Pricing');
semilogx(I_grid, price_E_exact * 100, 'bo-', 'LineWidth', 1.2, 'DisplayName', 'Exact Solution'); hold on;
semilogx(I_grid, price_E_KL * 100, 'g^-', 'LineWidth', 1.2, 'DisplayName', 'KL (Standard - Inadequate)');
semilogx(I_grid, price_E_KL_rob * 100, 'ks-', 'LineWidth', 1.2, 'DisplayName', 'KL (Robust - Corrected)');
semilogx(I_grid, price_E_LHP * 100, 'r--', 'LineWidth', 1.5, 'DisplayName', 'LHP Solution');

grid on;
xlabel('Number of Mortgages (I) - Log Scale');
ylabel('Tranche Price (% of Face Value)');
title('Equity Tranche (0% - 5%): Analyzing KL Inadequacy');
legend('Location', 'best');