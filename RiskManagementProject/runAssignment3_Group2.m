% Risk Measurements of a Linear Portfolio
% Financial Engineering: Politecnico Milano
% 
% ADD TO PATH: - ExcelData, HelperFunctions
%
% In order to run the script:
% >> runAssignment3_Group2
% THIS SCRIPT CONTAINS THE SOLUTIONS TO EXERCISES 0, 1, 2

clc;
clear all;
close all;

%% --- GLOBAL PARAMETERS ---
inputFile = 'ExcelData\sx5e_historical_data.xls';
formatDate = 'dd/mm/yyyy'; % IF YOU USE MACOSX KEEP MM instead of mm
refDate = datetime(2012, 7, 24);
NumberOfYears = 2;
timeWindow = 12 * NumberOfYears;

% bootstrap
[datesCurveInput, ratesCurveInput] = readExcelData('ExcelData\MktData_CurveBootstrap.xls', formatDate);
[curveDates, curveDiscounts, curveZeroRates] = bootstrap(datesCurveInput, ratesCurveInput);

%% --- EXERCISE 0: ANALYTIC NORMAL MEASURES ---
fprintf('--- Running Exercise 0 ---\n');

sharesList0 = cellstr({'LVMH'; 'Inditex'; 'BASF'}); 
numAssets0 = size(sharesList0, 1);
weights0 = (1/numAssets0) * ones(numAssets0, 1); 
portfolioValue0 = 10 * 1e6; 
alpha0 = 0.95;
riskDays = 1;

% Data Extraction
[tSelected0, returnsSelected0] = returnsOfInterest(inputFile, refDate, timeWindow, sharesList0, formatDate);

% Risk Computation (Analytic)
try
    [ES0, VaR0] = AnalyticNormalMeasures(alpha0, weights0, portfolioValue0, riskDays, returnsSelected0);
    fprintf('Analytic VaR: %.2f | ES: %.2f\n', VaR0, ES0);
catch err
    warning('AnalyticNormalMeasures failed: %s', e.message);
end

% Plausibility Check
Var_check = PlausibilityCheckVaR(alpha0,weights0,portfolioValue0,riskDays,returnsSelected0);
fprintf('Plausibility Check (Ex 0): %.2f\n\n', Var_check);


%% --- EXERCISE 1.a: HISTORICAL SIMULATION & BOOTSTRAP ---
fprintf('--- Running Exercise 1.a ---\n');

sharesList_1 = cellstr({'ENI'; 'Telefonica'; 'EON'; 'Daimler'});
alpha1 = 0.99;
numSimulations = 200;

% Data Extraction
[tSelected_1, returnsSelected_1] = returnsOfInterest(inputFile, refDate, timeWindow, sharesList_1, formatDate);

prices_1 = FindSharesValue(inputFile, refDate, sharesList_1);

% Portfolio Construction 
sharesquantity_1 = [18000; 25000; 15000; 9000];
Values_1 = sharesquantity_1 .* prices_1; 
portfolioValue_1 = sum(Values_1);
weights_1 = Values_1 ./ portfolioValue_1; 

% 1. Standard Historical Simulation
[ES1_HS, VaR1_HS] = HSMeasures(alpha1, weights_1, portfolioValue_1, riskDays, returnsSelected_1);

% 2. Bootstrap Simulation
[ES1_BS, VaR1_BS] = BootstrapMeasures(alpha1, weights_1, portfolioValue_1, riskDays, returnsSelected_1, numSimulations);

% 3. Plausibility Check
plausibility1 = PlausibilityCheckVaR(alpha1,weights_1,portfolioValue_1,riskDays,returnsSelected_1);

% Results Output
fprintf('Portfolio Value: %.2f\n', portfolioValue_1);
fprintf('HS VaR: %.2f | Bootstrap VaR: %.2f\n', VaR1_HS, VaR1_BS);
fprintf('HS ES: %.2f | Bootstrap ES: %.2f\n', ES1_HS, ES1_BS);
fprintf('Plausibility Check (Ex 1): %.2f\n\n', plausibility1);


%% --- EXERCISE 1.b: WEIGHTED HISTORICAL SIMULATION (WHS) ---
fprintf('--- Running Exercise 1.b ---\n');

sharesList_2 = cellstr({'Vivendi'; 'AXA'; 'ENEL'; 'Volkswagen'; 'Schneider'});
numAssets_2 = size(sharesList_2, 1);
weights_2 = (1/numAssets_2) * ones(numAssets_2, 1);
portfolioValue_2 = 1e6; %assumption
alpha2 = 0.99;
lambda = 0.98;

% Data Extraction
[tSelected_2, returnsSelected_2] = returnsOfInterest(inputFile, refDate, timeWindow, sharesList_2, formatDate);

% Weighted Historical Simulation
[ES2_WHS, VaR2_WHS] = WHSMeasures(alpha2, lambda, weights_2, portfolioValue_2, riskDays, returnsSelected_2);

% Plausibility Check
plausibility2 = PlausibilityCheckVaR(alpha2,weights_2,portfolioValue_2,riskDays,returnsSelected_2);

% Results Output
fprintf('WHS VaR (lambda=%.2f): %.2f\n', lambda, VaR2_WHS);
fprintf('WHS ES (lambda=%.2f): %.2f\n', lambda, ES2_WHS);
fprintf('Plausibility Check (Ex 2): %.2f\n', plausibility2);

%% --- EXERCISE 1.c: GAUSSIAN PCA APPROACH ---
fprintf('\n--- Running Exercise 1.c ---\n');

% Setup Parameters
idx_list = (2:26); % Extracting 25 assets
sharesList_3 = getShareListbyindex(idx_list);
numAssets_3 = size(sharesList_3, 1);
weights_3 = (1/numAssets_3) * ones(numAssets_3, 1); 
riskDays_3 = 10;
portfolioValue_3 = 15e6; 
alpha3 = 0.99;

% Data Extraction
[tSelected_3, returnsSelected_3] = returnsOfInterest(inputFile, refDate, timeWindow, sharesList_3, formatDate);

% Benchmark: Full Analytical VaR (No Dimensionality Reduction)
[ES_3_analytical, VaR_3_analytical] = AnalyticNormalMeasures(alpha3, weights_3, portfolioValue_3, riskDays_3, returnsSelected_3);

% PCA Convergence Loop
% We test k from 1 to the total number of assets
k_range = 1:numAssets_3;
VaR_PCA_results = zeros(numAssets_3, 1);
ES_PCA_results = zeros(numAssets_3,1);
percentage_errors = zeros(numAssets_3, 1);

fprintf('Starting PCA Sensitivity Analysis...\n');

for k = k_range
    % Compute PCA VaR for k components
    [~, current_VaR] = PCAMeasures(alpha3, k, weights_3, portfolioValue_3, riskDays_3, returnsSelected_3);
    
    VaR_PCA_results(k) = current_VaR;
    
    % Calculate Percentage Difference relative to Analytical Benchmark
    % Error = (PCA_VaR - Full_VaR) / Full_VaR
    percentage_errors(k) = abs((current_VaR - VaR_3_analytical)) / VaR_3_analytical * 100;
end

% Visualization of Convergence
figure('Name', 'PCA Convergence Analysis', 'Color', 'w');

% Plot 1: VaR Values Comparison
subplot(2,1,1);
plot(k_range, VaR_PCA_results, '-o', 'LineWidth', 1.5, 'MarkerSize', 4);
hold on;
yline(VaR_3_analytical, '--r', 'Full Analytical VaR', 'LineWidth', 2);
title('PCA VaR Convergence to Full Analytical Model');
xlabel('Number of Principal Components (k)');
ylabel('Value at Risk (€)');
grid on;
legend('PCA VaR', 'Full Benchmark', 'Location', 'southeast');

% Plot 2: Percentage Error (Precision)
subplot(2,1,2);
bar(k_range, percentage_errors, 'FaceColor', [0.2 0.6 0.8]);
title('Percentage Difference (PCA vs Analytical)');
xlabel('Number of Principal Components (k)');
ylabel('Error (%)');
grid on;

% Final Summary to Command Window
fprintf('\n--- Final Comparison (k = %d) ---\n', numAssets_3);
fprintf('Full Analytical VaR: (Mln)  %.2f €\n', VaR_3_analytical/1e6);
fprintf('Full PCA VaR (k=N): (Mln)   %.2f €\n', VaR_PCA_results(end)/1e6);
fprintf('Percentage Error:           %.4f %%\n', percentage_errors(end));
% Check plausibility 
plausibility_3 = PlausibilityCheckVaR(alpha3,weights_3,portfolioValue_3,riskDays_3,returnsSelected_3);
fprintf('\nPlausibility value is: (Mln) %.2f €\n', plausibility_3/1e6);


%% --- EXERCISE 2: DELTA NORMAL VAR & FULL MONTECARLO ---
fprintf('\n--- Running Exercise 2 ---\n');

stock_value_ex2 = 1.164 * 1e6;
K_ex2 = 28.5;
vol_ex2 = 0.223; % Yearly
div_ex2 = 0.051; % Yearly
alpha_ex2 = 0.99;
riskDays_ex2 = 1;
refDate_ex2 = datetime(2010, 02, 15);
NumberOfYears_ex2 = 2;
timeWindow_ex2 = 12 * NumberOfYears_ex2;
maturityDate_ex2 = datetime(2010, 4, 18);

% We assumed that the bootstrap is valid for the current date (15-02-2010)
% Retrieve 1y zero rate
t0 = datetime(2008,02,19); 
targetDate = datenum(t0+calyears(1));
discountTarget = fromdatetodiscount(datesCurveInput.settlement, curveDates, curveZeroRates, targetDate);
rate = -log(discountTarget) / yearfrac(datesCurveInput.settlement, targetDate, 3);

% Historical returns of Generali over 2 years
sharesList_ex2 = cellstr({'Generali'});
[tSelected_ex2, returnsSelected_ex2] = returnsOfInterest(inputFile, refDate_ex2, timeWindow_ex2, sharesList_ex2, formatDate);

% Spot price of Generali at refDate
opts = detectImportOptions(inputFile, 'Sheet', 'Data');
opts.VariableNamingRule = 'preserve';
shareData = readtable(inputFile, opts);

refDateNum_ex2 = datenum(refDate_ex2);
bbgCode_ex2 = underlyingCode('Generali');
[valuesGen, datesGen] = findSeries(shareData, bbgCode_ex2, formatDate);
[~, idxSpot_ex2] = closestDate(refDateNum_ex2, datesGen);
stockPrice_ex2 = valuesGen(idxSpot_ex2);

% Number of shares and number of puts 
numberOfShares_ex2 = ceil(stock_value_ex2 / stockPrice_ex2);
numberOfPuts_ex2 = numberOfShares_ex2;

% Time to maturity in years
TTM_ex2 = yearfrac(refDate_ex2, maturityDate_ex2, 3);


% VaR via Full Monte Carlo
VaR_MC_ex2 = FullMonteCarloVaR(alpha_ex2, numberOfShares_ex2, numberOfPuts_ex2, stockPrice_ex2, K_ex2, rate, div_ex2, vol_ex2, TTM_ex2, riskDays_ex2, returnsSelected_ex2);

% VaR via Delta Normal
flag = 0; % Historical Simulation 
VaR_DN_ex2 = DeltaNormalVaR(alpha_ex2, numberOfShares_ex2, numberOfPuts_ex2, stockPrice_ex2, K_ex2, rate, div_ex2, vol_ex2, TTM_ex2, riskDays_ex2, returnsSelected_ex2, flag);

% Print results
fprintf('Generali spot price: %.4f\n', stockPrice_ex2);
fprintf('Number of shares: %.2f\n', numberOfShares_ex2);
fprintf('Number of puts: %.2f\n', numberOfPuts_ex2);
fprintf('Full Monte Carlo VaR: %.2f\n', VaR_MC_ex2);
fprintf('Delta Normal VaR: %.2f \n', VaR_DN_ex2);



