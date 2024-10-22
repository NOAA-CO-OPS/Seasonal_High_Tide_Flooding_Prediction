function HTF_cross_validation(stationList, training_startStr, training_endStr, ...
    months_or_folds, numMonths_or_numFolds, holdOut, stationIndex)

%Function to conduct cross validation of monthly high tide flooding outlook
%model.
%

%Parameters
%
% stationList - is the list of HTF stations to download along with necessary
%   metadata.  For now using:stationList = 'HighTideOutlookStationList_11_17_21.xlsx'

% training_startStr and training_endStr - are the dates in format 'yyyymmdd' for when to start
%   and stop downloading the hourly data - these should only be dates at the
%   first and last days of a given month. For example:
%       startStr='20030301'
%       endStr='20230228'

% months_or_folds - is a variable that specifies whether to determine the
%    number of folds to split the data into for cross-validation by
%    directly indicating the number of folds ("folds") or by indicating the
%    number of months to include ("months"). 

% numMonths_or_numFolds - is either the number of months to include each group 
%   that the data is split into for cross-validation OR the number of folds
%   or groups that the data is split into. 

% holdOut - is a binary "yes" or "no" which indicates whether each fold
% should be held out of the training dataset and tested. If "no", then all
% of the data will be used to train the model and be part of the test.

% stationIndex - is the indices in the HTF station list that you want to run
%   the code for. Set stationIndex = [], to run for all stations.

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

% Convert date formats from input
%training_startStr = '19961201';
training_startdt = datetime(training_startStr, 'InputFormat', 'yyyyMMdd')-calmonths(1);
%disp(training_startdt)
training_startStr = char(training_startdt, 'yyyyMMdd');
%disp(training_startStr)
training_start_date_time = datetime(year(training_startdt), month(training_startdt),...
    day(training_startdt), 0, 0, 0);
training_startYear = year(training_startdt);
training_enddt = datetime(training_endStr, 'InputFormat', 'yyyyMMdd');
training_end_date_time = datetime(year(training_enddt), month(training_enddt),...
    day(training_enddt), 23, 0, 0);
training_endYear = year(training_enddt);

% Create list of training years
training_years = training_startYear:training_endYear;

% Create datetime array with hourly intervals
training_timeSeries = training_start_date_time:hours(1):training_end_date_time;

%numDays = length(training_timeSeries); 
uniqueMonths = unique(month(training_timeSeries) + year(training_timeSeries)*100);
numMonths = length(uniqueMonths);
%disp(numMonths)

% Option 1: Determine the number of folds from the specified number of months
% in each fold
if months_or_folds == "months"
    foldSize = numMonths_or_numFolds;
    numFolds = floor(numMonths / foldSize);
    %disp(numFolds)

% Option 2: Calculate the number of days and hours in each fold   
elseif months_or_folds == "folds"
    numFolds = numMonths_or_numFolds;
    foldSize = floor(numMonths / numFolds);
    %disp(foldSize)
end    

% Separate the time series into folds without splitting months
folds = cell(1, numFolds);

% % Option 1 - Randomly select unique months to hold out
% if random_or_seq == "random"
%     % Karen - this isn't working and completely random doesn't necessarily
%     % make sense for this assessment. I could specify the months
%     % to always include. However, would non-consecutive data in the hold out set
%     % make sense?
% 
%     % Randomly partition months into k groups
%     cv = cvpartition(numMonths, 'KFold', numFolds);
% 
%     for i = 1:numFolds
%         % Get the training and validation months
%         testIdx = test(cv, i); 
%         trainIdx = training(cv, i);
% 
%         valMonths = uniqueMonths(testIdx);
%         trainMonths = uniqueMonths(trainIdx);
% 
%         foldIndices = ismember(month(training_timeSeries) + year(training_timeSeries)*100, valMonths);
%         folds{i} = training_timeSeries(foldIndices);
%         disp(folds{i})
%     end    
% 
% % Option 2 - Select a sequence unique months to hold out
% elseif random_or_seq == "sequence"
% 
%     currentMonthIdx = 1;
% 
%     for i = 1:numFolds
% 
%         startMonthIdx = currentMonthIdx;
% 
%         if i < numFolds
%             endMonthIdx = startMonthIdx + foldSize - 1;
%         else
%             endMonthIdx = numMonths;
%         end
% 
%         selectedMonths = uniqueMonths(startMonthIdx:endMonthIdx);
% 
%         foldIndices = ismember(month(training_timeSeries) + year(training_timeSeries)*100, selectedMonths);    
% 
%         folds{i} = training_timeSeries(foldIndices);
%         %disp(folds{i})
% 
%         currentMonthIdx = endMonthIdx + 1;        
% 
%     end   
% 
% end

%Select a sequence unique months to hold out
currentMonthIdx = 2;

for i = 1:numFolds

    startMonthIdx = currentMonthIdx;

    if i < numFolds
        endMonthIdx = startMonthIdx + foldSize - 1;
    else
        endMonthIdx = numMonths;
    end
    
    selectedMonths = uniqueMonths(startMonthIdx:endMonthIdx);

    foldIndices = ismember(month(training_timeSeries) + year(training_timeSeries)*100, selectedMonths);    

    folds{i} = training_timeSeries(foldIndices);
    %disp(folds{i})
    
    currentMonthIdx = endMonthIdx + 1; 
end    

% Initialize empty array for output
%output_columnNames = {'StationID','minorThreshDerived','Total Floods', 'skillful'...
%                       'avg_bss', 'avg_bssSE', 'avg_recall', 'avg_false_alarm'};
% Initialize empty array for output
%output_columnNames = {'StationID','minorThreshDerived','Total Floods', 'skillful'...
%                       'bss', 'bssSE', 'recall', 'false_alarm'};
%output_columnNames = {'StationID','minorThreshDerived','Total Floods', 'skillful'...
%                       'bss', 'bssSE', 'recall', 'false_alarm', 'bss_upperQ', 'bssSE_upperQ'...
%                       'recall_upperQ', 'falseAlarm_upperQ'};
output_columnNames = {'StationID','minorThreshDerived','upper quantile', 'Total Floods', 'skillful'...
                       'bss', 'bssSE', 'recall', 'false_alarm', 'rmse', 'bss_upperQ', 'bssSE_upperQ'...
                       'recall_upperQ', 'falseAlarm_upperQ'};
output_cell_array = [];
%output_cell_array = cell(n, length(output_columnNames));
output_cell_array = [output_cell_array, output_columnNames];


% Download data
disp('Running the data download on stations:')

for stn_i = stationIndex
    stationNumStr = num2str(stationNum(stn_i));
    disp(stationNumStr)

    %Create an array to store skill assessment output
    allskillOut = cell(1, length(numFolds));
    
    % Data for training
    %training_data = HTF_data_pull(stationNumStr, training_startStr, training_endStr);
    % Pull data from 1 year before training start date specified to end
    % date specified
    %pre_training_year = datestr(training_startdt - calyears(1), 'yyyymmdd');
    training_data = HTF_data_pull(stationNumStr, training_startStr, training_endStr);
    %training_data = HTF_data_pull(stationNumStr, pre_training_year, training_endStr);
    [~] = movefile([stationNumStr,'_data.mat'],[stationNumStr,'_data_training.mat']);

    %Convert structured array to table
    training_data_table = struct2table(training_data);
    %disp(training_data_table(1,:))

    if holdOut == "yes"
        %Iterate through folds and create training datasets that remove 
        %1 fold at a time
        % Test starting at 2nd fold so that you always have
        % preceding monthly anomaly without retrieving more data than training
        % set and the predictions are always based on preceding data
        for i = 2:numFolds
            testFold = folds{i};
            %disp(testFold)
            trainFolds = folds;
            trainFolds(i) = [];
            training_data_folds = [trainFolds{:}];
            
            % Extract holdout months from datetime
            rowsToKeep = ismember(training_data_table.dateTime, training_data_folds);
            %disp(training_data_table(1,:))
            
            % Remove rows from data based on logical index
            training_data_table_i = training_data_table(rowsToKeep,:);
            %disp(training_data_table_i(1,:))
    
            rowsToHoldout = ismember(training_data_table.dateTime, testFold);
            %disp(rowsToHoldout)
    
            % Create test data from original training dataset
            test_data_table_i = training_data_table(rowsToHoldout,:);
            %disp(test_data_table_i(1,:))
        
            % Convert the training and test tables to a structured array and save as "data"
            data = table2struct(training_data_table_i,"ToScalar",true);
            test_data = table2struct(test_data_table_i,"ToScalar",true);
    
            % Save the updated structured arrays
            filename = sprintf('%s_data_training_omit_%s',stationNumStr,num2str(i));
            save(filename,'data');
    
            test_file = sprintf('%s_data_testing_%s',stationNumStr,num2str(i));
            save(test_file,'test_data');
        
            % RESIDUAL CALC
            % copy mat file to fit HTF_residual_calc
            data = load(filename);
            newdata = sprintf('%s_data.mat',stationNumStr);
            save(newdata, '-struct', 'data')
    
            % Run HTF_residual_calc
            resOut = HTF_residual_calc(stationNumStr, slt(stn_i), epochCenter(stn_i)); 
    
            % copy mat file
            resOut_copy = load(sprintf('%s_res',stationNumStr));
            newres = sprintf('%s_res_training_omit_%s',stationNumStr,num2str(i));
            save(newres,'-struct','resOut_copy');
    
            % RUN MODEL FOR TEST YEARS
            % PREDICTION
            % Run HTF_predict        
            testing_startDate = testFold(1);
            testing_startMonth = datestr(testing_startDate, 'yyyymm');
            %disp(testing_startMonth)
    
            testing_endDate = testFold(end);
            testing_endMonth = datestr(testing_endDate, 'yyyymm');
    
            %predOut = HTF_predict(stationNumStr,minorThreshDerived(stn_i),slt(stn_i),epochCenter(stn_i),...
            %              testing_startMonth,testing_endMonth,resOut,test_data); 

            % copy mat file
            %newpred = sprintf('%s_pred_test_omit_%s',stationNumStr,num2str(i));
            %save(newpred,'-struct','predOut');
    
            % SKILL ASSESSMENT
            % Run HTF_cross_valid_skill
            disp('Calculating skill...')
            skillOut = HTF_cross_valid_skill(stationNumStr,minorThreshDerived(stn_i),slt(stn_i),epochCenter(stn_i),...
                                         testing_startDate, testing_endDate,...
                                         test_data,resOut);
        
            allskillOut{i} = skillOut;
            %disp(allskillOut{i})
    
            % copy mat file
            newskill = sprintf('%s_skill_test_omit_%s',stationNumStr,num2str(i));
            save(newskill,'-struct','skillOut');
        end

        % Calculate the results for all training iterations 
        % All observations of threshold being exceeded - get 1 month lead
        % time values
        validEntries_ynObs = cellfun(@(s) isstruct(s) && isfield(s, 'ynObs'), allskillOut);
        ynObs_all_fields = cellfun(@(s) s.ynObs, allskillOut(validEntries_ynObs), 'UniformOutput', false);
        ynObs_all_data = vertcat(ynObs_all_fields{:});
        %disp(ynObs_all_data)
    
        % All daily prob - get 1 month lead time values
        validEntries_dailyProb = cellfun(@(s) isstruct(s) && isfield(s, 'dailyProb'), allskillOut);
        dailyProb_all_fields = cellfun(@(s) flip(s.dailyProb(1, :))', allskillOut(validEntries_dailyProb), "UniformOutput", false);
        dailyProb_all_data = vertcat(dailyProb_all_fields{:});
        dailyProb_all = struct('dailyProb', dailyProb_all_data);

        % Brier skill score for all for 1 month lead time      
        [bs_all, bss_all, bsSE_all, bssSE_all] = BrierScore(ynObs_all_data, dailyProb_all_data);
        %disp(bs_all)
    
        % Sum total floods
        validEntries_floods = cellfun(@(s) isstruct(s) && isfield(s, 'totalYes'), allskillOut);
        floods_all_fields = cellfun(@(s) s.totalYes, allskillOut(validEntries_floods), "UniformOutput", false);
        floods_all_data = vertcat(floods_all_fields{:});
        total_Floods_all = sum(floods_all_data);
        %disp(total_Floods)
    
        %Confusion matrix and stats for the 5% warning threshold
        confusion05_all = confusionStats(ynObs_all_data, dailyProb_all_data, 0.05);
        recall_all = confusion05_all.recall;
        falseAlarm_all = confusion05_all.falseAlarm; 

        % Calculate Root Mean Square Error
        valid_idx = ~isnan(dailyProb_all_data) & ~isnan(ynObs_all_data);
        rmse_all = sqrt(mean((dailyProb_all_data(valid_idx) - ynObs_all_data(valid_idx)).^2));

        % Brier skill score for upper quantile of observations
        % All daily obs
        validEntries_dailyObs = cellfun(@(s) isstruct(s) && isfield(s, 'dailyObs'), allskillOut);
        dailyObs_all_data = cellfun(@(s) s.dailyObs, allskillOut(validEntries_dailyObs), "UniformOutput", false);
        dailyObs_all_data = vertcat(dailyObs_all_data{:});
        upperQuantileThreshold = quantile(dailyObs_all_data, 0.8);
        %disp(upperQuantileThreshold)
        observedUpperQuantile = dailyObs_all_data >= upperQuantileThreshold;
        %disp(observedUpperQuantile)
        [bs_upperQ, bss_upperQ, bsSe_upperQ, bssSE_upperQ] = BrierScore(observedUpperQuantile, dailyProb_all_data);

        %Confusion matrix and stats for the upper quantile
        observedUpperQuantile = double(observedUpperQuantile);
        confusion05_upperQ = confusionStats(observedUpperQuantile, dailyProb_all_data, 0.05);
        recall_upperQ = confusion05_upperQ.recall;
        falseAlarm_upperQ = confusion05_upperQ.falseAlarm;

        if bss_all >= bssSE_all
            skillful_all = 'yes';
        else
            skillful_all = 'no';
        end    

        output_data = {stationNumStr, minorThreshDerived(stn_i), upperQuantileThreshold, total_Floods_all, skillful_all,... 
                       bss_all, bssSE_all, recall_all, falseAlarm_all, rmse_all, bss_upperQ, bssSE_upperQ...
                       recall_upperQ, falseAlarm_upperQ};
        disp(output_data)
    
    elseif holdOut == "no"        
        % Pull data for dates specified
        training_data = HTF_data_pull(stationNumStr, training_startStr, training_endStr);
        %training_data = HTF_data_pull(stationNumStr, '19961201', training_endStr);        
        [~] = movefile([stationNumStr,'_data.mat'],[stationNumStr,'_data_training.mat']);
    
        %Convert structured array to table
        training_data_table = struct2table(training_data);        

        % Convert the training table to a structured array and save as "data"
        data = table2struct(training_data_table,"ToScalar",true);
        
        % RESIDUAL CALC
        % Run HTF_residual_calc
        
        % copy mat file to fit HTF_residual_calc
        filename = sprintf('%s_data_training',stationNumStr);
        save(filename,'data');

        data = load(filename);
        newdata = sprintf('%s_data.mat',stationNumStr);
        save(newdata, '-struct', 'data')
        
        resOut = HTF_residual_calc(stationNumStr, slt(stn_i), epochCenter(stn_i));    

        % Run prediction model
        training_start_dt = datetime(training_startStr, 'InputFormat', 'yyyyMMdd');
        training_startMonth = datestr(training_start_dt, 'yyyymm');
        
        training_end_dt = datetime(training_endStr, 'InputFormat', 'yyyyMMdd');
        training_endMonth = datestr(training_end_dt, 'yyyymm');

        predOut = HTF_predict(stationNumStr,minorThreshDerived(stn_i),slt(stn_i),epochCenter(stn_i),...
                           resOut.yrMoTime(2),training_endMonth,resOut,data.data);  

        % copy mat file
        newpred = sprintf('%s_pred',stationNumStr);
        save(newpred,'-struct','predOut');

        % SKILL ASSESSMENT
        % get data that corresponds with predictions
        timeInd = find(data.data.dateTime >= predOut.dateTime(1) & data.data.dateTime <= predOut.dateTime(end));

        filteredData.dateTime = data.data.dateTime(timeInd);
        filteredData.wl = data.data.wl(timeInd);

        % Run HTF_cross_valid_skill
        skillOut = HTF_cross_valid_skill(stationNumStr,minorThreshDerived(stn_i),slt(stn_i),epochCenter(stn_i),...
                                         training_start_dt, training_end_dt,...
                                         filteredData,resOut,predOut);
    
        % Sum total floods
        total_Floods = skillOut.totalYes;
        %disp(total_Floods)
    
        % Brier skill score
        bss = skillOut.bss;
        bssSE = skillOut.bssSE;

        %Confusion matrix and stats for the 5% warning threshold
        recall = skillOut.recall;
        falseAlarm = skillOut.falseAlarm;

        % Calculate Root Mean Square Error
        valid_idx = ~isnan(skillOut.dailyProb) & ~isnan(skillOut.ynObs);
        rmse = sqrt(mean((skillOut.dailyProb(valid_idx) - skillOut.ynObs(valid_idx)).^2));        

        % Brier skill score for upper quantile of observations
        % Daily obs
        upperQuantileThreshold = quantile(skillOut.dailyObs, 0.8);
        %disp(upperQuantileThreshold)
        observedUpperQuantile = skillOut.dailyObs >= upperQuantileThreshold;
        %disp(observedUpperQuantile)
        [bs_upperQ, bss_upperQ, bsSe_upperQ, bssSE_upperQ] = BrierScore(observedUpperQuantile, skillOut.dailyProb);

        %Confusion matrix and stats for the upper quantile
        observedUpperQuantile = double(observedUpperQuantile);
        confusion05_upperQ = confusionStats(observedUpperQuantile, skillOut.dailyProb, 0.05);
        recall_upperQ = confusion05_upperQ.recall;
        falseAlarm_upperQ = confusion05_upperQ.falseAlarm;
        
        if bss >= bssSE
            skillful = 'yes';
        else
            skillful = 'no';
        end    
        %disp(skillful);
    
        %Define data to output to table 
        %output_data = {stationNumStr, minorThreshDerived(stn_i), total_Floods,skillful,bss,...
        %               bssSE, recall, falseAlarm};  
        %output_data = {stationNumStr, minorThreshDerived(stn_i), total_Floods,skillful,bss,...
        %               bssSE, recall, falseAlarm, bss_upperQ, bssSE_upperQ...
        %               recall_upperQ, falseAlarm_upperQ};
        output_data = {stationNumStr, minorThreshDerived(stn_i), upperQuantileThreshold, total_Floods,skillful,...
                       bss, bssSE, recall, falseAlarm, rmse, bss_upperQ, bssSE_upperQ...
                       recall_upperQ, falseAlarm_upperQ};
        disp(output_data)

    end
    
    output_cell_array = [output_cell_array; output_data];
    

%Output table w/ skill scores

%Create the filename for saving the HTF summary table csv
tabfileName = strcat('HTF_crossvalid_skillsummary',training_startStr,'_',training_endStr,'.csv');

%Write the file
writecell(output_cell_array,tabfileName);

end