function [datums, thresholds] = getMDAPI(stationID)
% function to get the metric datums & thresholds for a
% particular station, from CO-OPS MDAPI.
% JH Nov 27 2023
%% base url
base_url = ['https://api.tidesandcurrents.noaa.gov/' ...
    'mdapi/prod/webapi/stations/'];
%% url request for datums and thresholds
datumsInput = '/datums.json?units=metric'; 
thresholdsInput = '/floodlevels.json?units=metric';
%% build URLs
datumsUrl = [base_url, stationID, datumsInput];
thresholdsUrl = [base_url, stationID, thresholdsInput];
%% Weboptions
options = weboptions('ContentType', 'json');
%% call mdapi w/ exception handling
 try
     datums = webread(datumsUrl, options);
     thresholds = webread(thresholdsUrl, options);
 catch exception
     disp('Error in API request:');
     disp(exception.message);
     datums = [];
     thresholds = [];
 end
end

