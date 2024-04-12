function [monthMu,monthSigma,decileMu,decileSigma,deciles] = dist_calc(dTime,res,pred)

%DIST_CALC takes a time series of hourly non tidal residuals (NTR) and calculates
% mu and std distribution parameters in both monthly and tidal decile
% partitions to give climatological parameters for each aspect of NTR.
% Future changes may enable doing this as effectively a 2d distribution
% (accross both month and decile (or some smaller wl partition) - e.g. the
% mu for the top 10% of predicted water levels for all januaries). This
% code will also enable future changes to distributions other than normal.

% Inputs:
% dTime - hourly datetime
% res - hourly non tidal residual (obs WL - [tide prections + trend]))
% pred - hourly tide predictions ***(with trend - will be changing to no
%        trend***

% Outputs:
% monthMu - monthly climatological mean (Jan to Dec)
% monthSigma - monthly climatological std deviation
% deciles - deciles used for calculating decile distributions
% decileMu - decile climatological mu
% decileSigma - decile climatological sigma



%% MONTHLY PART

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
            mu_by_month(ind)=NaN;
            sigma_by_month(ind)=NaN;
            paddedMonths=cat(1,paddedMonths,ind);
        else
            mu_by_month(ind)=nanmean(res(findInd));
            sigma_by_month(ind)=nanstd(res(findInd));
        end
    end
end

%Now reshape the mu and sigma vectors by year and take the averages accross
%all years to create the climatology
sizeYears=year(dTime(end))-year(dTime(1))+1;
sizeMonths=12;

mu_month_reshape=reshape(mu_by_month,[sizeMonths,sizeYears])';
sigma_month_reshape=reshape(sigma_by_month,[sizeMonths,sizeYears])';

monthMu=nanmean(mu_month_reshape);
monthSigma=nanmean(sigma_month_reshape);


%% DECILE PART

% calculate the deciles of the adjusted tide predictions and the
% corresponding mu and sigma 

%Calculate the decile of the tide predictions
deciles=prctile(pred,[0:10:100]);
%adding a 1m offset to ensure min and max are captured within bounds
deciles(1)=deciles(1) - 1;
deciles(11)=deciles(11) + 1;

%Calculate the mu and sigma of the total data set
allMu = nanmean(res);
allSigma = nanstd(res);

decileMu=NaN(10,1);
decileSigma=NaN(10,1);

%calculate the mu and sigma of the deciles and relate those back to the mu
%and sigma of the total (we are assuming this relationship is independent
%of time).
for i = 1:10
    decileMu(i)=nanmean(res(pred >= deciles(i) & pred <= deciles(i+1))) - allMu;
    decileSigma(i)=nanstd(res(pred >= deciles(i) & pred <= deciles(i+1))) - allSigma;
end



end

