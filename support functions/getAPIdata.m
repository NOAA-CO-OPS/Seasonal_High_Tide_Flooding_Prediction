function Output = getAPIdata(StationID,BeginDate,EndDate,...
    Product,varargin)
% Output = getAPIdata(StationID,BeginDate,EndDate,Product,varargin);
%
% This function will download data from the CO-OPS API and output a data
% structure with fields that correspond to the data retrieved.
% Required Inputs:
% StationID > The station ID of the water level, met, or current station
%             of interst.  String. eg - '8452660'
% BeginDate > The beginning date of the data request.  Only month day and
%             year input.  The hours and minutes will be assumed to be
%             00:00 on the day.  The format should be yyyymmdd.  eg -
%             '20150101' will be interpreted as Jan. 1st, 2015 00:00.
%             String.
% EndDate >   The end date of the data being requested.  Same limitations
%            as BeginDate except the end time will be assumed to be 23:59.
%             eg - '20150101' will be interpreted as Jan 1, 2015 23:59.
% Product >   The water level, met, or oceanographic product of interst.
%             The choices are:
%             'water_level' - Prelim or verified water levels
%             'air_temperature' - Air temp as measured
%             'water_temperature' - Water temp as measured
%             'wind' - Wind Speed, direction, and gusts as measured
%             'air_pressure' - Barometric pressure as measured
%             'air_gap' - Air Gap at the station
%             'conductivity' - water conductivity
%             'visibility' - Visibility
%             'humidity' - relative humidity
%             'hourly_height' - Verified hourly height data
%             'high_low' - verified high/low water level data
%             'daily_mean' - verified daily mean water level data
%             'monthly_mean' - Verified monthly mean water level data
%             'one_minute_water_level' - One minute water level data
%             'predictions' - 6 minute predicted water level data
%             'datums' - accepted datums for the station
%             'currents' - Current data for thee current station
% Optional inputs: 
% These inputs should be input into the function as the optional input in
% quotes, a comma, and the value of the option in quotes.  Example:
% 'DatumBias', 'MLLW' or 'Bin', '4'
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
%             Default is STND
% Units     > Metric or english units. Options are
%             'metric' - celcius, meters
%             'english' - fahrenheit, feet
%             Default is 'metric'.
% TimeZone  > The time zone of the data.  Greeenwich, local, or local
%             daylight time.
%             'gmt' - Greenwich Mean Time
%             'lst' - local standard time
%             'last_ldt' - Local Standard or Local daylight, depending on
%             time of year
%             Default is 'gmt'
% Interval  > The interval for met and tide predictions
%             'h' - hourly data
%             Default is not used as there is no need since the API
%             defaults to 6 minute data.
% Bin       > current data for bin number.  Number as a string eg - '3'.
%             Default is '1'.
% 
% examples:
% x = getAPIdata('8452660','20150101','20150331','water_level',...
%       'DatumBias','MLLW')
% returns a structure, x, with the following fields:
%   x.DateTime - numeric time stamps of the data in matlab datenum format
%   x.WaterLevel - 6 minute water level value bias to MLLW
%   x.Sigma - standard deviation of the water level value
%   x.O - I have no idea what this is but the API returns it
%   x.F - see x.O for complete explanation of this field
%   x.R - seriosly, i got nothing but it's in there
%   x.L - some kind of measure of quality?
%   x.Quality - character stamps regarding the quality of the data 'v' =
%   verified
% Even thought the API limits you to 31 days of 6 minute data this function
% will send multiple requests in order to get more data and then complile
% them all into a single output structure.  
% LL 5/2/2016
% email and questions or comments to:
% louis.licate@noaa.gov
% or go to SSMC4 7146

% supress warnings
warning off;

% Put dates into matlab datenum format
BeginDateNum = datenum(BeginDate,'yyyymmdd');
EndDateNum = datenum(EndDate,'yyyymmdd');
BV = datevec(BeginDateNum);
EV = datevec(EndDateNum);

% get variable inputs
% defaults
DatumBias = 'STND';
Units = 'metric';
TimeZone = 'gmt';
Bin = '1';
Interval = [];
% 
if nargin>4 % optional inputs
    for i = 1:2:length(varargin)
        switch varargin{i}
            case 'DatumBias'
                DatumBias = varargin{i+1};
            case 'Units'
                Units = varargin{i+1};
            case 'TimeZone'
                TimeZone = varargin{i+1};
            case 'Interval'
                Interval = varargin{i+1};
            case 'Bin'
                Bin = varargin{i+1};
            otherwise
                disp(['Input arguments do not conform to required '...
                    'format.  Please reenter inputs.']);
                return;
        end % switch
    end
end

% Determine the begin and end dates for the request.  A string of dates
% will be created and looped over the total number of dates so as to get
% more than 31 days of data.
switch lower(Product)
    case 'one_minute_water_level'
        % the limit is 5 days
        if EndDateNum - BeginDateNum > 5
            % increment dates by 5 days so the loop will get all data
            DatesB = BeginDateNum;
            DatesE = BeginDateNum+4;
            while DatesE(end)~=EndDateNum
                DatesB = cat(2,DatesB,DatesE(end)+1);
                DatesE = DatesB+4;
                if DatesE(end)>EndDateNum;
                    DatesE(end)=EndDateNum;
                end
            end
        else
            DatesB = BeginDateNum;
            DatesE = EndDateNum;
        end
    case {'water_level','air_temperature','water_temperature','wind',...
            'air_pressure','air_gap','conductivity','visibility',...
            'humidity','salinity','currents','predictions'}
        % ***Edited by G.Dusek on 3/27/23 - These are 6 minute data by default, however predictions (and
        % possibly other data) and can be hourly with interval.  So editing
        % to look for that specific case. (Using the hourly case below -
        % this should all be edited to more seemlessly account for interval
        % in the future)
        if Interval == 'h'
            if EndDateNum - BeginDateNum > 365
                DatesB = BeginDateNum;
                DatesE = NaN;
                while DatesE(end)~=EndDateNum
                    V = DatesB(end);
                    DatesE = cat(2,DatesE,V+364);
                    
                    if DatesE(end)>=EndDateNum
                        DatesE(end)=EndDateNum;
                        DatesE(isnan(DatesE)) = [];
                    else
                        DatesB = cat(2,DatesB,DatesE(end)+1);
                    end
                end
            else
                DatesB = BeginDateNum;
                DatesE = EndDateNum;
            end

        else
            if EndDateNum - BeginDateNum > 30
                % increment dates by 30 days so the loop will get all data
                DatesB = BeginDateNum;
                DatesE = NaN;
                while DatesE(end)~=EndDateNum
                    
                    V = datevec(DatesB(end));
                    m = V(:,2);
                    if m==1 || m==3 || m==5 || m==7 || m==8 || m==10 || m==12
                        V2 = [V(:,1) m 31 0 0 0];
                    elseif m==2
                        if V(:,1)~=1900 && rem(V(:,1),4)==0
                            V2 = [V(:,1) m 29 0 0 0];
                        else
                            V2 = [V(:,1) m 28 0 0 0];
                        end
                    elseif m==4 || m==6 || m==9 || m==11
                        V2 = [V(:,1) m 30 0 0 0];
                    end
                    
                    DatesE = cat(2,DatesE,datenum(V2));
                    
                    if DatesE(end)>=EndDateNum;
                        DatesE(end)=EndDateNum;
                        DatesE(isnan(DatesE)) = [];
                    else
                        DatesB = cat(2,DatesB,DatesE(end)+1);
                    end
                end
                
            else
                DatesB = BeginDateNum;
                DatesE = EndDateNum;
            end
        end
    case{'hourly_height','high_low'}
        % same as for previous but increment over a year if needed
        if EndDateNum - BeginDateNum > 365
            DatesB = BeginDateNum;
            DatesE = NaN;
            while DatesE(end)~=EndDateNum
                V = DatesB(end);
                DatesE = cat(2,DatesE,V+364);
                
                if DatesE(end)>=EndDateNum
                    DatesE(end)=EndDateNum;
                    DatesE(isnan(DatesE)) = [];
                else
                    DatesB = cat(2,DatesB,DatesE(end)+1);
                end
            end
        else
            DatesB = BeginDateNum;
            DatesE = EndDateNum;
        end
    case {'daily_mean','monthly_mean','datums'}
        % 10 year max from API
        if EndDateNum - BeginDateNum > 364*10
            DatesB = BeginDateNum;
            DatesE = NaN;
            while DatesE(end)~=EndDateNum
                V = datevec(DatesB(end));
                DatesE = cat(2,DatesE,datenum([V(:,1)+8 12 31 0 0 0]));
                
                if DatesE(end)>=EndDateNum;
                    DatesE(end)=EndDateNum;
                    DatesE(isnan(DatesE)) = [];
                else
                    DatesB = cat(2,DatesB,DatesE(end)+1);
                end
            end
        else
            DatesB = BeginDateNum;
            DatesE = EndDateNum;
        end
end % switch


% loop over the dates
all_data = [];
disp(['Submitting ' num2str(length(DatesE)) ' requests.']);
perc=0;
disp(['percent complete = ', num2str(perc), '%'])
for i=1:length(DatesB)
    %G.Dusek 4/29/20 - Added a % update to track each request to show that progress is being
    %made
    indPerc=ceil([.10:.10:1]*length(DatesB));
    perc = i/length(DatesB) * 100;
    if ismember(i,indPerc)
        disp([num2str(perc),'%'])
    end
    
    % build url request - Updated 12/02/2016 by C.Fanelli from http:// to
    % https://
    url_request = ['https://tidesandcurrents.noaa.gov/api/datagetter?'...
        'begin_date=' datestr(DatesB(i),'yyyymmdd') ' 00:00' ...
        '&end_date='  datestr(DatesE(i),'yyyymmdd') ' 23:59'...
        '&station='   StationID ...
        '&product='   lower(Product) ...
        '&datum='     DatumBias ...
        '&units='     Units ...
        '&time_zone=' TimeZone ...
        '&application=web_services&format=csv'];
    if strcmp(Product,'currents')
        url_request = [url_request '&bin=' Bin];
    end
    if ~isempty(Interval)
        url_request = [url_request '&interval=' Interval];
    end
    x = urlread(url_request);
    
    uu(i).r = url_request;
    uu(i).x = x;
    uu(i).startTime = datestr(DatesB(i),'yyyymmdd');
    uu(i).endTime = datestr(DatesE(i),'yyyymmdd');
    
    % check to see if there is an error
    q = textscan(x,'%s','HeaderLines',1);

    if strfind(q{1}{1},'Error:')
        % error in file, skipping
        disp(['There was an error during request ' num2str(i)]);
        
        q{1}{1}
    else
        % remove first line
        first_end = strfind(x,char(10));
        x(1:first_end(1)) = [];
        all_data = cat(2,all_data,x);
    end
end

% now that the request is available parse the data
disp('Parsing Data...');
data_flag = 0;
switch lower(Product)
    case 'water_level'
         % open file from urlwrite
        format = '%s%f%f%f%f%f%f%s%[^\n\r]';
	if ~isempty(all_data)
        	data = textscan(all_data, format,'Delimiter',',',...
            	       'EmptyValue',NaN,'HeaderLines',0,'ReturnOnError',false);
	else
	    data_flag = 1;
	end
        fnames = {'DateTime','WaterLevel','Sigma',...
            'O','F','R','L','Quality'};
        for j = 1:length(fnames)
            Output.(fnames{j}) = [];
        end

        if ~data_flag
            for j = 1:length(fnames)
                switch fnames{j}
                    case 'DateTime'
                        t = datenum(data{:,j},'yyyy-mm-dd HH:MM');
                        Output.(fnames{j}) = cat(1,Output.(fnames{j}),t);
                    case {'WaterLevel','Sigma','O','F','R','L'}
                        Output.(fnames{j}) = cat(1,Output.(fnames{j}),...
                            data{:,j});
                    case 'Quality'
                        Output.(fnames{j}) = cat(1,Output.(fnames{j}),...
                            data{:,j});
                end %switch
            end % j
        end

    case 'hourly_height'
        format = '%s%f%f%f%f%[^\n\r]';
        if ~isempty(all_data)
        	data = textscan(all_data, format,'Delimiter',',',...
            	       'EmptyValue',NaN,'HeaderLines',0,'ReturnOnError',false);
        else
            data_flag = 1;
        end
        fnames = {'DateTime','WaterLevel','Sigma'...
            'I','L'};
        for j = 1:length(fnames);
            Output.(fnames{j}) = [];
        end
        if ~data_flag
        for j = 1:length(fnames)
            switch fnames{j}
                case 'DateTime'
                    %data{:,j}(1:50)
                    t = datenum(data{:,j},'yyyy-mm-dd HH:MM');
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),t);
                case {'WaterLevel','Sigma','I','L'}
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),...
                        data{:,j});
            end %switch
        end % j 
        end

    case 'air_temperature'
        format = '%s%f%f%f%f%[^\n\r]';
        if ~isempty(all_data)
        	data = textscan(all_data, format,'Delimiter',',',...
            	       'EmptyValue',NaN,'HeaderLines',0,'ReturnOnError',false);
	else
	    data_flag = 1;
	end
        fnames = {'DateTime','AirTemperature','X','N','R'};
        for j = 1:length(fnames);
            Output.(fnames{j}) = [];
        end
        if ~data_flag
        for j = 1:length(fnames)
            switch fnames{j}
                case 'DateTime'
                    t = datenum(data{:,j},'yyyy-mm-dd HH:MM');
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),t);
                case {'AirTemperature','X','N','R'}
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),...
                        data{:,j});
            end %switch
        end % j 
        end
    case 'wind'
        format = '%s%f%f%s%f%f%f%[^\n\r]';
        if ~isempty(all_data)
        	data = textscan(all_data, format,'Delimiter',',',...
            	       'EmptyValue',NaN,'HeaderLines',0,'ReturnOnError',false);
	else
	    data_flag = 1;
	end
        fnames = {'DateTime','Speed','Direction1','Direction2',...
            'Gust','X','R'};
        for j = 1:length(fnames);
            Output.(fnames{j}) = [];
        end
        if ~data_flag
        for j = 1:length(fnames)
            switch fnames{j}
                case 'DateTime'
                    t = datenum(data{:,j},'yyyy-mm-dd HH:MM');
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),t);
                case {'Speed','Direction1','Direction2','Gust','X','R'}
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),...
                        data{:,j});
            end %switch
        end % j 
        end

    case 'air_pressure'
        format = '%s%f%f%f%f%[^\n\r]';
        if ~isempty(all_data)
        	data = textscan(all_data, format,'Delimiter',',',...
            	       'EmptyValue',NaN,'HeaderLines',0,'ReturnOnError',false);
	else
	    data_flag=1;
	end
        fnames = {'DateTime','AirPressure','X','N','R'};
        for j = 1:length(fnames);
            Output.(fnames{j}) = [];
        end
        if ~data_flag
        for j = 1:length(fnames)
            switch fnames{j}
                case 'DateTime'
                    t = datenum(data{:,j},'yyyy-mm-dd HH:MM');
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),t);
                case {'AirPressure','X','N','R'}
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),...
                        data{:,j});
            end %switch
        end % j 
        end

    case 'air_gap'
        format = '%s%f%f%f%f%f%f%s%[^\n\r]';
        if ~isempty(all_data)
        	data = textscan(all_data, format,'Delimiter',',',...
            	       'EmptyValue',NaN,'HeaderLines',0,'ReturnOnError',false);
	else
	    data_flag = 1;
	end
        fnames = {'DateTime','AirGap','Sigma','O','F','R','L','Quality'};
        for j = 1:length(fnames);
            Output.(fnames{j}) = [];
        end
        if ~data_flag
        for j = 1:length(fnames)
            switch fnames{j}
                case 'DateTime'
                    t = datenum(data{:,j},'yyyy-mm-dd HH:MM');
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),t);
                case {'AirGap','Sigma','O','F','R','L'}
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),...
                        data{:,j});
                case 'Quality'
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),...
                        data{:,j});
            end %switch
        end % j 
        end

    case 'conductivity'
        format = '%s%f%f%f%f%[^\n\r]';
        if ~isempty(all_data)
        	data = textscan(all_data, format,'Delimiter',',',...
            	       'EmptyValue',NaN,'HeaderLines',0,'ReturnOnError',false);
	else
	    data_flag=1;
	end
        fnames = {'DateTime','Conductivity','X','N','R'};
        for j = 1:length(fnames);
            Output.(fnames{j}) = [];
        end
        if ~data_flag
        for j = 1:length(fnames)
            switch fnames{j}
                case 'DateTime'
                    t = datenum(data{:,j},'yyyy-mm-dd HH:MM');
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),t);
                case {'Conductivity','X','N','R'}
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),...
                        data{:,j});
            end %switch
        end % j 
        end

    case 'visibility'
        format = '%s%f%[^\n\r]';
        if ~isempty(all_data)
        	data = textscan(all_data, format,'Delimiter',',',...
            	       'EmptyValue',NaN,'HeaderLines',0,'ReturnOnError',false);
	else
	    data_flag = 1;
	end
        fnames = {'DateTime','Visibility'};
        for j = 1:length(fnames);
            Output.(fnames{j}) = [];
        end
        if ~data_flag
        for j = 1:length(fnames)
            switch fnames{j}
                case 'DateTime'
                    t = datenum(data{:,j},'yyyy-mm-dd HH:MM');
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),t);
                case {'Visibility'}
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),...
                        data{:,j});
            end %switch
        end % j 
        end

    case 'humidity'
        format = '%s%f%f%f%f%[^\n\r]';
        if ~isempty(all_data)
        	data = textscan(all_data, format,'Delimiter',',',...
            	       'EmptyValue',NaN,'HeaderLines',0,'ReturnOnError',false);
	else
	    data_flag = 1;
	end
        fnames = {'DateTime','Humidity','X','N','R'};
        for j = 1:length(fnames);
            Output.(fnames{j}) = [];
        end
        if ~data_flag
        for j = 1:length(fnames)
            switch fnames{j}
                case 'DateTime'
                    t = datenum(data{:,j},'yyyy-mm-dd HH:MM');
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),t);
                case {'Humidity','X','N','R'}
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),...
                        data{:,j});
            end %switch
        end % j 
        end

    case 'high_low'
        format = '%s%f%s%f%f%[^\n\r]';
        if ~isempty(all_data)
        	data = textscan(all_data, format,'Delimiter',',',...
            	       'EmptyValue',NaN,'HeaderLines',0,'ReturnOnError',false);
	else
	    data_flag = 1;
	end
        fnames = {'DateTime','WaterLevel','Type','I','L'};
        for j = 1:length(fnames);
            Output.(fnames{j}) = [];
        end
        if ~data_flag
        for j = 1:length(fnames)
            switch fnames{j}
                case 'DateTime'
                    t = datenum(data{:,j},'yyyy-mm-dd HH:MM');
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),t);
                case {'WaterLevel','I','L'}
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),...
                        data{:,j});
                case 'Type'
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),...
                        data{:,j});
            end %switch
        end % j 
        end

    case 'daily_mean'
        format = '%s%f%f%f%[^\n\r]';
        if ~isempty(all_data)
        	data = textscan(all_data, format,'Delimiter',',',...
            	       'EmptyValue',NaN,'HeaderLines',0,'ReturnOnError',false);
	else
	    data_flag = 1;
	end
        fnames = {'DateTime','WaterLevel','I','L'};
        for j = 1:length(fnames)
            Output.(fnames{j}) = [];
        end
        if ~data_flag
        for j = 1:length(fnames)
         
            switch fnames{j}
              
                case 'DateTime'
                    t = datenum(data{:,j},'yyyy-mm-dd HH:MM');
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),t);
                case {'WaterLevel','I','L'}
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),...
                        data{:,j});
            end %switch
        end % j 
        end

    case 'monthly_mean'
        format = '%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%[^\n\r]';
        if ~isempty(all_data)
        	data = textscan(all_data, format,'Delimiter',',',...
            	       'EmptyValue',NaN,'HeaderLines',0,'ReturnOnError',false);
	else
	    data_flag = 1;
	end
        fnames = {'Year','Month','Highest','MHHW','MHW','MSL','MTL',...
            'MLW','MLLW','DTL','GT','MN','DHQ','DLQ','HWI','LWI',...
            'Lowest','Inferred'};
        for j = 1:length(fnames);
            Output.(fnames{j}) = [];
        end
        if ~data_flag
        for j = 1:length(fnames)
            Output.(fnames{j}) = cat(1,Output.(fnames{j}),...
                        data{:,j});
                    % no special cases for this one
        end % j 
        end

    case 'one_minute_water_level'
        format = '%s%f%[^\n\r]';
        if ~isempty(all_data)
        	data = textscan(all_data, format,'Delimiter',',',...
            	       'EmptyValue',NaN,'HeaderLines',0,'ReturnOnError',false);
	else
	    data_flag = 1;
	end
        fnames = {'DateTime','WaterLevel'};
        for j = 1:length(fnames);
            Output.(fnames{j}) = [];
        end
        if ~data_flag
        for j = 1:length(fnames)
            switch fnames{j}
                case 'DateTime'
                    t = datenum(data{:,j},'yyyy-mm-dd HH:MM');
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),t);
                case 'WaterLevel'
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),...
                        data{:,j});
            end %switch
        end % j 
        end
    case 'predictions'
        format = '%s%f%[^\n\r]';
        if ~isempty(all_data)
        	data = textscan(all_data, format,'Delimiter',',',...
            	       'EmptyValue',NaN,'HeaderLines',0,'ReturnOnError',false);
	else
	    data_flag=1;
	end
        fnames = {'DateTime','Prediction'};
        for j = 1:length(fnames);
            Output.(fnames{j}) = [];
        end
        if ~data_flag
        for j = 1:length(fnames)
            switch fnames{j}
                case 'DateTime'
                    t = datenum(data{:,j},'yyyy-mm-dd HH:MM');
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),t);
                case 'Prediction'
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),...
                        data{:,j});
            end %switch
        end % j 
        end

    case 'datums'
        format = '%s%f%[^\n\r]';
        if ~isempty(all_data)
        	data = textscan(all_data, format,'Delimiter',',',...
            	       'EmptyValue',NaN,'HeaderLines',0,'ReturnOnError',false);
	else
	    data_flag = [];
	end
        [nr,~] = size(data{1});
        for j = 1:nr
            Output.(data{1}{j}) = data{2}(j);
        end

    case 'currents'
        uu(1).x
        format = '%s%f%f%f%[^\n\r]';
        if ~isempty(all_data)
        	data = textscan(all_data, format,'Delimiter',',',...
            	       'EmptyValue',NaN,'HeaderLines',0,'ReturnOnError',false);
	else
	    data_flag = 1;
	end
        fnames = {'DateTime','Speed','Direction','Bin'};
        for j = 1:length(fnames);
            Output.(fnames{j}) = [];
        end
        if ~data_flag
        for j = 1:length(fnames)
            switch fnames{j}
                case 'DateTime'
                    t = datenum(data{:,j},'yyyy-mm-dd HH:MM');
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),t);
                case {'Speed','Direction','Bin'}
                    Output.(fnames{j}) = cat(1,Output.(fnames{j}),...
                        data{:,j});
            end %switch
        end % j
        end
end % switch
disp('Finished...');
      
% turn warnings back on
warning on;