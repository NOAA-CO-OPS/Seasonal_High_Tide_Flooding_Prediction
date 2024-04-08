function [cy] = cdf_calc(mu,sigma,px)

% CDF_CALC takes distribution parameters (in this case mu and sigma) and 
% outputs a  cdf (cy) given defined px values (which are wl in meters)
% 
% For the time being this is mu (mean) and sigma (std-dev), but could be 
% any distribution parameter. 
%  
% The output (cy) is used as the input to prob_calc, which calculates an
% hourly probability of flooding given an hourly time series and cdf matrix

% mu = distribution mean
% sigma - distribution std dev
% px = an array of x values (wl in meters) for calculating the pdf and cdf


%Calculate the pdf, default is normal but could easily modify the code to try
%other distributions
pd = makedist('Normal',mu,sigma);

%Cacluate the cdf
cy = 1-cdf(pd,px);


end

