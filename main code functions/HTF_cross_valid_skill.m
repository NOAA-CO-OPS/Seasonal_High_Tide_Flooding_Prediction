function [skillOut]=HTF_cross_valid_skill(stationNum,minorThresh,slt,epochCenter,testing_startDate,testing_endDate,data,resOut)

%This function works with HTF_cross_validation.m and takes the data and residual output from the code
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
%load([stationNum,'_data']);
%load([stationNum,'_res']);

wl=data.wl;
dTime=data.dateTime;
%tidePred=resOut.predAdj; % this does not function with cross-validation


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
%skillOut.dateTime=NaT(366,240);
%skillOut.prob=NaN(366,240);
%skillOut.leadTime=NaN(366,240);

% Remove time components by converting to just the date
% resOut.yrMoTime = dateshift(resOut.yrMoTime, 'start', 'day');
% resOut.yrMoTime = datetime(resOut.yrMoTime, 'Format', 'dd-MMM-yyyy');
% testing_startDate = dateshift(testing_startDate, 'start', 'day');
% testing_startDate = datetime(testing_startDate, 'Format', 'dd-MMM-yyyy');
% testing_endDate = dateshift(testing_endDate, 'start', 'day');
% testing_endDate = datetime(testing_endDate, 'Format', 'dd-MMM-yyyy');




%Will need to run the prediction code 239 times to generate predictions to
%cover the entire 20 year observation period.  
% 
%Set up the skill matrices
testing_startDate.Format = 'dd-MMM-yyyy';
testing_endDate.Format = 'dd-MMM-yyyy';
testDates = testing_startDate:testing_endDate;
testMonthDates = testing_startDate:calmonths(1):testing_endDate;
%disp(testing_dateArray)
subset_endDate = testing_startDate + calmonths(12);

skillOut.dateTime = transpose(unique(dateshift(testDates, 'start', 'day')));
numCols = size(skillOut.dateTime, 2);
numRows = size(skillOut.dateTime, 1);
skillOut.prob = NaN(numRows, numCols);
skillOut.leadTime = NaN(numRows, numCols);


% Need to skip the first time
%step since we don't have observations the month before, so filling the
%dateTime values for comparing with obs later
%check if there is a leap year
% use test dates
% if mod(year(testMonthDates(1)),4) == 0 && (mod(year(testMonthDates(1)),100) ~= 0 || mod(year(testMonthDates(1)),400) == 0)
%     skillOut.dateTime(:,1)=testMonthDates(1):day(1):testMonthDates(1)+calmonths(12);
% else
%     skillOut.dateTime(:,1)=testMonthDates(1):day(1):testMonthDates(1)+calmonths(12)-day(1);
% end   

%disp(testMonthDates)
for i = 2:length(testMonthDates)
    %disp(i)
    disp(['Formatting prediction starting in:' datestr(testMonthDates(i))]);

    %For the end of the time series, need to shorten the prediction window
    %since we won't have data beyond the present month
    if testMonthDates(i)+calmonths(11) > testMonthDates(end)
        [predOut] = HTF_predict(stationNum,minorThresh,slt,epochCenter,datestr(testMonthDates(i),'yyyymm'),datestr(testMonthDates(end),'yyyymm'),resOut,data);
    else
        [predOut] = HTF_predict(stationNum,minorThresh,slt,epochCenter,datestr(testMonthDates(i),'yyyymm'),[],resOut,data);
    end
    
    % Need to figure out how to break these into year long chunks that
    % increment up 1 day with each ith column
    skillOut.prob(1:length(predOut.dailyProb),i)=predOut.dailyProb;
    skillOut.dateTime(1:length(predOut.dailyProb),i)=predOut.dailyProbTime;

    % Get the number of columns
%    numCols = size(predOut.dailyProb, 2);

    % Loop through each column and increment the datetime
%    for j = 1:numCols
%        testing_startDate = predOut.dailyProbTime + caldays(j-1);

%        skillOut.dateTime(:, j) = testing_startDate + caldays(0:length(predOut.dailyProb)-1);
%    end    

    %I want to create a corresponding matrix to indicate the forecast lead
    %time for each value
    monthsOrder=month(predOut.dailyProbTime);
    yearsOrder = year(predOut.dailyProbTime);
    compositeTime = yearsOrder * 12 + monthsOrder;
    % Displaying the unique values and their counts
    [uniqueCompositeTime, ~, idx] = unique(compositeTime);
    numUniquePeriods = length(uniqueCompositeTime);
    % Initialize leadMonths with zeros
    leadMonths = zeros(1, length(predOut.dailyProbTime));
    % Assign lead months based on unique periods
    for k = 1:numUniquePeriods
        leadMonths(idx == k) = k; 
    end
    % Store the lead months in skillOut
    skillOut.leadTime(1:length(predOut.dailyProb), i) = leadMonths;
end

%% 
%Now I need to go day by day and set up the obs in daily max and then flag
%a 1 if the obs exceeded the flood threshold

%set up the output arrays
nDays = ceil(days(dTime(end)-dTime(1)));
%disp(nDays)
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
    %disp(dailyObs(i));
    %[dailyTidePred(i),~]=max(tidePred(dayInd));
    if dailyObs(i) >= minorThresh
        ynObs(i)=1; 
    elseif isfinite(dailyObs(i))
        ynObs(i)=0;
    end 
end
%disp(ynObs)

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
%skillOut.dailyProb = transpose(predOut.dailyProb);
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

% For cross-validation, 1-month lead ONLY
% skillOut.totalYes = nansum(ynObs);
% skillOut.fracYes = skillOut.totalYes/length(find(isfinite(ynObs)));
% skillOut.bs = NaN(1,1);
% skillOut.bss = NaN(1,1);
% skillOut.bsSE = NaN(1,1);
% skillOut.bssSE = NaN(1,1);
% skillOut.recall = NaN(1,1);
% skillOut.falseAlarm = NaN(1,1);

% %Calculate Brier Scores and Brier Skill Scores by month lead time
% [skillOut.bs,skillOut.bss,skillOut.bsSE,skillOut.bssSE] = BrierScore(ynObs,skillOut.dailyProb);
% %Calculate reliability stats (to plot with reliability diagrams)
% skillOut.rel = reliability(ynObs,skillOut.dailyProb);
% %Confusion matrix and stats for the 5% warning threshold
% skillOut.confusion05 = confusionStats(ynObs,skillOut.dailyProb,0.05);
% %Output recall (fraction of flood events predicted) and false alarm
% %rates (no flood, but warned one might occur)
% skillOut.recall = skillOut.confusion05.recall;
% skillOut.falseAlarm = skillOut.confusion05.falseAlarm;


%Now for the 1-month lead ONLY, calculate skill for the last 5 years and 10
%years to assess potential influence of SLR

%yr10ind=find(skillOut.dailyProbTime >=skillOut.dailyProbTime(end)-years(10));
%yr5ind=find(skillOut.dailyProbTime >=skillOut.dailyProbTime(end)-years(5));

%10yr
%skillOut.totalYes10yr=nansum(ynObs(yr10ind));
%skillOut.fracYes10yr=skillOut.totalYes10yr/length(find(isfinite(ynObs(yr10ind))));
%skillOut.bss10yr=NaN;
%skillOut.bss10yr=NaN;
%skillOut.bssSE10yr=NaN;
%skillOut.recall10yr=NaN;
%skillOut.falseAlarm10yr=NaN;

%[~,skillOut.bss10yr,~,skillOut.bssSE10yr] = BrierScore(ynObs(yr10ind),skillOut.dailyProb(1,yr10ind));
%skillOut.confusion10yr = confusionStats(ynObs(yr10ind),skillOut.dailyProb(1,yr10ind),0.05);
%skillOut.recall10yr=skillOut.confusion10yr.recall;
%skillOut.falseAlarm10yr=skillOut.confusion10yr.falseAlarm;

%5yr
%skillOut.totalYes5yr=nansum(ynObs(yr5ind));
%skillOut.fracYes5yr=skillOut.totalYes5yr/length(find(isfinite(ynObs(yr5ind))));
%skillOut.bss5yr=NaN;
%skillOut.bss5yr=NaN;
%skillOut.bssSE5yr=NaN;
%skillOut.recall5yr=NaN;
%skillOut.falseAlarm5yr=NaN;

%[~,skillOut.bss5yr,~,skillOut.bssSE5yr] = BrierScore(ynObs(yr5ind),skillOut.dailyProb(1,yr5ind));
%skillOut.confusion5yr = confusionStats(ynObs(yr5ind),skillOut.dailyProb(1,yr5ind),0.05);
%skillOut.recall5yr=skillOut.confusion5yr.recall;
%skillOut.falseAlarm5yr=skillOut.confusion5yr.falseAlarm;


%%
%Save the files
save([stationNum,'_skill'],'skillOut');


end



