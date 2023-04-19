function [data] = HTF_data_pull(stationNum,startStr,endStr)
%This function downloads, preps and saves the necesssary water level data
%and predictions to run the High Tide Flooding residual calculations,
%predictions and skill assessments

%*Dependencies*
%Requires the following matlab code in the path:
% getAPIdata.m
% addNaNs.m
% tc.m

%stationNum - stationNum (eg. 1820000)
%startStr - The start year, month, day as a string - eg '19970101'
%endYearMonth - The end year, month, day as a string - eg '20161231'
%***Note that these MUST start and stop at the beginning and end of the
%months - as this will only grab entire months at a time.

tic
%%
%chang the stationNum to a string
stationNum=num2str(stationNum);

%%
%Grab all years of 6 minute predictions
[pred1hr] = getAPIdata(stationNum,startStr,endStr,'predictions','DatumBias','MHHW','Interval','h');


%%
%Grab all years of 1 hour verified observations
[obs1hr] = getAPIdata(stationNum,startStr,endStr,'hourly_height','DatumBias','MHHW');


%%
%Check for missing data and add in nans
%first need to check to ensure that there is a data point at the first and
%last day of the months input

dStart=obs1hr.DateTime(1);
dEnd=obs1hr.DateTime(end);

tStart=datenum([startStr,'0000'],'yyyymmddHHMM');
tEnd=datenum([endStr,'2300'],'yyyymmddHHMM');

if dStart ~= tStart
    warning('First datetime in observations is missing: inserting NaN')
    obs1hr.DateTime=cat(1,tStart,obs1hr.DateTime);
    obs1hr.WaterLevel=cat(1,NaN,obs1hr.WaterLevel);
end

if dEnd ~= tEnd
    warning('Last datetime in observations is missing: inserting NaN')
    obs1hr.DateTime=cat(1,obs1hr.DateTime,tEnd);
    obs1hr.WaterLevel=cat(1,obs1hr.WaterLevel,NaN);
end

%Now add in NaNs
[obs1hr.WaterLevel,obs1hr.DateTime]=addNaNs(obs1hr.WaterLevel,obs1hr.DateTime,1/24);

%Do a check to see that the prediction time series and obs time series are
%the same length and times are the same.  If not throw an error

if length(obs1hr.DateTime) ~= length(pred1hr.DateTime)
    error('length of obs time series is different than length of pred time series')
end

compareTime=obs1hr.DateTime-pred1hr.DateTime;

if max(abs(compareTime)) > 0
    error('Time arrays for obs and prediction series are different')
end

%%
%Now add the time and pred and obs to the output structure
data.time=obs1hr.DateTime;
data.timevec=datevec(data.time); %calculate the date vector
data.dateTime=tc(data.time); %calculate the date time - tc is a function to convert
data.wl=obs1hr.WaterLevel;
data.pred=pred1hr.Prediction;


toc

save([num2str(stationNum),'_data'],'data');

end

