function [percentileMu, percentileSigma, percentiles] = percentile_calc(data, dependence, p_percentile)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PERCENTILE_CALC - calculate the percentiles of the 'adjusted tide predictions' and the corresponding mu and sigma of the 'residuals'
% DEFAULT SETTING - percentile_calc(res, pred, 10)

% INPUT
% data - timeseries of the data to bin into deciles and compute PDFs. Previously 'res' but can also be nontidal residual (NTR)
% dependence - dataset that the percentiles are dependent on. Previously used 'adjusted tide predictions' but can also just be tides
% p_percentile - single value (previously = 10; deciles). The percentiles in the interval [0, 100] used to divide the dependence (i.e., tide range)

% OUTPUT
% percentileMu - percentile climatological mu
% percentileSigma - percentile climatological sigma
% percentiles - percentiles used for calculating percentile distributions

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Calculate the percentile of the tide predictions
percentiles=prctile(dependence, [0:p_percentile:100]);

%adding a 1m offset to ensure min and max are captured within bounds
percentiles(1)=percentiles(1) - 1;
percentiles(end)=percentiles(end) + 1;

%Calculate the mu and sigma of the total data set
allMu = nanmean(data);
allSigma = nanstd(data);

percentileMu=NaN(length(percentiles)-1,1);
percentileSigma=NaN(length(percentiles)-1,1);

%calculate the mu and sigma of the percentiles and relate those back to the mu
%and sigma of the total (we are assuming this relationship is independent
%of time).
for i = 1:length(percentiles)-1;
    percentileMu(i)=nanmean(data(dependence >= percentiles(i) & dependence <= percentiles(i+1))) - allMu;
    percentileSigma(i)=nanstd(data(dependence >= percentiles(i) & dependence <= percentiles(i+1))) - allSigma;
end

end