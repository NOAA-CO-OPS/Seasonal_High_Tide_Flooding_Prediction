function [predWithTrend,trendAdded] = addTrend(pred,dTime,slt,epochCenter)

%addTrend takes a tide prediction time series and adds a sea level trend
%to account for long-term sea level variability in the time series. The initial 
%implementation utilizes a linear trend, however this could be adapted with
%non-linear trends, yearly averages, or other ways to account for the
%long-term SL change.

%pred - the tide prediction time series
%dTime - the dateTime vector for the predictions
%slt - the sea level trend in mm/year
%epochCenter - the center point of the tidal epoch the data set and tide
%predictions are based on. This will be where MSL = 0 (typically 1992.5 for most locations), 
% and thus the start point for adding/subtracting trend values from the remainder of the time
%series moving either forward or backward from this point

%predWithTrend - the output of the tide prediction time series with the trend added
%trendAdded - the time series of the trend values added to each time step


%change trend to meters
slt=slt/1000;

%How much of the trend goes from the center epoch to the start date
startTrend= slt*years((dTime(1)-epochCenter));

% total change over the length of the predictions 
sltTotal=slt*years(dTime(end)-dTime(1)); 

% the time by time SLT addition
trendAdded=startTrend+(sltTotal./length(pred)).*(0:1:length(pred)-1); 

% The tide predictions with trend added
predWithTrend=pred+trendAdded';




end