function [predOut] = HTF_predict(stationNum,minorThresh,slt,epochCenter,startMonth,endMonth,resOut,data)

%This function takes the data and residual output from the code
%HTF_data_pull.m and HTF_residual_calc.m and calculates forward looking
%predictions out to a maximum of 12 months

% stationNum - stationNum as as a string (eg. '1820000')
% minorThresh - The minor HTF flood threshold for the station relative to MHHW
% slt - The sea level trend to apply to the tide predictions in mm/yr
% epochCenter - The date for the center of the station's tidal epoch in partial years, usually 1992.5
% startMonth - The first month to calculate a prediction in the format 'yyyymm' - if left empty
%   [], will default to the first month after the last month of observations
% endMonth - The last month to calculate a prediction in the format 'yyyymm' - if left empty [],
%   will default to 12 months after the start month
% resOut - Set to [] if performing forward looking predictions. If
%   predictions are being run in skill assessment mode (backward looking) it
%   is faster to load the resOut structure and pass it to the function.
% data - Set to [] if performing forward looking predictions. If
%   predictions are being run in skill assessment mode (backward looking) it
%   is faster to load the data structure and pass it to the function.


%Dependencies:

% tc.m
% addNaNs.m
% interpnan.m

%%

%Check to see if passed a resOut structure. If YES then assume we want to
%run this as a skill assessment (ie. backward looking)
if isempty(resOut)
    %Load the residual information data from the mat file
    load([stationNum,'_res']);
    %Assume not a skill assessment
    skillAssessment = 'n';
else
    %If we pass a res structure, assume we do want to run a skill assessment
    skillAssessment = 'y';
end

%Define the start and stop times for the predictions
if isempty(startMonth)
    startTime=resOut.dateTime(end)+hours(1); %start time should be 1 hour after the end of the previous month
else
    startTime=datetime(startMonth,'InputFormat','yyyyMM');
end

if isempty(endMonth)
    endTime=startTime+calmonths(12)-hours(1); %end time is 1 hour less than adding 12 months
else
    endTime=datetime(endMonth,'InputFormat','yyyyMM')+calmonths(1)-hours(1);
end

%convert to strings
startStr=datestr(startTime,'yyyymmdd');
endStr=datestr(endTime,'yyyymmdd');


%%


%Check if using already downloaded predictions or need to use the API to
%download
if skillAssessment == 'n'

    %Grab the hourly tide predictions in Local Time for the forward looking
    %predictions
    [pred1hr] = getAPIdata(stationNum,startStr,endStr,'predictions','DatumBias','MHHW','Interval','h','TimeZone','lst_ldt');
    timeNum = pred1hr.DateTime;
    pred = pred1hr.Prediction;

    %Add a nan where the lst to ldt jumps forward by an hour in march
    [pred,timeNum]=addNaNs(pred,timeNum,1/24);

    %fill the nan left by grabbing lst/ldt with a linear interp.
    pred = fillmissing(pred,'movmean',3); 

    %Create the datetime vector
    dTime = tc(timeNum);

elseif skillAssessment == 'y'

    %Note that backward looking predictions for model creation are
    %generated in UTC, so daylight savings need-not be addressed.
    dTime = startTime:hours(1):endTime;
    timeInd=find(data.dateTime >= startTime & data.dateTime <= endTime);
    pred = data.pred(timeInd);
end


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
sltAdd=startTrend+(sltTotal./length(pred)).*(0:1:length(pred)-1); % the time by time SLT addition
predAdj=pred+sltAdd';


%% 
% calculate remaining "freeboard" by subtracting from nuisance level
freeboard=minorThresh-predAdj;

%% 
% Calculate the likelihood of exceeding the flood threshold given the
% adjusted tide predictions and the applied damped persistence to the last
% observed monthly mean SL anomaly

%List the months in the prediction time series
monthArray=month(dTime);
monthList = unique(monthArray,'stable');
numMonths=length(monthList);

%calculate the cdf for each of the forward looking months (up to 12) and each of the 10 deciles
px = -2:.005:15;
cy=NaN(numMonths,10,length(px));

%Create the persistence vector by multiplying the damped persistence
%coefficent vector with the most recent monthly anomaly value

%First we need to find the anomaly value we should be using (for the case
%of forward looking predictions, this will just be the last value of the
%monthly observations).
amlyInd=find(resOut.yrMoTime < startTime, 1,'last');

if isnan(resOut.mu_monthAmly(amlyInd))
    %if there isn't a valid anomly value for the month before predictions,
    %check back the previous 11 months and see if there is an anomaly and
    %apply that instead, filling the rest of the values with zeros
    warning(['No observed SL anomaly value for month: ' datestr(resOut.yrMoTime(amlyInd)) '. Using previous month or climatology instead.']);
    persApply = zeros(numMonths,1); %Set to zeroes (e.g. just using climatology if no obs within 12 months)
    amlyInd12=find(resOut.yrMoTime < startTime, 12,'last');
    amlyArray12=resOut.mu_monthAmly(amlyInd12);
    amlyLastGoodInd=find(isfinite(amlyArray12),1,'last');
    if ~isempty(amlyLastGoodInd)
        amlyApply=amlyArray12(amlyLastGoodInd);
        dampedApply=zeros(12,1);
        dampedApply(1:amlyLastGoodInd)=resOut.dampedPers(12-amlyLastGoodInd+1:12);
        persApply = amlyApply.*dampedApply;
    end
else
    persApply = resOut.mu_monthAmly(amlyInd).*resOut.dampedPers(1:numMonths);
end


%Allocate the distributions going forward in time
for i = 1:numMonths
    %What is the month of the year for the month predicted 
    monthIn=monthList(i);
    for j = 1:10
        pd = makedist('Normal',resOut.mu_monthAvg(monthIn)+persApply(i)+resOut.decileMu(j),resOut.sigma_monthAvg(monthIn)+resOut.decileSigma(j));
        cy(i,j,:) = 1-cdf(pd,px);
    end
end

%Apply the cdf to determine probability of exceedance each hour
forecastProb=NaN(length(predAdj),1);

for i = 1:length(dTime)
    xVal=find(px > freeboard(i),1);
    monthIndex=find(monthList == month(dTime(i)));
    decileInd=find(resOut.deciles <= predAdj(i),1,'last');
    cyHour=cy(monthIndex,decileInd,:);
    forecastProb(i)=cyHour(xVal);
end


%%
%Calculate all peak freeboard (will actually be inverse), likelihoods and corresponding times
[peakFb,peakInd]=findpeaks(-1*freeboard);
peakProb=forecastProb(peakInd);

peakTime=dTime(peakInd);

%%
% In preparation for the cumulative probability, calculate the correlation
% coefficient of the hourly residual and compute the inverse

%Need to linearly interpolate any missing data and detrend
resInt=detrend(interpnan(resOut.res,datenum(resOut.dateTime)));

lags = 24;
r = xcorr(resInt,lags,'coeff');
%set the time=0 probability to 0 since we want to retain that prob as
%completely independent
r(25)=0;

%Calculate the coefficient as the fraction that is uncorrelated
r = 1-r;

%%
%Calculate the daily cumulative probality

for i=1:length(dTime)/24
    ind=i*24-23:i*24;
    
    forecastProbVal=forecastProb(ind);
  
    [dailyFreeboard(i),maxInd]=max(-1*freeboard(ind));
    dailyProbTime(i)=dTime(ind(1));
    
    %Calculate the cumulative probability starting at the max index
    
    %first, using the max index in the 24 hour period slice the correlation
    %coefficients respectively
    rSub = r(25-maxInd+1:25-maxInd+24);
    
    % calculate the fraction of the probabilities which is independent and subtract from 1 to calculate the probability it DOESN'T flood
    inFrac= 1 - forecastProbVal.*rSub;
    %calculate the probability that it doesn't flood at all for the window and then subtract from 1 for the probability it floods at least once
    dailyProb(i) = 1 - prod(inFrac); 
     
end

    

%%
%Set up the output

predOut.stationNum=stationNum;
predOut.minorThresh=round(minorThresh,3);
predOut.dateTime=dTime;
predOut.freeboard=-1*freeboard; %using inverse freeboard to make it more intuitive (larger = more flooding)
predOut.hourlyProb=forecastProb;
predOut.hourlyPeakFreeboard=peakFb;
predOut.hourlyPeakProb=peakProb;
predOut.hourlyPeakTime=peakTime;
predOut.dailyProb=dailyProb;
predOut.dailyFreeboard=dailyFreeboard;
predOut.dailyProbTime=dailyProbTime;

%Only save the prediction output if NOT performing a skill assessment
if skillAssessment == 'n'
    save([stationNum,'_pred'],'predOut');
end


end

