% Exercise 3 - Group2

% ADD TO PATH: HelperCliquet

clc
close all
clear all

%% Define parameters for the cliquet option pricing
sigma = 0.19;  % Volatility
Notional = 45000000;  % Notional amount
R=0.40; %Recovery rate

%% Bootstrap 
formatData='dd/mm/yyyy'; 
[datesSet, ratesSet] = readExcelData('MktData_CurveBootstrap.xls', formatData);
[dates, discounts, zeroRates] = bootstrap(datesSet, ratesSet); 

% Valuation date
t0 = datenum('19-Feb-2008');

% Yearly payment dates (t1, t2, t3, t4, t5)
payment_dates_raw = datetime({'19-Feb-2009', '19-Feb-2010', ...
                              '19-Feb-2011', '19-Feb-2012', ...
                              '19-Feb-2013'});

% ConvertDates → adjusts dates to business days and returns datenum
payment_dates = ConvertDates(payment_dates_raw); 

% Exctract zero ratesfor and discount factors for payment dates
discount_factors = fromdatetodiscount(t0, dates, zeroRates, payment_dates);
TTM = yearfrac(t0, payment_dates, 3); 
zero_rates_cliquet = -log(discount_factors) ./ TTM;

B = [1; discount_factors];

%% CDS bootstrap 
t0_CDS = datetime(2008,02,19);
% Define the CDS maturity dates vector for the ISP case study
datesCDS = t0_CDS:calyears(1): (t0_CDS + calyears(7));
% Input Data (ISP CDS Spreads as of 15-02-2008)
tenors = [1; 2; 3; 4; 5; 7]; 
spreads_bps = [29; 34; 37; 39; 40; 40];
targetTenor = 6;
plotFlag=1; % to plot
[spread_6y, pp_model] = CompleteSet(tenors, spreads_bps, targetTenor, plotFlag);
% putting together spreads
spreadsCDS = [spreads_bps(1:5); spread_6y; spreads_bps(end)];
tenors_final = [tenors(1:5); 6; tenors(end)];
recovery = 0.4;
flag=1;
[datesCDS, survProbs, intensities] = bootstrapCDS(dates, zeroRates, datesCDS, spreadsCDS, flag, recovery);

% Hazard rates of interest
lambdas=intensities(1:5);

%% Price Cliquet

[PriceRiskFree, CVA, RiskyPrice] = priceCliquet(Notional, sigma, t0, payment_dates, B,lambdas, R);
fprintf('Risk Free Price: %.2f Mln\n', PriceRiskFree/1e6);
fprintf('CVA: %.2f Mln\n', CVA/1e6);
fprintf('Risky Price %.2f Mln\n', RiskyPrice/1e6);



