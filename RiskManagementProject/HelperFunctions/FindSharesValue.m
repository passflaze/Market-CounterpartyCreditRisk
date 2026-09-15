function [prices] = FindSharesValue(inputFile, refDate, sharesList, formatDate)
% Extracts the spot prices for a list of assets at a specific date.
%
% This function iterates through a list of shares, retrieves their full 
% historical series from the provided table, and identifies the price 
% closest to the requested reference date using a nearest-neighbor approach.
%
% INPUTS:
%  - shareData:  MATLAB Table containing the market data (prices and dates).
%  - refDate:    Target date for valuation (string 'dd/mm/yyyy' or datenum).
%  - sharesList: Matrix or cell array of strings containing asset names.
%  - formatDate: Format string for date conversion (default: 'dd/mm/yyyy').
%
% OUTPUTS:
%  - prices:     A [1 x N] vector of prices corresponding to the sharesList.

%% 1. Input Check and Initialization
if nargin < 4
    formatDate = 'dd/mm/yyyy';
end

opts = detectImportOptions(inputFile, 'Sheet', 'Data');
opts.VariableNamingRule = 'preserve'; % Mantiene i nomi dei ticker intatti
shareData = readtable(inputFile, opts);
% Ensure refDate is in numeric (datenum) format for mathematical comparison
if ischar(refDate) || isstring(refDate) || isdatetime(refDate)
    refDate = datenum(refDate);
end

numShares = size(sharesList, 1);
prices = zeros(numShares, 1); % Pre-allocate for efficiency

%% 2. Extraction Loop
for i = 1:numShares
    % Step A: Convert the descriptive name to the Bloomberg Ticker code
    bbgCode = underlyingCode(sharesList(i,:));
    
    % Step B: Call your original findSeries to get the FULL historical series.
    % findSeries handles column lookup and NaN removal.
    [v_all, t_all, ~] = findSeries(shareData, bbgCode, formatDate);
    
    % Step C: Synchronize the asset's timeline with the refDate.
    % closestDate finds the index 'idx' where |t_all(idx) - refDate| is minimized.
    [~, idx] = closestDate(refDate, t_all);
    
    % Step D: Store the price found at that specific historical point.
    if ~isempty(idx)
        prices(i) = v_all(idx);
    else
        prices(i) = NaN; % Assign NaN if the data is missing or out of range
    end
end

end % End of function