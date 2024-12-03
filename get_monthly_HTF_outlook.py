#!/usr/bin/env python
# coding: utf-8

"""============================================================================
__author__ = "Karen Kavanaugh"
__purpose__ = Gets monthly HTF outlook predictions.
__creation date__ = 11/25/2024
__latest update__ = 11/25/2024
__project__ = Monthly High Tide Flooding Outlook
__contact__ = "karen.kavanaugh@noaa.gov"
__notes__ = 
    - Requirements for set-up:
        + Python 3.7
        + pyHTF - created by Matthew Conlin
============================================================================="""
#/////////////////////////////////Change History////////////////////////////////////#

#//////////////////////////////////////////////////////////////////////////////////#
#-------------------------------LIBRARIES--------------------------------------#
# imports
import os
import pandas as pd
import numpy as np
import datetime as dt
from datetime import date, datetime, timezone, timedelta

from HTF import HTF_model

#/////////////////////////////////INPUTS//////////////////////////////////////#
data_dir = os.getcwd()

if not os.path.exists(data_dir+'/Monthly_HTF/Output/'):
    os.makedirs(data_dir+'/Monthly_HTF/Output/')
outpath = '/Monthly_HTF/Output/'

#get current time
now = dt.datetime.now(timezone.utc)
now_filename = now.strftime("%Y%m%d_%H%M")


# USER SPECIFIED INPUTS
beg_dt_fit = input('BEGIN DATE of model training data (format is: YEAR (YYYY), MONTH (MM), DAY (DD)): ')
end_dt_fit = input('END DATE of model training data: ')
beg_dt_assess = input('BEGIN DATE of model assessment data (if different from training data): ') or beg_dt_fit
end_dt_assess = input('END DATE of model assessment data (if different from training data): ') or end_dt_fit
beg_dt_pred = input('BEGIN DATE of model predictions: ')
end_dt_pred = input('END DATE of model predictions: ')
thresh_type = input('Specify flood threshold type (default is NOS): ') or 'NOS'
htb_run_id = input('Enter model run ID: ')

assess_method = 'DusekEtAl'
assess_metric = 'htf_days'
fold_size = 1
prctile_bin_val = 'pred_adj'


# INTERPRET INPUT DATA SPREADSHEETS
## Read in HTF station list csv
htf_stn_df = pd.read_excel(data_dir + '/Monthly_HTF/Data/test-HighTideOutlookStationList_05_17_23_PAC_SLT.xlsx')

## Create dictionary of station ID and region name
htf_stn_dict = dict(zip(htf_stn_df['St ID'], htf_stn_df['Station Name']))

#/////////////////////////////////MAIN//////////////////////////////////////#

# RUN MONTHLY HIGH TIDE FLOODING MODEL
# Create empty dataframe to concatenate results for each station
all_monthly_pred_df = pd.DataFrame()

for stn_id in htf_stn_dict:
    model = HTF_model(loc=stn_id,
                      years_fit=[beg_dt_fit, end_dt_fit],
                      years_assess=[beg_dt_assess, end_dt_assess],
                      years_pred=[beg_dt_pred, end_dt_pred],
                      thresh_type=thresh_type,
                      assess_method=assess_method,
                      assess_metric=assess_metric,
                      fold_size=fold_size,
                      prctile_bin_val=prctile_bin_val
                     )

    print('Training the model for station {}...'.format(stn_id))
    model.train()
    print('Assessing the model for station {}...'.format(stn_id))
    model.assess()
    print('Calculating flood likelihoods for station {}...'.format(stn_id))
    model.predict()

    #split time column into year, month, and day columns
    model.out_predict['prob_daily']['time'] = pd.to_datetime(model.out_predict['prob_daily']['time'])
    model.out_predict['prob_daily']['year'] = model.out_predict['prob_daily']['time'].dt.year
    model.out_predict['prob_daily']['month'] = model.out_predict['prob_daily']['time'].dt.month
    model.out_predict['prob_daily']['day'] = model.out_predict['prob_daily']['time'].dt.day
    
    #determine flood status (if likelihood is > 0.05)
    model.out_predict['prob_daily']['flood'] = np.where(model.out_predict['prob_daily']['val'] >= 0.05, 1, 0)       

    #FORMAT RESULTS IN DATAFRAME
    print('Compiling results...')
    monthly_pred_df = pd.DataFrame()

    # add values from model.out_predict['prob_daily'] including year, month, day, flood, likelihood, dist_to_thresh
    monthly_pred_df = pd.concat([monthly_pred_df, model.out_predict['prob_daily'].rename(columns={'val': 'likelihood', 'max freeboard': 'dist_to_thresh'})], ignore_index=True)
    monthly_pred_df.drop('time', axis=1, inplace=True)

    # add station ID from stn_id
    monthly_pred_df['station_id'] = stn_id
    
    # add flood_category
    monthly_pred_df['flood_category'] = np.nan
    
    # add values from model.out_train['data']: minor_thresh
    monthly_pred_df['minor_thresh'] = model.out_train['data']['Flood thresh']
    
    # add htb_run_id
    monthly_pred_df['htb_run_id'] = htb_run_id
    
    # rearrange columns
    col_order = ['station_id', 'year', 'month', 'day', 'flood', 'flood_category', 'likelihood', 'minor_thresh', 'dist_to_thresh', 'htb_run_id']
    monthly_pred_df = monthly_pred_df[col_order]
    print(monthly_pred_df)

    all_monthly_pred_df = pd.concat([all_monthly_pred_df, monthly_pred_df], ignore_index=True)
    print(all_monthly_pred_df)

#EXPORT THE OUTPUT
# save to a csv file
all_monthly_pred_df.to_csv(data_dir + outpath + 'HTF_pred.csv', index=False)