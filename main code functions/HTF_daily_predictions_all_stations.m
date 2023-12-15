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
        if (stationNum(i) >= 9450000) && (stationNum(i) < 9470000)
            [~] = HTF_predict(stationNumStr,minorThreshDerived(i),slt(i),epochCenter(i),[],[],[],[]);
        else
            minorThreshDerived = getThresholddata(stationNumStr,'MHHW');
        %[~] = HTF_predict(stationNumStr,minorThreshDerived(i),slt(i),epochCenter(i),[],[],[],[]);
            [~] = HTF_predict(stationNumStr,minorThreshDerived,slt(i),epochCenter(i),[],[],[],[]);
        end    
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

    % Merge csvs into one table
    output_file = 'HTF_pred.csv';
    file_info = dir(fullfile('.','*.csv'));
    full_file_names = fullfile('.',{file_info.name});
    n_files = numel(file_info);
    all_data = cell(1,n_files);
    for ii = 1:n_files
        all_data{ii} = readtable(full_file_names{ii});
    end    
    
    % concatenate all the tables inot one big table and write it to output
    % file
    %writetable(cat(1,all_data{:}),output_file);
    writetable(cat(1,all_data{:}),output_file,'Delimiter', ',');

    % concatenate all the tables into one table without nans
    if true
        %writetable(all_data{ii},output_file,'Delimiter', ',');
        fid = fopen(output_file,'rt');
        X = fread(fid);
        fclose(fid);
        X = char(X.');
        % replace string S1 with string S2
        Y = strrep(X, 'NaN', '');
        fid2 = fopen(output_file,'wt');
        fwrite(fid2,Y);
        fclose(fid2);
    end    

end

%For the skill assessment

if ~isempty(find(strcmp(varargin, 'skill')))
    disp('Calculating the skill assessment over the past 20 years for stations:')

    %Set up the variables we will want to output to a table (all 1 month
    %leads)
    minorThresh=NaN(n,1);
    skillful_1mo=cell(n,1);
    totalFloods=NaN(n,1);
    bss_1mo=NaN(n,1);
    bssSE_1mo=NaN(n,1);
    recall_1mo=NaN(n,1);
    falseAlarm_1mo=NaN(n,1);
    % 2 month leads
    skillful_2mo=cell(n,1);
    bss_2mo=NaN(n,1);
    bssSE_2mo=NaN(n,1);
    recall_2mo=NaN(n,1);
    falseAlarm_2mo=NaN(n,1);
    % 3 month leads
    skillful_3mo=cell(n,1);
    bss_3mo=NaN(n,1);
    bssSE_3mo=NaN(n,1);
    recall_3mo=NaN(n,1);
    falseAlarm_3mo=NaN(n,1);
    % 4 month leads
    skillful_4mo=cell(n,1);
    bss_4mo=NaN(n,1);
    bssSE_4mo=NaN(n,1);
    recall_4mo=NaN(n,1);
    falseAlarm_4mo=NaN(n,1); 
    % 5 month leads
    skillful_5mo=cell(n,1);
    bss_5mo=NaN(n,1);
    bssSE_5mo=NaN(n,1);
    recall_5mo=NaN(n,1);
    falseAlarm_5mo=NaN(n,1);
    % 6 month leads
    skillful_6mo=cell(n,1);
    bss_6mo=NaN(n,1);
    bssSE_6mo=NaN(n,1);
    recall_6mo=NaN(n,1);
    falseAlarm_6mo=NaN(n,1); 
    % 7 month leads
    skillful_7mo=cell(n,1);
    bss_7mo=NaN(n,1);
    bssSE_7mo=NaN(n,1);
    recall_7mo=NaN(n,1);
    falseAlarm_7mo=NaN(n,1); 
    % 8 month leads
    skillful_8mo=cell(n,1);
    bss_8mo=NaN(n,1);
    bssSE_8mo=NaN(n,1);
    recall_8mo=NaN(n,1);
    falseAlarm_8mo=NaN(n,1); 
    % 9 month leads
    skillful_9mo=cell(n,1);
    bss_9mo=NaN(n,1);
    bssSE_9mo=NaN(n,1);
    recall_9mo=NaN(n,1);
    falseAlarm_9mo=NaN(n,1); 
    % 10 month leads
    skillful_10mo=cell(n,1);
    bss_10mo=NaN(n,1);
    bssSE_10mo=NaN(n,1);
    recall_10mo=NaN(n,1);
    falseAlarm_10mo=NaN(n,1);
    % 11 month leads
    skillful_11mo=cell(n,1);
    bss_11mo=NaN(n,1);
    bssSE_11mo=NaN(n,1);
    recall_11mo=NaN(n,1);
    falseAlarm_11mo=NaN(n,1);  
    % 12 month leads
    skillful_12mo=cell(n,1);
    bss_12mo=NaN(n,1);
    bssSE_12mo=NaN(n,1);
    recall_12mo=NaN(n,1);
    falseAlarm_12mo=NaN(n,1);      
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
        if (stationNum(i) >= 9450000) && (stationNum(i) < 9470000)
            [skillOut]=HTF_skill(stationNumStr,minorThreshDerived(i),slt(i),epochCenter(i));
        else    
            minorThreshDerived = getThresholddata(stationNumStr,'MHHW');
        %[skillOut]=HTF_skill(stationNumStr,minorThreshDerived(i),slt(i),epochCenter(i));
            [skillOut]=HTF_skill(stationNumStr,minorThreshDerived,slt(i),epochCenter(i));
        end
        %Populate variables for output
        minorThresh(i)=skillOut.minorThresh;
        %For 1 mo lead time
        totalFloods(i)=skillOut.totalYes;
        bss_1mo(i)=skillOut.bss(1);
        bssSE_1mo(i)=skillOut.bssSE(1);
        recall_1mo(i)=skillOut.recall(1);
        falseAlarm_1mo(i)=skillOut.falseAlarm(1);
        if bss_1mo(i)>=bssSE_1mo(i)
            skillful_1mo{i}='yes';
        else
            skillful_1mo{i}='no';
        end

        %For 2 months lead time
        bss_2mo(i)=skillOut.bss(2);
        bssSE_2mo(i)=skillOut.bssSE(2);
        recall_2mo(i)=skillOut.recall(2);
        falseAlarm_2mo(i)=skillOut.falseAlarm(2);
        if bss_2mo(i)>=bssSE_2mo(i)
            skillful_2mo{i}='yes';
        elseif bss_2mo(i)<bssSE_2mo(i)
            skillful_2mo{i}='no';
        else
            skillful_2mo{i}='NaN';
        end

        %For 3 months lead time
        bss_3mo(i)=skillOut.bss(3);
        bssSE_3mo(i)=skillOut.bssSE(3);
        recall_3mo(i)=skillOut.recall(3);
        falseAlarm_3mo(i)=skillOut.falseAlarm(3);
        if bss_3mo(i)>=bssSE_3mo(i)
            skillful_3mo{i}='yes';
        elseif bss_3mo(i)<bssSE_3mo(i)
            skillful_3mo{i}='no';
        else
            skillful_3mo{i}='NaN';
        end

        %For 4 months lead time
        bss_4mo(i)=skillOut.bss(4);
        bssSE_4mo(i)=skillOut.bssSE(4);
        recall_4mo(i)=skillOut.recall(4);
        falseAlarm_4mo(i)=skillOut.falseAlarm(4);
        if bss_4mo(i)>=bssSE_4mo(i)
            skillful_4mo{i}='yes';
        elseif bss_4mo(i)<bssSE_4mo(i)
            skillful_4mo{i}='no';
        else
            skillful_4mo{i}='NaN';
        end  

        %For 5 months lead time
        bss_5mo(i)=skillOut.bss(5);
        bssSE_5mo(i)=skillOut.bssSE(5);
        recall_5mo(i)=skillOut.recall(5);
        falseAlarm_5mo(i)=skillOut.falseAlarm(5);
        if bss_5mo(i)>=bssSE_5mo(i)
            skillful_5mo{i}='yes';
        elseif bss_5mo(i)<bssSE_5mo(i)
            skillful_5mo{i}='no';
        else
            skillful_5mo{i}='NaN';
        end     

        %For 6 months lead time
        bss_6mo(i)=skillOut.bss(6);
        bssSE_6mo(i)=skillOut.bssSE(6);
        recall_6mo(i)=skillOut.recall(6);
        falseAlarm_6mo(i)=skillOut.falseAlarm(6);
        if bss_6mo(i)>=bssSE_6mo(i)
            skillful_6mo{i}='yes';
        elseif bss_6mo(i)<bssSE_6mo(i)
            skillful_6mo{i}='no';
        else
            skillful_6mo{i}='NaN';
        end            

        %For 7 months lead time
        bss_7mo(i)=skillOut.bss(7);
        bssSE_7mo(i)=skillOut.bssSE(7);
        recall_7mo(i)=skillOut.recall(7);
        falseAlarm_7mo(i)=skillOut.falseAlarm(7);
        if bss_7mo(i)>=bssSE_7mo(i)
            skillful_7mo{i}='yes';
        elseif bss_7mo(i)<bssSE_7mo(i)
            skillful_7mo{i}='no';
        else
            skillful_7mo{i}='NaN';
        end  

        %For 8 months lead time
        bss_8mo(i)=skillOut.bss(8);
        bssSE_8mo(i)=skillOut.bssSE(8);
        recall_8mo(i)=skillOut.recall(8);
        falseAlarm_8mo(i)=skillOut.falseAlarm(8);
        if bss_8mo(i)>=bssSE_8mo(i)
            skillful_8mo{i}='yes';
        elseif bss_8mo(i)<bssSE_8mo(i)
            skillful_8mo{i}='no';
        else
            skillful_8mo{i}='NaN';
        end         

        %For 9 months lead time
        bss_9mo(i)=skillOut.bss(9);
        bssSE_9mo(i)=skillOut.bssSE(9);
        recall_9mo(i)=skillOut.recall(9);
        falseAlarm_9mo(i)=skillOut.falseAlarm(9);
        if bss_9mo(i)>=bssSE_9mo(i)
            skillful_9mo{i}='yes';
        elseif bss_9mo(i)<bssSE_9mo(i)
            skillful_9mo{i}='no';
        else
            skillful_9mo{i}='NaN';
        end     

        %For 10 months lead time
        bss_10mo(i)=skillOut.bss(10);
        bssSE_10mo(i)=skillOut.bssSE(10);
        recall_10mo(i)=skillOut.recall(10);
        falseAlarm_10mo(i)=skillOut.falseAlarm(10);
        if bss_10mo(i)>=bssSE_10mo(i)
            skillful_10mo{i}='yes';
        elseif bss_10mo(i)<bssSE_10mo(i)
            skillful_10mo{i}='no';
        else
            skillful_10mo{i}='NaN';
        end 

        %For 11 months lead time
        bss_11mo(i)=skillOut.bss(11);
        bssSE_11mo(i)=skillOut.bssSE(11);
        recall_11mo(i)=skillOut.recall(11);
        falseAlarm_11mo(i)=skillOut.falseAlarm(11);
        if bss_11mo(i)>=bssSE_11mo(i)
            skillful_11mo{i}='yes';
        elseif bss_11mo(i)<bssSE_11mo(i)
            skillful_11mo{i}='no';
        else
            skillful_11mo{i}='NaN';
        end         

        %For 12 months lead time
        bss_12mo(i)=skillOut.bss(12);
        bssSE_12mo(i)=skillOut.bssSE(12);
        recall_12mo(i)=skillOut.recall(12);
        falseAlarm_12mo(i)=skillOut.falseAlarm(12);
        if bss_12mo(i)>=bssSE_12mo(i)
            skillful_12mo{i}='yes';
        elseif bss_12mo(i)<bssSE_12mo(i)
            skillful_12mo{i}='no';
        else
            skillful_12mo{i}='NaN';
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

    %%Output to table and save
    %HTFtable=table(stationNum,stationName,skillful,totalFloods,bss,bssSE,recall,falseAlarm,...
    %     skillful10yr,totalFloods10yr,bss10yr,bssSE10yr,recall10yr,falseAlarm10yr,...
    %     skillful5yr,totalFloods5yr,bss5yr,bssSE5yr,recall5yr,falseAlarm5yr);

    % save('HTFtable.mat','HTFtable');

    %%Create the filename for saving the HTF summary table csv
    % tabfileName = strcat('HTF_skillsummary_',startStr,'_',endStr,'.csv');

    %%Write the file 
    % writetable(HTFtable,tabfileName);

    %Output table w/ 1mo-12mo lead times
    HTFtable_12mo=table(stationNum,stationName,minorThresh,...
        totalFloods,skillful_1mo,bss_1mo,bssSE_1mo,recall_1mo,falseAlarm_1mo,...
        skillful_2mo,bss_2mo,bssSE_2mo,recall_2mo,falseAlarm_2mo,...
        skillful_3mo,bss_3mo,bssSE_3mo,recall_3mo,falseAlarm_3mo,...
        skillful_4mo,bss_4mo,bssSE_4mo,recall_4mo,falseAlarm_4mo,...
        skillful_5mo,bss_5mo,bssSE_5mo,recall_5mo,falseAlarm_5mo,...
        skillful_6mo,bss_6mo,bssSE_6mo,recall_6mo,falseAlarm_6mo,...
        skillful_7mo,bss_7mo,bssSE_7mo,recall_7mo,falseAlarm_7mo,...
        skillful_8mo,bss_8mo,bssSE_8mo,recall_8mo,falseAlarm_8mo,...
        skillful_9mo,bss_9mo,bssSE_9mo,recall_9mo,falseAlarm_9mo,...
        skillful_10mo,bss_10mo,bssSE_10mo,recall_10mo,falseAlarm_10mo,...
        skillful_11mo,bss_11mo,bssSE_11mo,recall_11mo,falseAlarm_11mo,...
        skillful_12mo,bss_12mo,bssSE_12mo,recall_12mo,falseAlarm_12mo,...
        skillful10yr,totalFloods10yr,bss10yr,bssSE10yr,recall10yr,falseAlarm10yr,...
        skillful5yr,totalFloods5yr,bss5yr,bssSE5yr,recall5yr,falseAlarm5yr);

    save('HTFtable_12mo.mat','HTFtable_12mo');


    %Create the filename for saving the HTF summary table csv
    tabfileName_12mo = strcat('HTF_skillsummary_12mo_',startStr,'_',endStr,'.csv');
    %Write the file 
    writetable(HTFtable_12mo,tabfileName_12mo);     

end






end