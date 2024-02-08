function HTF_toCSV(stationNum,HTFrunID)

% Function to write a station's HTF predictions to a csv file

% stationNum - stationNum as as a string (eg. '1820000')
% HTFrunID - the run number for a particular time period to denote future updates 
    % This should probably be 1 for now, pending discussions with the team

%Note - before running this, you must have generated HTF daily predictions
%using the HTF_predict.m function

%The CSV file output is organized as: 
% STATION_ID  YEAR MONTH  DAY FLOOD FLOOD_CATEGORY LIKELIHOOD DIST_TO_THRESH HTB_RUN_ID

%Load the prediction mat file
load([stationNum,'_pred']);

%For Flood category we can just fill with empty or '' for now
floodCategory = {''};

%grab the times
dateTime = predOut.dailyProbTime;

%What is the length of the array
n = length(dateTime);

%convert to datevec with Year,Month,Day
timeVec=datevec(dateTime);
timeVec = timeVec(:,1:3);

%create a stationID column to repeat the ID every row
stationID=str2double(stationNum); %change to a number
stationIDcol = repmat(stationID,n,1);

%create a FLOOD_CATEGORY column to repeat that every row
floodCategoryCol = repmat(floodCategory,n,1);

%Create a HTFrun column to repeat every row
HTFrunIDcol = repmat(HTFrunID,n,1);

%grab daily Prob (LIKELIHOOD) rounded to nearest tenth of a percent
dailyProb = round(predOut.dailyProb,3);

%grab minor flood threshold to repeat every row
minorThresh = repmat(predOut.minorThresh,n,1);

%grab daily freeboard (DIST_TO_THRESH) rounded to nearest mm
dailyFreeboard = round(predOut.dailyFreeboard,3);

%Calculate the 0/1 n/y if the probability exceeds the 0.05 threshold
floodyn = zeros(n,1);
yflood = find(dailyProb >= 0.05);
floodyn(yflood) = 1;

%Create the table
tableOut = table(stationIDcol,timeVec(:,1),timeVec(:,2),timeVec(:,3),floodyn, floodCategoryCol, dailyProb', minorThresh, dailyFreeboard', HTFrunIDcol,...
    'VariableNames',{'STATION_ID', 'YEAR', 'MONTH', 'DAY', 'FLOOD', 'FLOOD_CATEGORY', 'LIKELIHOOD', 'MINOR_THRESH', 'DIST_TO_THRESH', 'HTB_RUN_ID'});

%Create the filename for saving the csv
startdate = string(dateTime(1),'yyyyMM');
enddate = string(dateTime(end),'yyyyMM');
fileName = strcat(stationNum,'_HTFpred_',startdate,'_',enddate,'.csv');

%Write the file 
writetable(tableOut,fileName);


end



