function [newVar,newTime]=addNaNs(var,time,interval)

%this function takes a time series with missing data points without nans
%and creates a new time series with all data points and NaNs where needed

%interval is the chosen interval for the new time series in datenum units
%(e.g. 1 = 1 datenum day, 1/240 = 6 minutes)

%based on interval chosen, start time should have a zero value for time
%units under interval unit (i.e. if the interval is minutes, the seconds
%should be 0)

%By G. Dusek - last edited (use text update) - 12/2/19

firstTime=datevec(time(1));
intVec=datevec(interval);
last=find(intVec>0,1,'last');
if last < 6
    firstTime(last+1:end)=0;
end
firstTime=datenum(firstTime);

newTime=firstTime:interval:time(end);
%this is to eliminate some round-off errors
newTime=datevec(newTime);
newTime=datenum(newTime);


n=length(var);
nNew=length(newTime);
newVar=nan(nNew,1);
prevInd=[];
%Note need to add some logic in here to deal with repeat time stamps.
%Basically just skip the second one

for i=1:n
    diffs=abs(newTime-time(i));
    [~,ind]=nanmin(diffs);
    %If the index is same as the previous iteration just skip it (e.g. this
    %means that there are repeat times in the input vector)
    if ind == prevInd
        continue
    end
    prevInd=ind;
    %something to account for bad time intervals
    if isnan(newVar(ind)) 
        newVar(ind)=var(i);
    else
        newVar(ind+1)=var(i);
    end
end

%out.time=newTime;
%out.newVar=newVar;


    




