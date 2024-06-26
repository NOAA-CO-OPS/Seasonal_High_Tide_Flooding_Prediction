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
[~] = HTF_data_pull(stationNumStr, training_startStr, training_endStr)
[~] = movefile([stationNumStr,'_data.mat'],[stationNumStr,'_data_training.mat'])
% Data for testing
[~] = HTF_data_pull(stationNumStr, testing_startStr, testing_endStr)
[~] = movefile([stationNumStr,'_data.mat'],[stationNumStr,'_data_testing.mat'])

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

% Remove entries with the specified year
yearToRemove = training_years(1);
disp(yearToRemove)

% Test list
%x = [datetime(2016,01,01), datetime(2016,01,02), datetime(2017,01,01), datetime(2018,01,01), datetime(2019,01,01)];
%years_x = year(x);
%rowsToKeep = years_x ~= yearToRemove;
%disp(rowsToKeep)

% Extract year from datetime
years = year(data.dateTime);
rowsToKeep = years ~= yearToRemove;

% Remove rows from data based on logical index
training_data = data(rowsToKeep);
%display(training_data);

% Logical indexing to remove data for the specified year
%training_data = training_data(years ~= yearToRemove);

% Save the updated structured array
filename = sprintf('%s_data_training_omit_%s',stationNumStr,num2str(yearToRemove));
save(filename,'training_data');

% Define hold out period
%for i = 1:length(training_years)
%    holdOutStart = datetime(training_years(i), 1, 1);
    %disp(holdOutStart)
%    holdOutEnd = datetime(training_years(i), 12, 31);
    %disp(holdOutEnd)

    % Remove hold out period from training set
%    training_years_subset = setdiff(training_years, training_years(i));
    %disp(training_years_subset)

    % Add hold out period back to training set
%    training_years_subset = [training_years_subset(1:i-1), training_years(i), training_years_subset(i+1:end)];
    %disp(training_years_subset)


% Testing years
testing_startYear = year(datetime(testing_startStr, 'InputFormat', 'yyyyMMdd'));
testing_endYear = year(datetime(testing_endStr, 'InputFormat', 'yyyyMMdd'));

% Create list of testing years
testing_years = testing_startYear:testing_endYear;
%disp(testing_years)



%Run HTF_daily_predictions_all_stations.m to generate parameters and to
%make forecasts.



end