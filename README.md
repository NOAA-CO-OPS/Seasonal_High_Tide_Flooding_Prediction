# Seasonal_High_Tide_Flooding_Prediction

# Overview

This is code for the NOAA Seasonal-to-Annual High Tide Flooding Prediction Model. 

The model predicts the daily likelihood of minor high tide flooding (exceeding the NOAA high tide flooding or HTF threshold) up to year in advance, given a hourly water level and tide prediction time series from a NOAA tide gauge available in the CO-OPS data API. This model is described in detail in the following journal article:

Dusek G, Sweet WV, Widlansky MJ, Thompson PR and Marra JJ (2022) A novel statistical approach to predict seasonal high tide flooding. Front. Mar. Sci. 9:1073792. doi: 10.3389/fmars.2022.1073792

This is open access and available at: https://www.frontiersin.org/articles/10.3389/fmars.2022.1073792/full

# Code Description

The primary code base is in the "main code functions" folder and includes the following functions.

## HTF_daily_predictions_all_stations.m

This function runs all or some of the following functions for 1 to n number of CO-OPS water level stations in an excel station list file (default included in the station list folder). This enables a user to quickly generate HTF predictions from start to finish, based off of any number of years of existing data (ideally 20 continuous years of hourly data). The user can choose to step through each function to save and review the .mat file output before moving to the next step, or just run through all functions at once.  Alternatively, the user can manually call an individual function as long as they have the station ID and several other pieces of information (including the sea level trend, HTF threshold, and center of the last tidal epoch for that particular station).

*Note* that if you want to step through the functions or call them manually, the previous functions *MUST* be run and the .mat file output *MUST* be in an accessible directory, as each function is dependent on previous functions.

## HTF_data_pull.m

This function downloads, preps and saves the necesssary NOAA CO-OPS water level data and predictions to run the High Tide Flooding residual calculations, predictions and skill assessments

## HTF_residual_calc.m

This function takes data from a water level station with SLTs, HTF thresholds and ideally 20 years of hourly data to calculate daily residuals for use in HTF predictions

## HTF_predict.m

This function takes the data and residual output from the code HTF_data_pull.m and HTF_residual_calc.m and calculates forward looking daily predictions out to a maximum of 12 months

## HTF_toCSV.m

This function writes the prediction output for a particular station to a csv file

## HTF_skill.m

This function takes the data and residual output from the code HTF_data_pull.m and HTF_residual_calc.m, calculates 12 month predictions for the historic data set, and performs a skill assessment for a specific station for the duration of the observational data. Note that this function can take an hour or more to run through the entire list of stations (about 98) in the default station list on a standard laptop.

For additional information, contact:
Greg Dusek,
NOAA Center for Operational Oceanographic Products and Services, gregory.dusek@noaa.gov

## NOAA Open Source Disclaimer

This repository is a scientific product and is not official communication of the National Oceanic and Atmospheric Administration, or the United States Department of Commerce. All NOAA GitHub project code is provided on an ?as is? basis and the user assumes responsibility for its use. Any claims against the Department of Commerce or Department of Commerce bureaus stemming from the use of this GitHub project will be governed by all applicable Federal law. Any reference to specific commercial products, processes, or services by service mark, trademark, manufacturer, or otherwise, does not constitute or imply their endorsement, recommendation or favoring by the Department of Commerce. The Department of Commerce seal and logo, or the seal and logo of a DOC bureau, shall not be used in any manner to imply endorsement of any commercial product or activity by DOC or the United States Government.

## License

Software code created by U.S. Government employees is not subject to copyright in the United States (17 U.S.C. �105). The United States/Department of Commerce reserve all rights to seek and obtain copyright protection in countries other than the United States for Software authored in its entirety by the Department of Commerce. To this end, the Department of Commerce hereby grants to Recipient a royalty-free, nonexclusive license to use, copy, and create derivative works of the Software outside of the United States.
