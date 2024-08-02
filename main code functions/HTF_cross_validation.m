function HTF_cross_validation(stationNum, training_startStr, training_endStr, ...
    testing_startStr, testing_endStr, minorThresh, slt, epochCenter)

%Function to conduct cross validation of monthly high tide flooding outlook
%model.
%
%Separate data into sets for training and testing the model.

%Parameters
%Training years: e.g. 1997-2019, cross-validate hindcasts for those years
%Testing years: e.g. 2019-present, generate "retrospective forecasts"
%Number of folds for validation: default = 10

% Passed 1 station number for testing, but would revise to pass station
% list as in HTF_daily_predictions_all_stations.m
stationNumStr = num2str(stationNum);

% Download data
disp('Running the data download on stations:')
% Data for training
[~] = HTF_data_pull(stationNumStr, training_startStr, training_endStr);
[~] = movefile([stationNumStr,'_data.mat'],[stationNumStr,'_data_training.mat']);
% Data for testing
test_data = HTF_data_pull(stationNumStr, testing_startStr, testing_endStr);
[~] = movefile([stationNumStr,'_data.mat'],[stationNumStr,'_data_testing.mat']);

% Get list of years from training start and end dates
training_startYear = year(datetime(training_startStr, 'InputFormat', 'yyyyMMdd'));
%disp(startYear)
training_endYear = year(datetime(training_endStr, 'InputFormat', 'yyyyMMdd'));
%disp(endYear)
% Create list of training years
training_years = training_startYear:training_endYear;
%disp(training_years);

% Testing date range
%testing_startYear = year(datetime(testing_startStr, 'InputFormat', 'yyyyMMdd'));
%testing_endYear = year(datetime(testing_endStr, 'InputFormat', 'yyyyMMdd'));
testing_startDate = datetime(testing_startStr, 'InputFormat', 'yyyyMMdd');
testing_endDate = datetime(testing_endStr, 'InputFormat', 'yyyyMMdd');
testing_startMonth = datestr(testing_startDate, 'yyyymm');
testing_endMonth = datestr(testing_endDate, 'yyyymm');


%Load the data from the mat file
load([stationNum,'_data_training']);

%Convert structured array to table
training_data_table = struct2table(data);
%disp(size(training_data_table))

%Create an array to store skill assessment output
allskillOut = cell(1, length(training_years));

%Iterate through training years and create training datasets that remove 
%1 year at a time
for i = 1:length(training_years)
    % Remove entries with the specified year
    yearToRemove = training_years(i);
    disp(yearToRemove)

    % Extract year from datetime
    years = year(training_data_table.dateTime); %from data table
    rowsToKeep = years ~= yearToRemove;
    %disp(size(rowsToKeep))

    % Remove rows from data based on logical index
    training_data_table_i = training_data_table(rowsToKeep,:);
    %display(training_data);
    
    % Convert the table to a structured array and save as "data"
    data = table2struct(training_data_table_i,"ToScalar",true);

    % Save the updated structured array
    filename = sprintf('%s_data_training_omit_%s',stationNumStr,num2str(yearToRemove));
    save(filename,'data');
    
    % RESIDUAL CALC
    % copy mat file to fit HTF_residual_calc
    data = load(filename);
    newdata = sprintf('%s_data.mat',stationNumStr);
    save(newdata, '-struct', 'data')

    % Run HTF_residual_calc
    resOut = HTF_residual_calc(stationNumStr, slt, epochCenter); 

    % copy mat file
    resOut_copy = load(sprintf('%s_res',stationNumStr));
    newres = sprintf('%s_res_training_omit_%s',stationNumStr,num2str(yearToRemove));
    save(newres,'-struct','resOut_copy');

    % PREDICTION % Do we need to generate predictions for each training
    % set? I think the predictions are just needed for validation of the test set. 
    %data = load(sprintf('%s_data',stationNumStr));
    % Run HTF_predict
    %[~] = HTF_predict(stationNumStr,minorThresh,slt,epochCenter,[],[],[],[]); %do you need to pass resOut?

    % copy mat file
    %predOut = load(sprintf('%s_pred',stationNumStr));
    %newpred = sprintf('%s_pred_training_omit_%s',stationNumStr,num2str(yearToRemove));
    %save(newpred,'-struct','predOut');

    % VALIDATE MODEL FOR TEST YEARS
    % PREDICTION
    % Run HTF_predict
    predOut = HTF_predict(stationNumStr,minorThresh,slt,epochCenter,...
                      testing_startMonth,testing_endMonth,resOut,test_data); 

    % copy mat file
    newpred = sprintf('%s_pred_test_omit_%s',stationNumStr,num2str(yearToRemove));
    %newpred = sprintf('%s_pred_training_omit_%s',stationNumStr,num2str(yearToRemove));
    save(newpred,'-struct','predOut');

    % SKILL ASSESSMENT
    % Run HTF_cross_valid_skill
    skillOut = HTF_cross_valid_skill(stationNumStr,minorThresh,slt,epochCenter,...
                                     testing_startDate, testing_endDate,...
                                     test_data,resOut,predOut);
    
    allskillOut{i} = skillOut;

    % copy mat file
    newskill = sprintf('%s_skill_test_omit_%s',stationNumStr,num2str(yearToRemove));
    save(newskill,'-struct','skillOut');

end


%Set up the variables for the output table
%minorThresh = NaN(1,1); %Karen - replace first 1 with n once using multiple stations. n is "n=length(stationNum);"
%skillful = cell(1,1);
%total_Floods = NaN(1,1);
%mean_bss = NaN(1,1);
%mean_bssSE = NaN(1,1);
%mean_recall = NaN(1,1);
%mean_falseAlarm = NaN(1,1);

% Average the results to get the final score
totalFloodsValues = cellfun(@(s) s.totalYes, allskillOut); 
total_Floods = mean(totalFloodsValues);
disp(total_Floods);

bssValues = cellfun(@(s) s.bss, allskillOut); 
mean_bss = mean(bssValues);
disp(mean_bss);

bssSEValues = cellfun(@(s) s.bssSE, allskillOut);
mean_bssSE = mean(bssSEValues);
disp(mean_bssSE);

recallValues = cellfun(@(s) s.recall, allskillOut);
mean_recall = mean(recallValues);
disp(mean_recall);

falseAlarmValues = cellfun(@(s) s.falseAlarm, allskillOut);
mean_falseAlarm = mean(falseAlarmValues);
disp(mean_falseAlarm);

if mean_bss >= mean_bssSE
    skillful = 'yes';
else
    skillful = 'no';
end    
disp(skillful);

%Define data to output to table
output_data = {stationNumStr, minorThresh, total_Floods,skillful,mean_bss,...
    mean_bssSE, mean_recall, mean_falseAlarm};
output_columnNames = {'StationID','minorThresh','Total Floods', 'skillful'...
    'avg_bss', 'avg_bssSE', 'avg_recall', 'avg_false_alarm'};
output_cell_array = [output_columnNames; output_data];

%Output table w/ average skill scores
%HTFtable = table(stationNumStr,minorThresh,total_Floods,skillful,mean_bss,...
%    mean_bssSE, mean_recall, mean_falseAlarm);
%save('HTFtable.mat','HTFtable');

%Create the filename for saving the HTF summary table csv
tabfileName = strcat('HTF_crossvalid_skillsummary',testing_startStr,'_',testing_endStr,'.csv');
%Write the file
%writetable(HTFtable,tabfileName);
writecell(output_cell_array,tabfileName);

end