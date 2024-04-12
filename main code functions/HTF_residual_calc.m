function [resOut] = HTF_residual_calc(stationNum,slt,epochCenter)
%This function takes data from a WL station with SLTs,
%thresholds and ideally 20 years of hourly data to calculate daily residuals for
%use in HT flooding predictions

% stationNum - string of stationNum (eg. '1820000')
% slt - The sea level trend to apply to the tide predictions in mm/yr
% epochCenter - The date for the center of the station's tidal epoch in partial years, usually 1992.5
% startYear - The start year - eg 1997
% endYear - The end year - eg 2018

%Dependencies
%Matlab function interpnan.m

tic
%%
%Load the data from the mat file
load([stationNum,'_data']);

wl=data.wl;
pred=data.pred;
dTime=data.dateTime;

% Convert the epoch center to a datetime
epochYear=floor(epochCenter);
partialYear=epochCenter-epochYear;
epochCenter=datetime(epochYear,1,1)+years(partialYear);

%%
%Add linear SLT to the predictions using the epoch center as 0 (should be
%1992.5 for most cases here)

slt=slt/1000; %change to meters
startTrend= slt*years((dTime(1)-epochCenter)); %How much of the trend goes from the center epoch to the start date
sltTotal=slt*years(dTime(end)-dTime(1)); % total change over the length of the predictions 
resOut.sltAdd=startTrend+(sltTotal./length(pred)).*(0:1:length(pred)-1); % the time by time SLT addition
resOut.predAdj=pred+resOut.sltAdd';
resOut.dateTime=dTime;

%%
%calculate the residual between the SLT adjusted predictions and
%observations
resOut.res=wl-resOut.predAdj;


%% Function to calculate the mu and sigma climatological values by month and by decile
[resOut.mu_monthAvg,resOut.sigma_monthAvg,resOut.decileMu,resOut.decileSigma,resOut.deciles] = dist_calc(dTime,resOut.res,resOut.predAdj);

%% 

%set up and output the year-month dates
%First need to create the yr-mo datetime vector for each month with data
yearsIn = year(dTime);
monthsIn = month(dTime);
yearMonth = [yearsIn(:), monthsIn(:)];  % Ensure it's a two-column matrix
[uniqueYearMonth, ia] = unique(yearMonth, 'rows', 'stable');
resOut.yrMoTime = datetime(uniqueYearMonth(:,1), uniqueYearMonth(:,2), 1);

%Now go through and calculate the monthly means and corresponding monthly
%anomalies for each month of data

% Initialize arrays to hold the monthly mu,sigma and anomaly water levels
resOut.mu_month = zeros(1,length(resOut.yrMoTime));
resOut.sigma_month = zeros(1,length(resOut.yrMoTime));
resOut.mu_monthAmly = zeros(1,length(resOut.yrMoTime));
resOut.sigma_monthAmly = zeros(1,length(resOut.yrMoTime));

for i = 1:length(resOut.yrMoTime)
    if i < length(resOut.yrMoTime)
        % Get the indices for the current month
        monthIndices = ia(i):(ia(i+1)-1);
    else
        % For the last month, go till the end of the array
        monthIndices = ia(i):length(dTime);
    end
    
    % Calculate the average, sigma water level and anomaly for the current month
    resOut.mu_month(i) = nanmean(resOut.res(monthIndices));
    resOut.sigma_month(i) = nanstd(resOut.res(monthIndices));
    monthInd=month(resOut.yrMoTime(i));
    resOut.mu_monthAmly(i)=resOut.mu_month(i)-resOut.mu_monthAvg(monthInd);
    resOut.sigma_monthAmly(i)=resOut.sigma_month(i)-resOut.sigma_monthAvg(monthInd);
end
  

%% Cross correlation calculation

% Now perform a cross-correlation with the monthly anomaly to help determine 
% the persistence length scale and damped persistence coefficient

%Need to first interp for NaNs in the mu_monthlyAmly and sigma data
resOut.mu_monthAmlyInt=interpnan(resOut.mu_monthAmly,datenum(resOut.yrMoTime));
resOut.sigma_monthAmlyInt=interpnan(resOut.sigma_monthAmly,datenum(resOut.yrMoTime));

%now do the cross correlation for mu out 12 months (sigma is not
%correlated)
numLags=12;
[r,~]=xcorr(resOut.mu_monthAmlyInt,numLags,'coef');
muCorrMonths=r(numLags+2:end);



%%
% Create the damped persistence coefficient vector.  This is done by
% finding the first autocorrelation value < the 95% confidence threshold
% and setting the remaining coefficients of the 12 to 0.

%Assuming a data record of 240 monthly mean values, the 95% confidence
%value of the noise floor is 
conf95 = sqrt(2)*erfcinv(2*.05/2);
upconf = conf95/sqrt(240);

%create the damped persistence vector
dampedPers = muCorrMonths;

%Find the first autocorrelation value <= the 95% conf
firstZero=find(dampedPers <= upconf,1);

%Set the months at that point and beyond to 0
if ~isempty(firstZero)
    dampedPers(firstZero:end)=0;
end

resOut.dampedPers=dampedPers;

toc

save([stationNum,'_res'],'resOut');

end

