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

    % copy mat file
    newskill = sprintf('%s_skill_test_omit_%s',stationNumStr,num2str(yearToRemove));
    save(newskill,'-struct','skillOut');





% Need to generate predictions with resOut from each training model
% Need to validate model for test set
% Average the results to get the final score


end