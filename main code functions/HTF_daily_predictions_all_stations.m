function HTF_daily_predictions_all_stations(stationList,startStr,endStr,stationIndex,stationRunID,varargin)

%Function to go through an entire list of stations and run the various
%functions required to make daily seasonal HTF predictions using the HTF
%prediction model.

%Note that right now all files are saved to the present directory

% stationList - is the list of HTF stations to download along with necessary
%   metadata.  For now using:stationList = 'HighTideOutlookStationList_11_17_21.xlsx'

% startStr and endStr - are the dates in format 'yyyymmdd' for when to start
%   and stop downloading the hourly data - these should only be dates at the
%   first and last days of a given month. For example:
%       startStr='20030301'
%       endStr='20230228'

% stationIndex - is the indices in the HTF station list that you want to run
%   the code for. Set stationIndex = [], to run for all stations.

% stationRunID - is the run ID to add to the csv output. This may be
% important if rerunning a particular time period and needing to denote
% that in the database.  I think for now this can just be 1.

% Varargin can be used to specify if the user wants to run through all steps
%   necessary to make new predictions, OR only run a subset of the necessary
%   steps. Inputs can be as follows and should be listed to specify which
%   steps to run

% default - no added arguments = runs through all steps for each station
% 'data' = runs the data function - HTF_data_pull
% 'residual' = runs the residual function - HTF_residual_calc
% 'prediction' = runs the prediction function - HTF_predict
% 'csv'= runs HTF_toCSV and writes the prediction output as a csv for each station
% 'skill' = runs the skill assessment function - HTF_skill

% For example:
%   HTF_daily_predictions_all_stations('HighTideOutlookStationList_11_17_21.xlsx','20030301','20230228',[],'data','residual')
%   Runs through ONLY the data and residual calculation steps


%% Import the information from HTF Station List
listIn=importdata(stationList);

stationNum=listIn.data(:,1); %station number
stationLat=listIn.data(:,3); %station latitude
stationLon=listIn.data(:,4); %station longitude
minorThreshNWS=listIn.data(:,5); %the minor (nuisance) NWS flood threshold
minorThreshDerived=listIn.data(:,6); %the minor derived threshold
slt=listIn.data(:,7);% Most recent SLT in mm/year
epochCenter=listIn.data(:,8); %Center of active epoch period - used for adding in SLR to predictions
stationName=listIn.textdata(2:end,2); %station name
region=listIn.textdata(2:end,9); %station region for the high tide bulletin

%Set the indices of the stations from the station list to run (by default
%all)

n=length(stationNum);

if isempty(stationIndex)
    stationIndex=1:n;
end



%% Check the varargin and determine which function loops to run

%if nothing is in varargin then run all 4 functions, so add them in
if isempty(varargin)
    disp('No function option selected, running all four functions')
    varargin ={'data', 'residual', 'prediction', 'csv', 'skill'};
end


%For the data download
if ~isempty(find(strcmp(varargin, 'data')))
    disp('Running the data download on stations:')

    % Run the data download function, HTF_data_pull for each station
    for i = stationIndex
        stationNumStr=num2str(stationNum(i));
        disp(stationNumStr)
        [~] = HTF_data_pull(stationNumStr,startStr,endStr);
    end

end

%For the residual calculation
if ~isempty(find(strcmp(varargin, 'residual')))
    disp('Running the residual calculation code on stations:')

    % Run the residual calculation function, HTF_residual_calc for each station
    for i = stationIndex
        stationNumStr=num2str(stationNum(i));
        disp(stationNumStr)
        [~] = HTF_residual_calc(stationNumStr,slt(i),epochCenter(i));
    end

end


%For the predictions
if ~isempty(find(strcmp(varargin, 'prediction')))
    disp('Calculating the forward looking predictions for stations:')

    % Run the daily prediction function, HTF_predict for each station
    for i = stationIndex
        stationNumStr=num2str(stationNum(i));
        disp(stationNumStr)
        [~] = HTF_predict(stationNumStr,minorThreshDerived(i),slt(i),epochCenter(i),[],[],[],[]);
    end

end

%For the csv output
if ~isempty(find(strcmp(varargin, 'csv')))
    disp('Writing to csv output for stations:')

    % Run the csv output code for each station
    for i = stationIndex
        stationNumStr=num2str(stationNum(i));
        disp(stationNumStr)
        HTF_toCSV(stationNumStr,stationRunID)
    end

end

%For the skill assessment
if ~isempty(find(strcmp(varargin, 'skill')))
    disp('Calculating the skill assessment over the past 20 years for stations:')

    %Set up the variables we will want to output to a table (all 1 month
    %leads)
    skillful=cell(n,1);
    totalFloods=NaN(n,1);
    bss=NaN(n,1);
    bssSE=NaN(n,1);
    recall=NaN(n,1);
    falseAlarm=NaN(n,1);
    %Over just the last 10 years
    skillful10yr=cell(n,1);
    totalFloods10yr=NaN(n,1);
    bss10yr=NaN(n,1);
    bssSE10yr=NaN(n,1);
    recall10yr=NaN(n,1);
    falseAlarm10yr=NaN(n,1);
    %Over just the last 5 years
    skillful5yr=cell(n,1);
    totalFloods5yr=NaN(n,1);
    bss5yr=NaN(n,1);
    bssSE5yr=NaN(n,1);
    recall5yr=NaN(n,1);
    falseAlarm5yr=NaN(n,1);

    % Run the daily prediction function, HTF_predict for each station and
    % output some skill metrics to a table for quick review
    for i = stationIndex
        stationNumStr=num2str(stationNum(i));
        disp(stationNumStr)
        [skillOut]=HTF_skill(stationNumStr,minorThreshDerived(i),slt(i),epochCenter(i));

        %Populate variables for output
        totalFloods(i)=skillOut.totalYes;
        bss(i)=skillOut.bss(1);
        bssSE(i)=skillOut.bssSE(1);
        recall(i)=skillOut.recall(1);
        falseAlarm(i)=skillOut.falseAlarm(1);
        if bss(i)>=bssSE(i)
            skillful{i}='yes';
        else
            skillful{i}='no';
        end

        %Over just the last 10 years
        totalFloods10yr(i)=skillOut.totalYes10yr;
        bss10yr(i)=skillOut.bss10yr(1);
        bssSE10yr(i)=skillOut.bssSE10yr(1);
        recall10yr(i)=skillOut.recall10yr(1);
        falseAlarm10yr(i)=skillOut.falseAlarm10yr(1);
        if bss10yr(i)>=bssSE10yr(i)
            skillful10yr{i}='yes';
        else
            skillful10yr{i}='no';
        end

        %Over just the last 5 years
        totalFloods5yr(i)=skillOut.totalYes5yr;
        bss5yr(i)=skillOut.bss5yr(1);
        bssSE5yr(i)=skillOut.bssSE5yr(1);
        recall5yr(i)=skillOut.recall5yr(1);
        falseAlarm5yr(i)=skillOut.falseAlarm5yr(1);
        if bss5yr(i)>=bssSE5yr(i)
            skillful5yr{i}='yes';
        else
            skillful5yr{i}='no';
        end

    end

    %Output to table and save
    HTFtable=table(stationNum,stationName,skillful,totalFloods,bss,bssSE,recall,falseAlarm,...
        skillful10yr,totalFloods10yr,bss10yr,bssSE10yr,recall10yr,falseAlarm10yr,...
        skillful5yr,totalFloods5yr,bss5yr,bssSE5yr,recall5yr,falseAlarm5yr);

    save('HTFtable.mat','HTFtable');

    %Create the filename for saving the HTF summary table csv
    tabfileName = strcat('HTF_skillsummary_',startStr,'_',endStr,'.csv');

    %Write the file 
    writetable(HTFtable,tabfileName);

end






end