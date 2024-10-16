# -*- coding: utf-8 -*-
"""
Created on Wed Aug 21 16:12:38 2024

@author: Matthew.Conlin
"""

from Seasonal_High_Tide_Flooding_Prediction.HTF import HTF_model
import numpy as np
import os
import pandas as pd
import pytest
from scipy.io import loadmat
import shutil
import stat
import subprocess

def run_model_py(station,years_fit,years_pred):
    model = HTF_model(loc=station,
                    years_fit=years_fit,
                    years_assess=years_fit,
                    years_pred=years_pred,
                    thresh_type='NOS',
                    thresh_rel=0,
                    assess_method='DusekEtAl',
                    assess_metric='htf_days',
                    fold_size=1,
                    prctile_bin_val='pred_adj',
                    cora_data_dir=None)
    model.train()
    model.predict()
    model.assess()    
    return model
    
def run_model_mat(station,years_fit,years_pred):   
    pull_master_branch()

    # Determine the station id of the desired station from the xlsx file #
    station_list = pd.read_excel('data/HighTideOutlookStationList_05_17_23_PAC_SLT.xlsx')
    ID = np.where(station_list['St ID']==station)[0]
    
    # Set up the cocmand line cocmands to run the model
    cmd1 = 'matlab -batch '
    cmd2 = '"addpath(genpath('+"'temp_master-branch'));"
    cmd3 = ("HTF_daily_predictions_all_stations("+
    "'data/HighTideOutlookStationList_05_17_23_PAC_SLT.xlsx'"+
    ','+"'"+str(years_fit[0])+"'"+','+"'"+str(years_fit[1])+"'"+','+str(int(ID)+1)+',1);'+'"')
    cmd = cmd1 + cmd2 + cmd3
    
    # Run the Matlab version, which saves output as mat files #
    subprocess.run(cmd)

    # Load in the model output #
    res = loadmat(str(station)+'_res.mat',simplify_cells=True)['resOut']
    pred = loadmat(str(station)+'_pred.mat',simplify_cells=True)['predOut']
    skill = loadmat(str(station)+'_skill.mat',simplify_cells=True)['skillOut']
    model = {'res':res,
              'pred':pred,
              'skill':skill}
    
    # Clean up by removing the master branch and created files #
    remove_master_branch()
    os.remove('HTF_pred.csv')
    os.remove(str(station)+'_res.mat')
    os.remove(str(station)+'_pred.mat')
    os.remove(str(station)+'_data.mat')
    try:
        os.remove(str(station)+'_skill.mat')    
        os.remove('HTFtable_12mo.mat')    
        os.remove('HTF_skillsummary_12mo_'+str(years_fit[0])+'_'+str(years_fit[1])+'.csv')
    except:
        pass
    os.remove(str(station)+'_HTFpred_'+str(years_pred[0])[0:6]+'_'+str(years_pred[1])[0:6]+'.csv')      
    return model

def pull_master_branch():
    os.mkdir('temp_master-branch')   
    subprocess.run(f"git clone {'https://github.com/NOAA-CO-OPS/Seasonal_High_Tide_Flooding_Prediction.git'} {'temp_master-branch'}",shell=True,check=True)

def remove_master_branch():
    for root, dirs, files in os.walk('temp_master-branch', topdown=False):
        for name in files:
            file_path = os.path.join(root, name)
            os.chmod(file_path, stat.S_IWRITE)
    shutil.rmtree('temp_master-branch')

def test_Charleston():
    print('Comparing the Python and Matlab models at the Charleston tide gauge for an example date range. This takes a few minutes...')    
    if os.path.isdir('temp_master-branch'):
        remove_master_branch()
    
    station = 8665530
    years_fit = [20041001,20240930]
    years_pred = [20241001,20250930]
    # years_fit = [19830101,20011231]
    # years_pred = [20020101,20021231]
    
    print('Running the Python version...')    
    model_py = run_model_py(station,years_fit,years_pred)
    print('Running the Matlab version...')
    model_mat = run_model_mat(station,years_fit,years_pred)
    
    # Compare pred_adj #
    print('Comparing adjusted predictions...')
    pred_adj_py = model_py.out_train['pred_adj']
    pred_adj_mat = model_mat['res']['predAdj']
    assert len(pred_adj_py) == len(pred_adj_mat) , 'Predictions from python version are not the same length as those from Matlab version, there is a problem with the python data download.'
    assert (((pred_adj_py['val']-pred_adj_mat)).dropna().abs() < 0.01).all() , 'Adjusted predictions from Python version are at least once more than 1 cm different than Matlab version'
    print('Good!')
    
    # Compare the hourly non-tidal residuals #
    print('Comparing non-tidal residuals...')
    res_py = model_py.out_train['resids']
    res_mat = model_mat['res']['res']
    assert len(res_py) == len(res_mat) , 'Residuals from python version are not the same length as those from Matlab version.'
    assert (((res_py['val']-res_mat)).dropna().abs() < 0.01).all() , 'Non-tidal residuals from Python version are at least once more than 1 cm different than Matlab version'
    print('Good!')

    # Compare the calendar month averages of mu and sigma #
    print('Comparing mu and sigma month averages...')
    month_mu_py = model_py.out_train['dists_time']['month_mu']
    month_mu_mat = model_mat['res']['mu_monthAvg']
    month_sigma_py = model_py.out_train['dists_time']['month_sigma']
    month_sigma_mat = model_mat['res']['sigma_monthAvg']
    assert ((month_mu_py['val']-month_mu_mat).abs() < 0.01).all() , 'Calendar month non-tidal residual averages (mu) from Python version are at least once more than 1 cm different than Matlab version'
    assert ((month_sigma_py['val']-month_sigma_mat).abs() < 0.01).all() , 'Calendar month non-tidal residual stdevs (sigma) from Python version are at least once more than 1 cm different than Matlab version'
    print('Good!')

    # Compare the tide level mu and sigma #  
    print('Comparing mu and sigma tidal percentiles...')
    prctile_mu_py = model_py.out_train['dists_tide']['prctile_mu']
    prctile_mu_mat = model_mat['res']['percentileMu']
    prctile_sigma_py = model_py.out_train['dists_tide']['prctile_sigma']
    prctile_sigma_mat = model_mat['res']['percentileSigma']
    assert ((prctile_mu_py['val']-prctile_mu_mat).abs() < 0.01).all() , 'Tide-level non-tidal residual averages (mu) from Python version are at least once more than 1 cm different than Matlab version'
    assert ((prctile_sigma_py['val']-prctile_sigma_mat).abs() < 0.01).all() , 'Tide-level non-tidal residual stdevs (sigma) from Python version are at least once more than 1 cm different than Matlab version'
    print('Good!')

    # Compare monthly mu and sigma averages and anomolies #
    print('Comparing monthly mu and sigma and anomalies...')
    monthly_mu_py = model_py.out_train['dists_time']['monthly_mu'].dropna()
    monthly_mu_mat = model_mat['res']['mu_month'][~np.isnan( model_mat['res']['mu_month'])]
    monthly_sigma_py = model_py.out_train['dists_time']['monthly_sigma'].dropna()
    monthly_sigma_mat = model_mat['res']['sigma_month'][~np.isnan(model_mat['res']['sigma_month'])]
    monthly_anom_mu_py = model_py.out_train['dists_time']['anom_mu'].dropna()
    monthly_anom_mu_mat = model_mat['res']['mu_monthAmly'][~np.isnan(model_mat['res']['mu_monthAmly'])]
    monthly_anom_sigma_py = model_py.out_train['dists_time']['anom_sigma'].dropna()
    monthly_anom_sigma_mat = model_mat['res']['sigma_monthAmly'][~np.isnan(model_mat['res']['sigma_monthAmly'])]
    assert ((monthly_mu_py['val']-monthly_mu_mat).abs() < 0.01).all() , 'Monthly mu averages from Python version are at least once more than 1 cm different than Matlab version'
    assert ((monthly_sigma_py['val']-monthly_sigma_mat).abs() < 0.01).all() , 'Monthly sigma averages from Python version are at least once more than 1 cm different than Matlab version'
    assert ((monthly_anom_mu_py['val']-monthly_anom_mu_mat).abs() < 0.01).all() , 'Monthly mu anomalies from Python version are at least once more than 1 cm different than Matlab version'
    assert ((monthly_anom_sigma_py['val']-monthly_anom_sigma_mat).abs() < 0.01).all() , 'Monthly sigma anomalies from Python version are at least once more than 1 cm different than Matlab version'
    print('Good!')

    # Compare damped persistence #
    print('Comparing damped persistence values...')
    damped_per_py = model_py.out_train['damped_per']
    damped_per_mat = model_mat['res']['dampedPers']
    assert (abs(damped_per_py-damped_per_mat) < 0.01).all() , 'Damped persistence values from Python version are at least once more than 1 unit different than Matlab version'
    print('Good!')
    
    # Compare hourly freeboard #
    print('Comparing freeboard for prediction window...')
    freeboard_hourly_py = model_py.out_predict['freeboard']
    freeboard_hourly_mat = model_mat['pred']['freeboard']
    assert ((freeboard_hourly_py['val']--freeboard_hourly_mat).dropna().abs() < 0.01).all() , 'Hourly freeboard from Python version are at least once more than 1 cm different than Matlab version'
    print('Good!')
       
    # Compare hourly probability #
    print('Comparing predicted hourly probabilities...')
    prob_hourly_py = model_py.out_predict['prob_hourly']
    prob_hourly_mat = model_mat['pred']['hourlyProb']
    assert ((prob_hourly_py['val']-prob_hourly_mat).dropna().abs() < 0.01).all() , 'Hourly probabilities from Python version are at least once more than 1% different than Matlab version'
    print('Good!')

    # Compare the daily probability #
    print('Comparing daily predicted probabilities...')
    prob_daily_py = model_py.out_predict['prob_daily']
    prob_daily_mat = model_mat['pred']['dailyProb']
    assert ((prob_daily_py['val']-prob_daily_mat).dropna().abs() < 0.01).all() , 'Daily probabilities from Python version are at least once more than 1% different than Matlab version'
    print('Good!')
    
    # Compare the skill metrics #
    print('Comparing skill metrics...')
    bs_py = []
    bs_se_py = []
    bss_py = []
    bss_se_py = []
    recall_py = []
    false_alarm_py = []
    for i in range(len( model_py.out_assess['f(lead)'])):
        lead = model_py.out_assess['f(lead)'].iloc[i]['out_assess']
        for k in ['bs','bs_se','bss','bss_se','recall']:
            eval(k+'_py').append(lead[k])
        false_alarm_py.append(lead['false alarm'])
        
    bs_mat = model_mat['skill']['bs']
    bs_se_mat = model_mat['skill']['bsSE']
    bss_mat = model_mat['skill']['bss']
    bss_se_mat = model_mat['skill']['bssSE']
    recall_mat = model_mat['skill']['recall']
    false_alarm_mat = model_mat['skill']['falseAlarm']    
    assert (np.abs(bs_py-bs_mat)<0.01).all() , 'BS as a function of lead time are for at least one lead time more than 0.01 different.'
    assert (np.abs(bss_py-bss_mat)<0.01).all() , 'BSS as a function of lead time are for at least one lead time more than 0.01 different.'
    assert (np.abs(bs_se_py-bs_se_mat)<0.01).all() , 'BS SE as a function of lead time are for at least one lead time more than 0.01 different.'
    assert (np.abs(bss_se_py-bss_se_mat)<0.01).all() , 'BSS SE as a function of lead time are for at least one lead time more than 0.01 different.'
    assert (np.abs(recall_py-recall_mat)<0.01).all() , 'Recall as a function of lead time are for at least one lead time more than 0.01 different.'
    assert (np.abs(false_alarm_py-false_alarm_mat)<0.01).all() , 'False alarm rate as a function of lead time are for at least one lead time more than 0.01 different.'
    print('Good!')


    
    
    
    
