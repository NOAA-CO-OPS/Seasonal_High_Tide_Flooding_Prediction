function Output = getThresholddata(StationID,DatumBias)
% Output = getThresholddata(StationID,DatumBias);
%
% This function downloads the NOS minor flood threshold on station datum (STND)
% and specified datum bias for a given station from the CO-OPS API. It then
% calculates the flood threshold for the specified datum. 
% Required Inputs:
% StationID > The station ID of the water level station of interest. 
%             String. eg - '8452660'
% DatumBias > The datum to which to bias the data to.  eg - 'mllw', 'mhw',
%             etc. Options are 
%             'MHHW' - mean higher high water
%             'MHW' - mean high water
%             'MTL' - mean tide level
%             'MSL' - mean sea level
%             'MLW' - mean low water
%             'MLLW' - mean lower low water
%             'NAVD' - North American Veritcal Datum of 1988
%             'STND' - station datum

% build url request for flood levels in meters
mdapi_url = "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/" + ...
            "stations/";
floodlevel_url = strcat(mdapi_url,StationID,...
                        "/floodlevels.json?units=metric");
floodlevel = webread(floodlevel_url);
% get NOS Minor flood threshold in meters relative to STND
if ~isempty(floodlevel.nos_minor)
    minor_floodlevel = floodlevel.nos_minor;      
else
    minor_floodlevel = 0;
    floodlevel_datumbias = 1.95;
    Output = round(floodlevel_datumbias,3); 
end  

% build url request for datums in meters
stn_datums_url = strcat(mdapi_url,StationID,...
                   "/datums.json?units=metric");
stn_datums = webread(stn_datums_url);
% get user selected datum in feet
for i = 1:length(stn_datums.datums)
    if stn_datums.datums(i).name == string(DatumBias)
        stn_datum_bias = stn_datums.datums(i).value;

        % Output = absolute value of minor_floodlevel - MHHW
        % handle null NOS minor flood level
        if minor_floodlevel ~= 0
            floodlevel_datumbias = abs(minor_floodlevel-stn_datum_bias);
        % round to 3 decimals
        Output = round(floodlevel_datumbias,3);
        end
    end   
end