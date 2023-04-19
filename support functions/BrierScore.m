function [bs,bss,bsSE,bssSE]=BrierScore(obs,forecast)

%%
%This function calculates the Brier Score between a forecast and observed
%time series and Brier Skill Score between the forecast and observed mean
%likelihood.  It also calculates a 95% confidence estimate for the bss
%following the method in Bradely et al, 2007 "sampling uncertainty and
%confidence intervals for the brier score and brier skill score".

%obs = the observed yes or no (0,1) time series if a forecasted event
%occurred or not

%forecast = the forecast likelihood (0 to 1) of the even occuring

%G. Dusek 4/6/23 - Removed positive BS and BSS calculations, since no
%longer using these. Previous calls to this function will need to remove
%the last three outputs when calling the function.

%%
%First check to see if the inputs are the same orientation
if size(obs,1) ~= size(forecast,1)
    obs=obs';
end

%Ensure the forecast has the same nan data points as the observed
indNaN=find(isnan(obs));
forecast(indNaN) = NaN;

bs=nanmean((forecast-obs).^2);

%Calculate the BSS
climate=nanmean(obs);

%climForecast=zeros(size(obs)); %To use a 0 reference forecast
climForecast=ones(size(obs)).*climate;

bsClimate=nanmean((climForecast-obs).^2);

bss=1-(bs/bsClimate);

%%
%Initial stats
n=length(find(isfinite(obs)));
meanObs=nanmean(obs);

%%
%The different moments we need to include to calculate the var and cov
%estimates

%Sample variance of the observations
varObs= meanObs*(1-meanObs);

%Forecast mean for 1 observations
ind1=find(obs==1);
meanFObs1=nanmean(forecast(ind1));

%2nd moment of the forecast for 1 observations
mom2FObs1=nanmean((forecast(ind1)).^2);

%2nd moment of the forecast for 0 observations
ind0=find(obs==0);
mom2FObs0=nanmean((forecast(ind0)).^2);

%3rd moment of the forecast for 1 observations
mom3FObs1=nanmean((forecast(ind1)).^3);

%4th moment of the forecast
mom4F=nanmean((forecast.^4));

%%
% Now solving for the three coefficients d1, d2 and d3

d1=(1/(varObs^2))*((n/(n-1))^2);

d2=(((1-bss)^2)/(varObs^2))*((n/(n-1))^4);

d3=(-2*(1-bss)/(varObs^2))*((n/(n-1))^3);

%%
%Now solving for the quantities MSE variance, the variance of the sample
%variance and the MSE covariance

varMSE = 1/n * (mom4F+meanObs*(1-4*mom3FObs1+6*mom2FObs1-4*meanFObs1)-bs^2);

varVar = ((n-1)/(n^3)) * ((n-1) + varObs*(6-4*n)) * varObs;

covMSE = ((n-1)/(n^2)) * varObs * (1-2*meanObs) * ((mom2FObs1-mom2FObs0) + (1-2*meanFObs1));

%% 
%Now solving for the standard errors for BS and BSS

%The standard error of the BS
bsSE=varMSE^.5;

%The variance of the BSS
varBSS = abs(d1*varMSE + d2*varVar + d3*covMSE); %Added abs to account for rare instances when we get a negative due to - bss

%The standard error of the BSS
bssSE=varBSS^.5;









