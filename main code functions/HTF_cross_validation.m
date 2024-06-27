function HTF_cross_validation(stationNum, training_startStr, training_endStr, testing_startStr, testing_endStr)

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
[~] = HTF_data_pull(stationNumStr, testing_startStr, testing_endStr);
[~] = movefile([stationNumStr,'_data.mat'],[stationNumStr,'_data_testing.mat']);

% Get list of years from training start and end dates
training_startYear = year(datetime(training_startStr, 'InputFormat', 'yyyyMMdd'));
%disp(startYear)
training_endYear = year(datetime(training_endStr, 'InputFormat', 'yyyyMMdd'));
%disp(endYear)
% Create list of training years
training_years = training_startYear:training_endYear;
%disp(training_years);

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
    [~] = HTF_residual_calc(stationNumStr, 1.96, 1992.50); %hard coded for now

    % copy mat file
    resOut = load(sprintf('%s_res',stationNumStr));
    newres = sprintf('%s_res_training_omit_%s',stationNumStr,num2str(yearToRemove));
    save(newres,'-struct','resOut');

    % PREDICTION
    data = load(sprintf('%s_data',stationNumStr));
    % Run HTF_predict
    [~] = HTF_predict(stationNumStr,0.304,1.96,1992.50,[],[],[],[]);

    % copy mat file
    predOut = load(sprintf('%s_pred',stationNumStr));
    newpred = sprintf('%s_pred_training_omit_%s',stationNumStr,num2str(yearToRemove));
    save(newpred,'-struct','predOut');





% Testing years
testing_startYear = year(datetime(testing_startStr, 'InputFormat', 'yyyyMMdd'));
testing_endYear = year(datetime(testing_endStr, 'InputFormat', 'yyyyMMdd'));

% Create list of testing years
testing_years = testing_startYear:testing_endYear;
%disp(testing_years)



%Run HTF_daily_predictions_all_stations.m to generate parameters and to
%make forecasts.



end