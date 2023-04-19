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


%%
%Do a month to month calculation of a normal distribution of residuals over
%the length of the time series

%Will do this by looping through years and months and filling a year/month
%vector
ind=0;
paddedMonths=[];
for yr = year(dTime(1)):1:year(dTime(end))
    for mo=1:12
        ind=ind+1;
        yrMoVec(ind,1)=yr;
        yrMoVec(ind,2)=mo;
        findInd=find( year(dTime)==yr & month(dTime) == mo);
        if isempty(findInd)
            resOut.mu_month(ind)=NaN;
            resOut.sigma_month(ind)=NaN;
            paddedMonths=cat(1,paddedMonths,ind);
        else
            resOut.mu_month(ind)=nanmean(resOut.res(findInd));
            resOut.sigma_month(ind)=nanstd(resOut.res(findInd));
        end
    end
end

%Now reshape the mu and sigma vectors by year and take the averages accross
%all years to create the climatology
sizeYears=year(dTime(end))-year(dTime(1))+1;
sizeMonths=12;

mu_month_reshape=reshape(resOut.mu_month,[sizeMonths,sizeYears])';
sigma_month_reshape=reshape(resOut.sigma_month,[sizeMonths,sizeYears])';

resOut.mu_monthAvg=nanmean(mu_month_reshape);
resOut.sigma_monthAvg=nanmean(sigma_month_reshape);

%set up and output the year-month dates
resOut.yrMoTime=datetime(yrMoVec(:,1),yrMoVec(:,2),ones(length(yrMoVec),1));

%Now need to remove the NaNs that we potentially added at the start and end
%of the monthly time series to make the climatology monthly calculations
resOut.yrMoTime(paddedMonths)=[];
resOut.mu_month(paddedMonths)=[];
resOut.sigma_month(paddedMonths)=[];

%Now go through and calculate the monthly anomaly
for i =1:length(resOut.yrMoTime)
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
% calculate the deciles of the adjusted tide predictions and the
% corresponding mu and sigma 

%Calculate the decile of the tide predictions
deciles=prctile(resOut.predAdj,[0:10:100]);
%adding a 1m offset to ensure min and max are captured within bounds
deciles(1)=deciles(1) - 1;
deciles(11)=deciles(11) + 1;

%Calculate the mu and sigma of the total data set
allMu = nanmean(resOut.res);
allSigma = nanstd(resOut.res);

decileMu=NaN(10,1);
decileSigma=NaN(10,1);

%calculate the mu and sigma of the deciles and relate those back to the mu
%and sigma of the total (we are assuming this relationship is independent
%of time).
for i = 1:10
    decileMu(i)=nanmean(resOut.res(resOut.predAdj >= deciles(i) & resOut.predAdj <= deciles(i+1))) - allMu;
    decileSigma(i)=nanstd(resOut.res(resOut.predAdj >= deciles(i) & resOut.predAdj <= deciles(i+1))) - allSigma;
end

resOut.deciles=deciles;
resOut.decileMu=decileMu;
resOut.decileSigma=decileSigma;

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

