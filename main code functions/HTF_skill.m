function [skillOut]=HTF_skill(stationNum,minorThresh,slt,epochCenter)

%This function takes the data and residual output from the code
%HTF_data_pull.m and HTF_residual_calc.m, calculates 12 month predictions
%for the historic data set, and performs a skill assessment for a specific station 
%for the duration of the observational data.

% stationNum - stationNum as as a string (eg. '1820000')
% minorThresh - The minor HTF flood threshold for the station relative to MHHW
% slt - The sea level trend to apply to the tide predictions in mm/yr
% epochCenter - The date for the center of the station's tidal epoch in partial years, usually 1992.5

% dependencies
% BrierScore.m
% confusionStats.m
% reliability.m

%%
%Load the observed time series from the mat file (a structure called data)
load([stationNum,'_data']);
load([stationNum,'_res']);

wl=data.wl;
dTime=data.dateTime;
tidePred=resOut.predAdj;

%% Output the metadata to the data structure
skillOut.stationNum=stationNum;
skillOut.minorThresh=round(minorThresh,3);
skillOut.slt=slt;
skillOut.epochCenter=epochCenter;

%%
%Will need to run the prediction code 239 times to generate predictions to
%cover the entire 20 year observation period.  
% 
%Set up the skill matrices
skillOut.dateTime=NaT(366,240);
skillOut.prob=NaN(366,240);
skillOut.leadTime=NaN(366,240);
% 
% Need to skip the first time
%step since we don't have observations the month before, so filling the
%dateTime values for comparing with obs later
skillOut.dateTime(:,1)=resOut.yrMoTime(1):day(1):resOut.yrMoTime(1)+calmonths(12)-day(1);

for i = 2:length(resOut.yrMoTime)
    disp(['Generating prediction starting in:' datestr(resOut.yrMoTime(i))]);
    %For the end of the time series, need to shorten the prediction window
    %since we won't have data beyond the present month
    if resOut.yrMoTime(i)+calmonths(11) > resOut.yrMoTime(end)
        [predOut] = HTF_predict(stationNum,minorThresh,slt,epochCenter,datestr(resOut.yrMoTime(i),'yyyymm'),datestr(resOut.yrMoTime(end),'yyyymm'),resOut,data);
    else
        [predOut] = HTF_predict(stationNum,minorThresh,slt,epochCenter,datestr(resOut.yrMoTime(i),'yyyymm'),[],resOut,data);
    end
    skillOut.prob(1:length(predOut.dailyProb),i)=predOut.dailyProb;
    skillOut.dateTime(1:length(predOut.dailyProb),i)=predOut.dailyProbTime;
    %I want to create a corresponding matrix to indicate the forecast lead
    %time for each value
    monthsOrder=month(predOut.dailyProbTime);
    change_positions = [1 diff(monthsOrder)~=0] == 1;
    count_array = 1:length(find(change_positions));
    leadMonths = count_array(cumsum(change_positions));
    skillOut.leadTime(1:length(predOut.dailyProb),i)=leadMonths;
end

%% 
%Now I need to go day by day and set up the obs in daily max and then flag
%a 1 if the obs exceeded the flood threshold

%set up the output arrays
nDays = ceil(days(dTime(end)-dTime(1)));
dTimeDays=NaT(nDays,1);
ynObs=NaN(nDays,1);
dailyObs=NaN(nDays,1);
dailyTidePred=NaN(nDays,1);

%Loop through day-by-day, take the max observed and see if it exceeded the
%threshold
%Will also grab the max adjusted tide prediction for each day for future
%plotting
for i =1:nDays
    dayInd = i*24-23:i*24;
    dTimeDays(i)=dTime(dayInd(1));
    [dailyObs(i),~]=max(wl(dayInd));
    [dailyTidePred(i),~]=max(tidePred(dayInd));
    if dailyObs(i) >= minorThresh
        ynObs(i)=1; 
    elseif isfinite(dailyObs(i))
        ynObs(i)=0;
    end 
end


%%
%Now we will go through the daily obs array and for each month, find the
%corresponding daily predictions for the same month (we should have 12 sets
%of daily predictions for each month, with the exception of the beginning
%of the data set).

dailyProb=NaN(12,length(dailyObs));
dailyTime=NaT(12,length(dailyObs));
dailyLead=NaN(12,length(dailyObs));
for i = 1:length(dailyObs)
    [ind] = find(skillOut.dateTime == dTimeDays(i));
    dailyProb(1:length(ind),i)=flip(skillOut.prob(ind));
    dailyTime(1:length(ind),i)=flip(skillOut.dateTime(ind));
    dailyLead(1:length(ind),i)=flip(skillOut.leadTime(ind));
end

%Output daily probabilities, where from top to bottom matrix goes from 1
%months lead time to 12 months lead
skillOut.dailyProb=dailyProb;
skillOut.dailyProbTime=dTimeDays;
skillOut.dailyObs=dailyObs;
skillOut.ynObs=ynObs;
skillOut.dailyTidePred=dailyTidePred;


%%
%Now calculate some skill estimates for the forecast over the total time
%window

skillOut.totalYes=nansum(ynObs);
skillOut.fracYes=skillOut.totalYes/length(find(isfinite(ynObs)));
skillOut.bs=NaN(12,1);
skillOut.bss=NaN(12,1);
skillOut.bsSE=NaN(12,1);
skillOut.bssSE=NaN(12,1);
skillOut.recall=NaN(12,1);
skillOut.falseAlarm=NaN(12,1);
 
for i = 1:12
    %Calculate Brier Scores and Brier Skill Scores by month lead time
    [skillOut.bs(i),skillOut.bss(i),skillOut.bsSE(i),skillOut.bssSE(i)] = BrierScore(ynObs,skillOut.dailyProb(i,:));
    %Calculate reliability stats (to plot with reliability diagrams)
    skillOut.rel(i) = reliability(ynObs,skillOut.dailyProb(i,:));
    %Confusion matrix and stats for the 5% warning threshold
    skillOut.confusion05(i) = confusionStats(ynObs,skillOut.dailyProb(i,:),0.05);
    %Output recall (fraction of flood events predicted) and false alarm
    %rates (no flood, but warned one might occur)
    skillOut.recall(i)=skillOut.confusion05(i).recall;
    skillOut.falseAlarm(i)=skillOut.confusion05(i).falseAlarm;
end

%Now for the 1-month lead ONLY, calculate skill for the last 5 years and 10
%years to assess potential influence of SLR

yr10ind=find(skillOut.dailyProbTime >=skillOut.dailyProbTime(end)-years(10));
yr5ind=find(skillOut.dailyProbTime >=skillOut.dailyProbTime(end)-years(5));

%10yr
skillOut.totalYes10yr=nansum(ynObs(yr10ind));
skillOut.fracYes10yr=skillOut.totalYes10yr/length(find(isfinite(ynObs(yr10ind))));
skillOut.bss10yr=NaN;
skillOut.bss10yr=NaN;
skillOut.bssSE10yr=NaN;
skillOut.recall10yr=NaN;
skillOut.falseAlarm10yr=NaN;

[~,skillOut.bss10yr,~,skillOut.bssSE10yr] = BrierScore(ynObs(yr10ind),skillOut.dailyProb(1,yr10ind));
skillOut.confusion10yr = confusionStats(ynObs(yr10ind),skillOut.dailyProb(1,yr10ind),0.05);
skillOut.recall10yr=skillOut.confusion10yr.recall;
skillOut.falseAlarm10yr=skillOut.confusion10yr.falseAlarm;

%5yr
skillOut.totalYes5yr=nansum(ynObs(yr5ind));
skillOut.fracYes5yr=skillOut.totalYes5yr/length(find(isfinite(ynObs(yr5ind))));
skillOut.bss5yr=NaN;
skillOut.bss5yr=NaN;
skillOut.bssSE5yr=NaN;
skillOut.recall5yr=NaN;
skillOut.falseAlarm5yr=NaN;

[~,skillOut.bss5yr,~,skillOut.bssSE5yr] = BrierScore(ynObs(yr5ind),skillOut.dailyProb(1,yr5ind));
skillOut.confusion5yr = confusionStats(ynObs(yr5ind),skillOut.dailyProb(1,yr5ind),0.05);
skillOut.recall5yr=skillOut.confusion5yr.recall;
skillOut.falseAlarm5yr=skillOut.confusion5yr.falseAlarm;


%%
%Save the files
save([stationNum,'_skill'],'skillOut');


end



