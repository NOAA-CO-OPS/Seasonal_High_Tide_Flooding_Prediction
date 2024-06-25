function HTF_cross_validation(training_startStr, training_endStr, testing_startStr, testing_endStr)

%Function to conduct cross validation of monthly high tide flooding outlook
%model.
%
%Separate data into sets for training and testing the model.

%Parameters
%Training years: e.g. 1997-2019, cross-validate hindcasts for those years
%Testing years: e.g. 2019-present, generate "retrospective forecasts"
%Number of folds for validation: default = 10

%split into years ???

% Get list of years from start and end dates
training_startYear = year(datetime(training_startStr, 'InputFormat', 'yyyyMMdd'));
%disp(startYear)
training_endYear = year(datetime(training_endStr, 'InputFormat', 'yyyyMMdd'));
%disp(endYear)
% Create list of training years
training_years = training_startYear:training_endYear;
disp(training_years);

testing_startYear = year(datetime(testing_startStr, 'InputFormat', 'yyyyMMdd'));
testing_endYear = year(datetime(testing_endStr, 'InputFormat', 'yyyyMMdd'));

% Create list of testing years
testing_years = testing_startYear:testing_endYear;
disp(testing_years)

%Run HTF_daily_predictions_all_stations.m to generate parameters and to
%make forecasts.



end