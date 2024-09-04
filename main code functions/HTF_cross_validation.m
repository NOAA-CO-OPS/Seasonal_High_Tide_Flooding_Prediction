function HTF_cross_validation(stationList, training_startStr, training_endStr, ...
    stationIndex)

%Function to conduct cross validation of monthly high tide flooding outlook
%model.
%
%Separate data into sets for training and testing the model.

%Parameters
%Training years: e.g. 1997-2019, cross-validate hindcasts for those years
%Testing years: e.g. 2020-present, generate "retrospective forecasts"

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

% Get list of years from training start and end dates
training_startdt = datetime(training_startStr, 'InputFormat', 'yyyyMMdd');
training_startYear = year(training_startdt);
training_endYear = year(datetime(training_endStr, 'InputFormat', 'yyyyMMdd'));

% Create list of training years
training_years = training_startYear:training_endYear;

% Testing date range
%testing_startDate = datetime(testing_startStr, 'InputFormat', 'yyyyMMdd');
%testing_endDate = datetime(testing_endStr, 'InputFormat', 'yyyyMMdd');
%testing_startMonth = datestr(testing_startDate, 'yyyymm');
%testing_endMonth = datestr(testing_endDate, 'yyyymm');


% Initialize empty array for output
%output_columnNames = {'StationID','minorThreshDerived','Total Floods', 'skillful'...
%                       'avg_bss', 'avg_bssSE', 'avg_recall', 'avg_false_alarm'};
% Initialize empty array for output
output_columnNames = {'StationID','minorThreshDerived','Total Floods', 'skillful'...
                       'bss', 'bssSE', 'recall', 'false_alarm'};
output_cell_array = [];
%output_cell_array = cell(n, length(output_columnNames));
output_cell_array = [output_cell_array, output_columnNames];


% Download data
disp('Running the data download on stations:')

for stn_i = stationIndex
    stationNumStr = num2str(stationNum(stn_i));
    disp(stationNumStr)
    
    % Data for training
    %training_data = HTF_data_pull(stationNumStr, training_startStr, training_endStr);
    % Pull data from 1 year before training start date specified to end
    % date specified
    pre_training_year = datestr(training_startdt - calyears(1), 'yyyymmdd');
    disp(pre_training_year)
    training_data = HTF_data_pull(stationNumStr, pre_training_year, training_endStr);
    [~] = movefile([stationNumStr,'_data.mat'],[stationNumStr,'_data_training.mat']);

    % Data for testing
    %test_data = HTF_data_pull(stationNumStr, testing_startStr, testing_endStr);
    %[~] = movefile([stationNumStr,'_data.mat'],[stationNumStr,'_data_testing.mat']);


    %Convert structured array to table
    training_data_table = struct2table(training_data);

    %Create an array to store skill assessment output
    allskillOut = cell(1, length(training_years));

    %Iterate through training years and create training datasets that remove 
    %1 year at a time
    for i = 1:length(training_years)
        % Remove entries with the specified year
        yearToHoldout = training_years(i);
        disp(yearToHoldout)

        % Extract year from datetime
        years = year(training_data_table.dateTime); %from data table
        rowsToKeep = years ~= yearToHoldout;

        % Remove rows from data based on logical index
        training_data_table_i = training_data_table(rowsToKeep,:);

        % Create test data from original training dataset
        rowsToHoldout = years == yearToHoldout;
        test_data_table_i = training_data_table(rowsToHoldout,:);
        %disp(test_data_table_i)
    
        % Convert the training and test tables to a structured array and save as "data"
        data = table2struct(training_data_table_i,"ToScalar",true);
        test_data = table2struct(test_data_table_i,"ToScalar",true);

        % Save the updated structured arrays
        filename = sprintf('%s_data_training_omit_%s',stationNumStr,num2str(yearToHoldout));
        save(filename,'data');

        test_file = sprintf('%s_data_testing_%s',stationNumStr,num2str(yearToHoldout));
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
        newres = sprintf('%s_res_training_omit_%s',stationNumStr,num2str(yearToHoldout));
        save(newres,'-struct','resOut_copy');

        % RUN MODEL FOR TEST YEARS
        % PREDICTION
        % Run HTF_predict
        testing_startyear = yearToHoldout;
        testing_startMonth_input = 1;
        testing_startDay_input = 1;
        testing_startDate = datetime(testing_startyear, testing_startMonth_input, testing_startDay_input);
        testing_startMonth = datestr(testing_startDate, 'yyyymm');

        testing_endyear = yearToHoldout;
        testing_endMonth_input = 12;
        testing_endDay_input = 31;
        testing_endDate = datetime(testing_endyear, testing_endMonth_input, testing_endDay_input);
        testing_endMonth = datestr(testing_endDate, 'yyyymm');

        predOut = HTF_predict(stationNumStr,minorThreshDerived(stn_i),slt(stn_i),epochCenter(stn_i),...
                      testing_startMonth,testing_endMonth,resOut,test_data); 

        %predOut_all(i) = predOut % Karen - 8/28/2024
        %disp(predOut_all)

        % copy mat file
        newpred = sprintf('%s_pred_test_omit_%s',stationNumStr,num2str(yearToHoldout));
        save(newpred,'-struct','predOut');

        % SKILL ASSESSMENT
        % Run HTF_cross_valid_skill
        skillOut = HTF_cross_valid_skill(stationNumStr,minorThreshDerived(stn_i),slt(stn_i),epochCenter(stn_i),...
                                     testing_startDate, testing_endDate,...
                                     test_data,resOut,predOut);
    
        allskillOut{i} = skillOut;
        %allskillOut{stn_i} = skillOut;

        % copy mat file
        newskill = sprintf('%s_skill_test_omit_%s',stationNumStr,num2str(yearToHoldout));
        save(newskill,'-struct','skillOut');
        
    % KAREN - 8/20 - Concatenate observations and predictions for
    % all model runs ???
        

    end

    % Calculate the results for all training iterations 
    % All observations of threshold being exceeded
    ynObs_all_fields = cellfun(@(s) s.ynObs, allskillOut, "UniformOutput", false);
    ynObs_all_data = vertcat(ynObs_all_fields{:});

    % All daily prob
    dailyProb_all_fields = cellfun(@(s) s.dailyProb, allskillOut, "UniformOutput", false);
    dailyProb_all_data = vertcat(dailyProb_all_fields{:});
    dailyProb_all = struct('dailyProb', dailyProb_all_data);

    % Brier skill score for all
    [bs_all, bss_all, bsSE_all, bssSE_all] = BrierScore(ynObs_all_data, dailyProb_all_data);
    %disp(bs)

    % Sum total floods
    floods_all_fields = cellfun(@(s) s.totalYes, allskillOut, "UniformOutput", false);
    floods_all_data = vertcat(floods_all_fields{:});
    total_Floods_all = sum(floods_all_data);
    %disp(total_Floods)

    %Confusion matrix and stats for the 5% warning threshold
    confusion05_all = confusionStats(ynObs_all_data, dailyProb_all_data,0.05);
    recall_all = confusion05_all.recall;
    falseAlarm_all = confusion05_all.falseAlarm;

    % Average the results to get the final score
    %totalFloodsValues = cellfun(@(s) s.totalYes, allskillOut); 
    %total_Floods = mean(totalFloodsValues);
    %disp(total_Floods);

    %bssValues = cellfun(@(s) s.bss, allskillOut); 
    %mean_bss = mean(bssValues);
    %disp(mean_bss);

    %bssSEValues = cellfun(@(s) s.bssSE, allskillOut);
    %mean_bssSE = mean(bssSEValues);
    %disp(mean_bssSE);

    %recallValues = cellfun(@(s) s.recall, allskillOut);
    %mean_recall = mean(recallValues);
    %disp(mean_recall);

    %falseAlarmValues = cellfun(@(s) s.falseAlarm, allskillOut);
    %mean_falseAlarm = mean(falseAlarmValues);
    %disp(mean_falseAlarm);

    %if mean_bss >= mean_bssSE
    %    skillful = 'yes';
    %else
    %    skillful = 'no';
    %end    
    %disp(skillful);
    
    if bss_all >= bssSE_all
        skillful_all = 'yes';
    else
        skillful_all = 'no';
    end    
    %disp(skillful);

    %Define data to output to table
    %output_data = {stationNumStr, minorThreshDerived(stn_i), total_Floods,skillful,mean_bss,...
    %                   mean_bssSE, mean_recall, mean_falseAlarm};
    %disp(output_data)
    
    output_data = {stationNumStr, minorThreshDerived(stn_i), total_Floods_all,skillful_all,bss_all,...
                       bssSE_all, recall_all, falseAlarm_all};
    disp(output_data)

    output_cell_array = [output_cell_array; output_data];
    

%Output table w/ skill scores

%Create the filename for saving the HTF summary table csv
tabfileName = strcat('HTF_crossvalid_skillsummary',training_startStr,'_',training_endStr,'.csv');

%Write the file
writecell(output_cell_array,tabfileName);

end