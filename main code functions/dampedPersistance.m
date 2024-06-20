function [dampedPers] = dampedPersistance(mu_monthAmly,sigma_monthAmly, yrMoTime)

%dampedPersistance takes the monthly SL anomaly values and calculates a
%version of damped persistence to use as a prediction in the HTF predict
%code. For now this is just the cross correlation from the entire data set,
%however this could be calculated differently to enable greater
%independence from the underlying data. This modularization should enable
%testing of alternative approaches.

%mu_monthAmly - The mean monthly sea level anomaly value for each month of
%the data record

%sigma_monthAmly - The standard deviation monthly sea level anomaly value for each month of
%the data record

%yrMoTime - The datetime vector of each month of the data record

%dampedPers - The damped persistence values from months 1 to 12, set to 0
%if not stastically significant

%number of monthly values
n = length(mu_monthAmly);

%% Autocorrelation calculation

% Now perform an auto-correlation (via cross correlation of the lagged time series) with the monthly anomaly to help determine 
% the persistence length scale and damped persistence coefficient

%Need to first interp for NaNs in the mu_monthlyAmly and sigma data
mu_monthAmlyInt=interpnan(mu_monthAmly,datenum(yrMoTime));
sigma_monthAmlyInt=interpnan(sigma_monthAmly,datenum(yrMoTime));

%now do the autocorrelation for mu out 12 months (sigma is not
%correlated)
numLags=12;
[r,~]=xcorr(mu_monthAmlyInt,numLags,'coef');
muCorrMonths=r(numLags+2:end);



%% Create the damped persistence coefficient vector.  
% This is done by finding the first autocorrelation value < the 95% confidence 
% threshold and setting the remaining coefficients of the 12 to 0.

%Assuming a data record of "n" monthly mean values, the 95% confidence
%value of the noise floor is 
conf95 = sqrt(2)*erfcinv(2*.05/2);
upconf = conf95/sqrt(n);

%create the damped persistence vector
dampedPers = muCorrMonths;

%Find the first autocorrelation value <= the 95% conf
firstZero=find(dampedPers <= upconf,1);

%Set the months at that point and beyond to 0
if ~isempty(firstZero)
    dampedPers(firstZero:end)=0;
end







end

