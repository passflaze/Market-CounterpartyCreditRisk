function [tSelected, returnsSelected] = returnsOfInterest(inputFile, refDate, timeWindow, sharesList, formatDate)
% Selects a specific time window of historical log-returns.
%
% It aligns all assets to the benchmark calendar (SX5E), using the previous
% available price when a stock price is missing on a benchmark date.

    if nargin < 5
        formatDate = 'dd/MM/yyyy';
    end

    numAssets = size(sharesList,1);

    % Load data
    opts = detectImportOptions(inputFile, 'Sheet', 'Data');
    opts.VariableNamingRule = 'preserve';
    shareData = readtable(inputFile, opts);

    % Benchmark calendar: SX5E
    [~, t_index] = findSeries(shareData, 'SX5E Index', formatDate);

    refDateNum = datenum(refDate);
    startDateNum = dateAddMonth(refDateNum, -timeWindow);

    % Select benchmark window
    [~, idxRef]   = closestDate(refDateNum,   t_index, 'p');
    [~, idxStart] = closestDate(startDateNum, t_index, 'p');

    idx1 = min(idxRef, idxStart);
    idx2 = max(idxRef, idxStart);

    tSelected = t_index(idx1:idx2);
    numObs = length(tSelected);

    % Matrix of aligned prices
    valuesSelectedShares = zeros(numObs, numAssets);

    for i = 1:numAssets
        bbgCode = underlyingCode(sharesList{i});
        [values_all, t_all] = findSeries(shareData, bbgCode, formatDate);

        alignedPrices = zeros(numObs,1);

        for j = 1:numObs
            % For each benchmark date, take same day if available,
            % otherwise previous available date
            [~, idxAsset] = closestDate(tSelected(j), t_all, 'p');
            alignedPrices(j) = values_all(idxAsset);
        end

        valuesSelectedShares(:,i) = alignedPrices;
    end

    % Compute log-returns
    returnsSelected = log(valuesSelectedShares(2:end,:) ./ valuesSelectedShares(1:end-1,:));
    tSelected = tSelected(2:end);
end