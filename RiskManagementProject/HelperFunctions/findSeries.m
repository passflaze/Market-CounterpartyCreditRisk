function [values, date, CompleteName] = findSeries(equityTable, assetName, formatDate)
% findSeries per oggetti TABLE
%
% INPUT:
%  - equityTable: la tabella generata da readtable
%  - assetName: stringa (o parte di essa) del titolo da cercare
%  - formatDate: non più strettamente necessario se la tabella ha già datetime, 
%                ma mantenuto per compatibilità.
%
% OUTPUT:
%  - values: prezzi (vettore double)
%  - date: date in formato numerico (datenum)
%% Inizializzazione
CompleteName = '';
allVariableNames = equityTable.Properties.VariableNames;
%% Ricerca della colonna
% Cerchiamo quale colonna contiene il nome richiesto
% 'contains' è più robusto di 'findstr'
idxCol = find(contains(allVariableNames, assetName, 'IgnoreCase', true), 1);
if isempty(idxCol)
    error(['Titolo "' assetName '" non trovato; provare a scrivere solo parte del nome']);
end
% Salviamo il nome completo trovato
CompleteName = allVariableNames{idxCol};
%% Estrazione Dati
% Assumiamo la struttura Bloomberg standard: [Data_Asset1, Prezzo_Asset1, Data_Asset2, Prezzo_Asset2, ...]
% Quindi se il prezzo è nella colonna idxCol, la sua data è nella colonna idxCol-1
% 1. Estrazione Prezzi (rimuovendo i NaN)
rawValues = equityTable{:, idxCol+1};
mask = ~isnan(rawValues);
values = rawValues(mask);
% 2. Estrazione Date
% Prendiamo la colonna precedente a quella del prezzo
rawDates = equityTable{:, idxCol};
% Se le date sono oggetti datetime (standard con readtable), convertiamo in datenum
if isdatetime(rawDates)
    date = datenum(rawDates(mask));
else
    % Se per qualche motivo sono rimaste stringhe o numeri seriali
    date = rawDates(mask);
    if iscell(date)
        date = datenum(date, formatDate);
    end
end
end % findSeries

