function [decileMu, decileSigma] = decile_calc(data, dependence, nbins)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DECILE_CALC - calculate the 'deciles' of the 'adjusted tide predictions' and the corresponding mu and sigma of the 'residuals'
% DEFAULT SETTING - decile_calc(res, pred, 10)

% INPUT
% data - timeseries of the data to bin into 'deciles' and compute PDFs. Previously 'res' but can also be nontidal residual (NTR) -  will need to add subroutine somewhere to compute hrly ntr
% dependence - dataset that the 'deciles' are dependent on. Previously adjusted tide predictions but can also be tides
% nbins - the number of equal bins used to divide the dependence (i.e., tide range)

% OUTPUT
% decileMu - decile climatological mu
% decileSigma - decile climatological sigma

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Calculate the decile of the tide predictions
deciles=prctile(dependence,[0:nbins:100]); %Think we could just put nbins, not [0:nbins:100]

%adding a 1m offset to ensure min and max are captured within bounds
deciles(1)=deciles(1) - 1;
deciles(11)=deciles(nbins+1) + 1;

%Calculate the mu and sigma of the total data set
allMu = nanmean(data);
allSigma = nanstd(data);

decileMu=NaN(nbins,1);
decileSigma=NaN(nbins,1);

%calculate the mu and sigma of the deciles and relate those back to the mu
%and sigma of the total (we are assuming this relationship is independent
%of time).
for i = 1:nbins
    decileMu(i)=nanmean(data(dependence >= deciles(i) & dependence <= deciles(i+1))) - allMu;
    decileSigma(i)=nanstd(data(dependence >= deciles(i) & dependence <= deciles(i+1))) - allSigma;
end

end