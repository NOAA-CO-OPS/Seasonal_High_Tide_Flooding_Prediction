# -*- coding: utf-8 -*-
"""
Created on Fri Aug 16 10:09:08 2024

@author: Matthew.Conlin
"""

import datetime
import intake
import numpy as np
import os
import pandas as pd
import pickle
import pkg_resources
import requests
import scipy
from sklearn.metrics import confusion_matrix
import subprocess
import warnings
warnings.filterwarnings('ignore')
import utide

class HTF_model:
    '''
    Python-translation of the statistical high tide flood (HTF) model originally
    introduced in Dusek et al. (2022). Class provides functionality to train,
    assess, and predict using many options for model parameters/methods 
    specified when the model is initialized.

    Attributes
    ----------
    loc : int or list of float
        NWLON station number or lat lon as a list of form [lat,lon] 
        
    years_fit : list of int
        Years on which to train the model, in the form yyyymmdd, where the list
        is [start_year,end_year]. Make sure the start year starts on Jan 1 and the
        end year ends on Dec 31, e.g. [19830101,20011231].
        
    years_assess : list of int
        Years on which to assess the model, in the form yyyymmdd, where the list
        is [start_year,end_year]. Make sure the start year starts on Jan 1 and the
        end year ends on Dec 31, e.g. [19830101,20011231].
        
    years_pred : list of int
        Years on which to assess the model, in the form yyyymmdd, where the list
        is [start_year,end_year]. Make sure the start year starts on Jan 1 and the
        end year ends on Dec 31, e.g. [19830101,20011231].
        
    thresh_type: str, optional
        The type of high tide flood threshold two use. Options are:
            'NWS': The published minor threshold from NWS at the tide gauge, if a gauge
                   id was input for loc. Not available if a lat/lon was input.
            'NOS': The derived minor threshold from NOS at the tide gauge, 
                   using the method of Sweet et al. (2018), if a gauge id was input for loc.
                   Not available if a lat/lon was input.
            'MHHW' or etc.: Use a threshold value relative to MHHW. Can also be any other
                    standard tidal datum, for example MSL, MHW, MLW, MLLW to use
                    a threshold value relative to that datum.
        The default is 'NOS'
    
    thresh_rel: float or int, optional
        The height (in m) to add to the high tide flood threhsold given by
        thresh_type. For example, if thresh_type='MHHW' and thresh_rel=0.15,
        the threshold is taken as 0.15 m above MHHW.
        The default is 0.
        
    assess_method : str, optional
        The model assessment method. Options are:
            'DusekEtAl': The original method used in Dusek et al. (2022).
                         Fully in-sample, i.e. assess the model on the same
                         data that the model was trained on, but do so at 
                         different lead times.
            'in_sample' : Assess the observations on the training data, without
                         looking at different lead times.
            'out_of_sample': Simple train-test split. Train the model on one set 
                            of observations, assess it on another.
            'cross_validation': K-fold cross-validation. Split the training data into
                                k subsets (folds). Re-train the data on k-1 folds and
                                evaluate it on the remaining fold, doing this
                                for all folds and aggregating the results.
            'None': Do not perform an assessment.
        The default is 'DusekEtAl'.
        
    assess_metric : str, optional
        The metric to use for skill assessment. Options are:
            'htf_days': The number of HTF days, as in Dusek et al. (2022)
            OTHERS CAN BE INSERTED HERE
        The default is 'htf_days'.
        
    fold_size : int, optional
        The size of the folds (in years) if using the cross_validation
        assesment method. Required if using the cross_validation assessment method,
        ignored otherwise. The deafault is 1 year.
        
    prctile_bin_val: str, optional
        The variable to use for the tide percentile binning. Options are:
            'pred_adj': Bin non-tidal residuals based on the predicted tide level
                        adjusted by the sea level trend.
            'pred': Bin non-tidal residuals based on the predicted tide level
                        not adjusted by the sea level trend.
        The default is 'pred_adj'.
        
    cora_data_dir: str, optional
        The directory of saved CORA timeseries and/or computed parameters, if it
        exists. The default is None.
        
    temp_cora_retrend: list of float, optional
        The trend in m/s to artifically give the CORA hourly_height timeseries. This is meant
        to be a temporary parameter for using CORA V1.0, which has bad trends. This is meant to
        be removed when V1.1 is available. The default is None, which means do not retrend.

    Methods
    ------
    train()
        Train the model on years_train observations, i.e. develop the 
        non-tidal residual distribution parameters and damped persistence
        values.
        
    assess()
        Assess the trained model on years_assess observations using one of
        the methods and one of the metrics specified at model initialization.
        
    predict()
        Apply the trained model on years_predict.
        
    Many additional staticmethods provide core functionality and are called 
    by these main methods.

    Returns
    -------
    After running, the model contains additional attributes:
    out_train : dict
        Contains the data used to train, non-tidal residuals, computed
        distribution parameters, and computed damped persistence.
    out_assess : dict
        Contains skill metrics for the model on the assessment years.
    out_predict : dict
        The same as out_assess but for the prediction years.

    '''
    def __init__(self,loc,years_fit,years_assess,years_pred,
                 thresh_type='NOS',thresh_rel=0,
                 assess_method='DusekEtAl',assess_metric='htf_days',
                 fold_size=1,prctile_bin_val='pred_adj',
                 cora_data_dir=None,temp_cora_retrend=None):     
        '''
        Initializes the HTF model and does initial error checking of inputs.

        '''
        self.loc = loc
        self.years_fit = years_fit
        self.years_assess = years_assess
        self.years_pred = years_pred   
        self.thresh_type = thresh_type
        self.thresh_rel = thresh_rel
        self.assess_method = assess_method
        self.assess_metric = assess_metric
        self.fold_size = fold_size
        self.prctile_bin_val = prctile_bin_val
        self.cora_data_dir = cora_data_dir
        self.temp_cora_retrend = temp_cora_retrend
        
        # Check that either a NWLON or lat/lon were provided correctly #
        if not isinstance(self.loc,int) and not isinstance(self.loc,list):
            raise ValueError('First argument loc must be either an integer, representing an NWLON station, or a list with lat/lon values in the form [lat,lon].')
        if isinstance(self.loc,list) and len(self.loc)!=2:
            raise ValueError('You have provided a list for first argument loc, but the list does not have len()=2. The list needs to be a lat and a lon value in the form [lat,lon].')

        # Check that the desired threshold types are valid for the type of location #
        if self.thresh_type not in ['NWS','NOS','MHHW','MHW','MSL','MLW','MLLW']:
                raise ValueError("The threshold type must be either 'NWS', 'NOS', or a standard tidal datum (e.g. 'MHHW' or 'MSL')")
        if isinstance(self.loc,list) and self.thresh_type=='NWS':
                raise ValueError("NWS thresholds are not available for non-tide gauge locations. You can use 'NOS' to compute a derived threshold based on GT, or a standard tidal datum (e.g. 'MHHW'), along with thresh_rel to specify a threshold.")
        
        # Check that valid options were provided for the remaining inputs. #
        if self.assess_method not in ['DusekEtAl','in_sample','out_of_sample','cross_validation','None']:
                raise ValueError("The assessment method must be one of: 'DusekEtAl','in_sample', 'out_of_sample', 'cross_validation', 'None'")
        if self.assess_metric not in ['htf_days']:
                raise ValueError("The assessment metric must be one of: 'htf_days'")            
        if self.prctile_bin_val not in ['pred','pred_adj']:
                raise ValueError("The percentile bin value must be one of: 'pred','pred_adj'")

    def train(self):
        '''
        Function to train the model.

        Returns
        -------
        After running, model object contains an attribute named out_train

        '''
        data = self.pull_data(self.loc,self.years_fit,'gmt',self.thresh_type,self.thresh_rel,
                              self.cora_data_dir,self.temp_cora_retrend)
        self.out_train = self.calc_resids_and_dists(data,bin_val=self.prctile_bin_val)
        
        
    def assess(self):
        '''
        Function to assess the trained model on the assessment years using one
        of the methods and one of the metrics specified at model initialization.

        Returns
        -------
        After running, model object contains an attribute named out_assess.

        '''
        try:
            self.out_train
        except AttributeError:
            raise AttributeError('You must train the model before you can assess performance. Use model.train().')

        print('Assessing the model using the '+self.assess_method+' method...')
        if self.assess_method == 'DusekEtAl':  
            yrmos = self.out_train['data']['predictions']['time'].dt.to_period('M').unique()  
            prob_daily_all = [np.nan]                     
            for yrmo in yrmos[1:len(yrmos)]:
                print('Generating prediction starting in '+str(yrmo))
                pred = self.out_train['data']['predictions'][self.out_train['data']['predictions']['time'].dt.to_period('M')>=yrmo]
                pred = pred[pred['time'].dt.to_period('M')<yrmo+12]
                out_run = self.run(pred,self.out_train)
                prob_daily_all.append(out_run['prob_daily'])
            print('Computing observed flood days...')   
            observed_floods = ModelEngine.calc_observed_floods(self.out_train['data'])
            print('Determining predicted flood days as a function of forecast lead time...')
            yrmods = self.out_train['data']['predictions']['time'].dt.to_period('D').unique()
            prob_daily_all_lead = np.zeros([12,len(yrmods)])*np.nan
            for yrmod in yrmods:               
                # Find the year-long predictions that contain this date #
                iin = [i for i in range(1,len(prob_daily_all)) if yrmod.to_timestamp() in prob_daily_all[i]['time'].values]
                # Store the prob value for each prediction on this date ordered
                # by lead time #
                for i in iin:
                    p_want = yrmod.to_timestamp().to_period('M')
                    p_avail = prob_daily_all[i]['time'].dt.to_period('M').unique()
                    i_lead = np.where(p_avail==p_want)[0][0]
                    prob_daily_all_lead[i_lead,np.where(yrmods==yrmod)[0][0]] = prob_daily_all[i][prob_daily_all[i]['time']==yrmod.to_timestamp()]['val'].values[0]
            print('Calculating skill as a function of lead time...') 
            out_assess_all_lead = pd.DataFrame({'lead':[],'out_assess':[]})
            for lead in np.arange(0,12):
                out_run = {'prob_daily':pd.DataFrame({'time':observed_floods['time'],'val':prob_daily_all_lead[lead,:]})}
                out_assess = self.calc_skill(self.out_train['data'],
                                             out_run,
                                             self.assess_metric)
                out_assess_all_lead = pd.concat([out_assess_all_lead,pd.DataFrame({'lead':[lead+1],'out_assess':[out_assess]})])
            print('Calculating skill for last 5 and 10 years at 1 month lead time...')    
            out_assess_5and10 = []
            for nyr in [5,10]:
                t_start = observed_floods['time'].iloc[-1]-datetime.timedelta(days=365.2425*nyr)            
                out_train_sub = self.out_train['data'].copy()
                for k in ['hourly_height','predictions']:
                    out_train_sub[k] = out_train_sub[k][out_train_sub[k]['time']>=datetime.datetime(t_start.year,t_start.month,t_start.day)+datetime.timedelta(days=1)].reset_index(drop=True)
                
                b_keep = observed_floods['time']>=t_start
                out_run = {'prob_daily':pd.DataFrame({'time':observed_floods['time'][b_keep].reset_index(drop=True),'val':prob_daily_all_lead[0,:][b_keep]})}
        
                out_assess = self.calc_skill(out_train_sub,
                                             out_run,
                                             self.assess_metric)
                out_assess_5and10.append(out_assess)
                
            self.out_assess = {'f(lead)':out_assess_all_lead,'5 and 10 yr':out_assess_5and10}
        
        elif self.assess_method == 'in_sample':
            # Run the trained model on the same data as it was trained on #
            print('Running the trained model on the same observations...')
            out_run = self.run(self.out_train['data']['predictions'],
                               self.out_train)
            # Do the skill assessment #
            print('Calclating model skill on the same observations...')
            self.out_assess = self.calc_skill(self.out_train['data'],
                                         out_run,
                                         self.assess_metric)
            
        elif self.assess_method == 'out_of_sample':
            # Get the new out-of-training-sample data for the validation #
            print('Downloading and formatting the new out of sample observations. This can take a while...')
            data = self.pull_data(self.loc,self.years_assess,'lst_ldt',self.thresh_type,self.thresh_rel,self.cora_data_dir,self.temp_cora_retrend)           
            # Run the trained model on the new data #
            print('Running the trained model on the new observations...')
            out_run = self.run(data['predictions'],self.out_train)                                                  
            # Do the skill assessment #
            print('Calclating model skill on the new observations...')
            self.out_assess = self.calc_skill(data,out_run,self.assess_metric)
                       
        elif self.assess_method == 'cross_validation':
            # Determine the folds #
            yrs = self.out_train['data']['hourly_height']['time'].dt.year.unique()
            set_test = [np.arange(i,i+self.fold_size) for i in np.arange(yrs[0],yrs[-1]+1,self.fold_size)]
            set_train = [yrs[~np.isin(yrs,i)] for i in set_test]
            folds = pd.DataFrame({'train':set_train,'test':set_test})
            # For each fold, re-train on training data and test on testing data #
            obs_all = self.out_train['data'].copy()
            obs_all['predictions'] = obs_all['predictions'].drop(obs_all['predictions'].index)
            obs_all['hourly_height'] = obs_all['hourly_height'].drop(obs_all['hourly_height'].index)         
            pred_all = pd.DataFrame({'time':[],'val':[]})
            for nfold in np.arange(1,len(folds)):
                print('Re-training, re-running, and assessing the model on fold '+str(nfold+1)+' of '+str(len(folds)))
                i_test = np.isin(self.out_train['data']['hourly_height']['time'].dt.year,folds['test'].iloc[nfold])
                data_retrain = self.out_train['data'].copy()
                data_rerun = self.out_train['data'].copy()
                data_retrain['predictions'] = data_retrain['predictions'][~i_test]
                data_retrain['hourly_height'] = data_retrain['hourly_height'][~i_test]
                data_rerun['predictions'] = data_rerun['predictions'][i_test]
                data_rerun['hourly_height'] = data_rerun['hourly_height'][i_test]
                # Retrain on training subset #
                out_retrain = self.calc_resids_and_dists(data_retrain,bin_val=self.prctile_bin_val)
                # Re-run on running subset, while predicting each month at one
                # month lead time #
                yrmos = data_rerun['predictions']['time'].dt.to_period('M').unique()
                prob_daily_1month_all = [np.nan]                     
                for yrmo in yrmos[1:len(yrmos)]:
                    print('Generating prediction starting in '+str(yrmo))
                    pred = data_rerun['predictions'][data_rerun['predictions']['time'].dt.to_period('M')>=yrmo]
                    pred = pred[pred['time'].dt.to_period('M')<yrmo+12]
                    out_rerun = self.run(pred,out_retrain)
                    prob_daily_1month = out_rerun['prob_daily'][out_rerun['prob_daily']['time'].dt.to_period('M')<yrmo+1]
                    prob_daily_1month_all.append(prob_daily_1month)
                pred_all = pd.concat([df for df in prob_daily_1month_all if isinstance(df, pd.DataFrame)], ignore_index=True)
                
                for v in ['predictions','hourly_height']:
                    obs_all[v] = pd.concat([obs_all[v],data_rerun[v]],ignore_index=True)
                    obs_all[v] = obs_all[v][obs_all[v]['time'].dt.to_period('M')>yrmos[0]]

            pred_all = {'prob_daily':pred_all}
            self.out_assess = self.calc_skill(obs_all,pred_all,self.assess_metric)
        
        elif self.assess_method == 'None':
                raise ValueError(r'The assessment method was set to None, so no assessment can be'+
                                 ' performed. If you would like to perform an assessment, choose'+
                                 ' an assessment method: DusekEtAl, in_sample, out_of_sample, or cross_validation.')
        
    def predict(self):
        '''
        Function to predict with the trained model using the prediction years.

        Returns
        -------
        After running, model object contains an attribute named out_predict.

        '''
        try:
            self.out_train
        except AttributeError:
            raise AttributeError('You must train the model before you can make predictions. Use model.train().')

        print('Generating predictions with the trained model...')

        # Get the predictions for the prediction period #
        print('Getting the tide predictions for the prediction period...')
        predictions = self.pull_predictions(self.loc,self.out_train,self.years_pred,'lst_ldt',self.cora_data_dir)           
        
        # Run the trained model on the new data #
        print('Running the trained model with the predictions...')
        self.out_predict = self.run(predictions,self.out_train) 

           
    @staticmethod    
    def pull_data(loc,years,time_zone,thresh_type,thresh_rel,cora_data_dir,temp_cora_retrend):
        '''
        Function to get and format the observed and predicted hourly water levels for
        the desired time period.

        Parameters
        ----------
        station : int
            Station number.
        years : list
            Years of data to pull, each in the format yyyymmdd. First year should
            end with 0101 and second year should end with 1231. For example:
            [19830101,20011231].
        time_zone : str
            The time zone to use.

        Returns
        -------
        data_api : list of Pandas DataFrames
            The observed hourly water level and predicted hourly water level as
            Pandas DataFrames, with gaps filled with NaNs.
        data_nonapi : Pandas DataFrame
            The non-api data from the station_list file.

        '''
        if isinstance(loc,int):
            print('Downloading and formatting gauge observations. This can take a while...')
            try:
                data_api = ApiInterface(loc, str(years[0]), str(years[1]),
                                    product=['hourly_height','predictions'],
                                    time_zone=time_zone).run()
                data_nonapi = utils.load_data(loc)
            except KeyError:
                raise ValueError('The provided gauge ID is not a valid NWLON station number')
            except TypeError:
                raise ValueError('The provided dates are not in the correct format. Please provide a list in the form [yyyymmdd,yyyymmdd]')
            except:
                raise ValueError('At least one of the requested product names is not valid, or something else went wrong.')
            
            if thresh_type == 'NOS':
                if 9450000<=loc<=9470000:
                    flood_thresh = data_nonapi['Derived Minor'].iloc[0]+thresh_rel
                else:
                    flood_levels = ApiInterface(loc,str(years[0]),str(years[1]),
                                                product='floodlevels').run()['floodlevels']
                    datums = ApiInterface(loc,str(years[0]),str(years[1]),
                                          product='datums').run()['datums']['datums']
                    flood_thresh = round(flood_levels['nos_minor']-utils.datumlist2datumval(datums,'MHHW'),3)
            elif thresh_type == 'NWS':
                flood_thresh = data_nonapi['NWS minor (MHHW)'].iloc[0]+thresh_rel                
            else:
                datums = ApiInterface(loc,str(years[0]),str(years[1]),
                                    product='datums').run()['datums']['datums'] # Datums are returned relative to the station datum #
                z_mhhw = utils.datumlist2datumval(datums,'MHHW')
                thresh1 = utils.datumlist2datumval(datums,thresh_type)
                flood_thresh = thresh1-z_mhhw+thresh_rel
            
            data = {'ID':data_nonapi['St ID'].iloc[0],
                    'Name':data_nonapi['Station Name'].iloc[0],
                    'Epoch center':data_nonapi['Epoch center'].iloc[0],
                    'SLT':data_nonapi['MSL Trend (mm/yr)'].iloc[0],
                    'Flood thresh':flood_thresh,
                    'hourly_height':data_api['hourly_height'],
                    'predictions':data_api['predictions']}   
            
        elif isinstance(loc,list):
            hourly_height_msl   = CoraEngine.get_timeseries(loc, 
                                                          utils.datestr2dt(str(years[0])), 
                                                          utils.datestr2dt(str(years[1])[0:4]+' '+str(years[1])[4:6]+' '+str(years[1])[6:8]+' 23:59'),
                                                          cora_data_dir,temp_cora_retrend)                
            datums_msl          = CoraEngine.calc_datums(CoraEngine.get_timeseries(loc, 
                                                             datetime.datetime(1983,1,1), 
                                                             datetime.datetime(2001,12,31,23,0),
                                                             cora_data_dir,temp_cora_retrend),
                                                         loc,
                                                         cora_data_dir)
            hourly_height,datums = CoraEngine.msl2mhhw(hourly_height_msl,datums_msl)
            predictions          = CoraEngine.calc_predictions(hourly_height,
                                                            loc,
                                                            hourly_height['time'],
                                                            cora_data_dir,
                                                            datums_msl)
            slt                  = CoraEngine.calc_slt(CoraEngine.get_timeseries(loc, 
                                                             datetime.datetime(1980,1,1), 
                                                             datetime.datetime(2019,12,31,23,0),
                                                             cora_data_dir,temp_cora_retrend)) 
            epoch_center         = CoraEngine.calc_epoch_center(years)
            flood_thresh         = CoraEngine.calc_flood_thresh(datums,thresh_type,thresh_rel)
            
            data = {'ID':loc,
                    'Name':'CORA node',
                    'Epoch center':epoch_center,
                    'SLT':slt,
                    'Flood thresh':flood_thresh,
                    'hourly_height':hourly_height,
                    'predictions':predictions}              
        return data
    
    @staticmethod
    def calc_resids_and_dists(data,bin_val='pred_adj'):
        print('Training the model...')
        # Add the sea level trend to the predictions #
        pred = data['predictions']
        pred_adj,adj = ModelEngine.add_trend(pred,
                                      data['SLT'],
                                      data['Epoch center'])
        
        # Calculate the residuals relative to the adjusted predictions #
        resids = data['hourly_height']['val']-pred_adj['val']
        resids = pd.DataFrame({'time':data['hourly_height']['time'],
                                   'val':resids})
        
        # Calculate the residual distribution parameters #
        resid_dists = ModelEngine.residual_distributions()
        dists_time = resid_dists.time(resids)
        dists_tide = resid_dists.tide(resids,eval(bin_val),prctile=10)
        
        # Calculate the damped persistence values #
        damped_per = ModelEngine.damped_persistence(dists_time['anom_mu'])
        
        out = {'data':data,
            'pred_adj':pred_adj,
            'resids':resids,
            'dists_time':dists_time,
            'dists_tide':dists_tide,
            'damped_per':damped_per}
   
        return out

    @staticmethod
    def pull_predictions(loc,out_train,years,time_zone,cora_data_dir):
        if isinstance(loc,int):
            print('Downloading predictions for prediction window...')
            predictions = ApiInterface(loc, str(years[0]), str(years[1]),
                                product='predictions',
                                time_zone=time_zone).run()['predictions']                 
        elif isinstance(loc,list):
            dt_start = utils.datestr2dt(str(years[0]))
            dt_end = utils.datestr2dt(str(years[1]))
            dt_end = datetime.datetime(dt_end.year,dt_end.month,dt_end.day,23,0,0)
            time_pred = pd.date_range(dt_start,dt_end,freq='h')
            print('Calculating tidal predictions...')
            f = open(cora_data_dir+'/CORA_'+str(loc[0])+'_'+str(loc[1])+'_1979_2022_datums.pkl','rb')
            datums_msl = pickle.load(f)
            predictions = CoraEngine.calc_predictions(out_train['data']['hourly_height'],loc,time_pred,cora_data_dir,datums_msl)
        return predictions
    
    @staticmethod
    def run(predictions,out_train):
        yrmo = predictions['time'].dt.to_period('M').unique()
        # Split into 12-month chunks #
        chunks = [np.array(yrmo)[i:i + 12] for i in range(0, len(yrmo), 12)]
        for chunk in chunks:
            predictions_chunk = predictions[np.isin(predictions['time'].dt.to_period('M'),chunk)]       
            try:
                anom_preceeding = out_train['dists_time']['anom_mu'][out_train['dists_time']['anom_mu']['time']<predictions_chunk['time'].iloc[0]].iloc[-1]
            except IndexError:
                anom_preceeding = out_train['dists_time']['anom_mu'].iloc[0]
                anom_preceeding.val = np.nan
            persistence_apply = ModelEngine.calc_persistence_apply(anom_preceeding,
                                                                   predictions_chunk,
                                                                   out_train)
                
            months = predictions_chunk['time'].dt.month.unique()
            mu,sigma = ModelEngine.calc_dist_params(out_train,
                                                    months,
                                                    persistence_apply)
            
            px = np.arange(-2,15.005,0.005)[0:-1] # The NTRs at which to evaluate the cdf #
            cy = ModelEngine.calc_cdf(px,
                                      mu,
                                      sigma)
            
            # Add the sea level trend to the predictions #
            pred_adj,adj = ModelEngine.add_trend(predictions_chunk,
                                                 out_train['data']['SLT'],
                                                 out_train['data']['Epoch center'])
        
        
            # Calculate hourly freeboard from flood thresh to adjusted predictions #
            freeboard = ModelEngine.calc_freeboard(out_train['data']['Flood thresh'],
                                                   pred_adj)
       
            # Apply cdfs to determine probability that the NTR is >freeboard
            # for each hourly observation #
            prob_hourly = ModelEngine.calc_hourly_prob(cy,
                                                     px,
                                                     pred_adj,
                                                     freeboard,
                                                     out_train['dists_tide'])
        
            # Use the hourly probabilities to compute cumulative daily probabilities,
            # taking into account the temporal dependence of NTR #
            prob_daily = ModelEngine.calc_daily_prob(prob_hourly,
                                                     freeboard,
                                                     out_train['resids'])
            
            if (chunk==chunks[0]).all():
                freeboard_all = freeboard
                prob_hourly_all = prob_hourly
                prob_daily_all = prob_daily
            else:
                freeboard_all = freeboard_all._append(freeboard,ignore_index=True)
                prob_hourly_all = prob_hourly_all._append(prob_hourly,ignore_index=True)
                prob_daily_all = prob_daily_all._append(prob_daily,ignore_index=True)
        
        out_run = {'freeboard':freeboard_all,
                    'prob_hourly':prob_hourly_all,
                    'prob_daily':prob_daily_all}
        return out_run

    @staticmethod
    def calc_skill(data,out_run,assess_metric):            
        if assess_metric == 'htf_days':
            observed_floods = ModelEngine.calc_observed_floods(data)
            bs,bss,bs_se,bss_se = ModelEngine.brier_stats(observed_floods,
                                                          out_run['prob_daily']).run()
            reliability,resolution = ModelEngine.calc_reliability(observed_floods,
                                                                  out_run['prob_daily'])
            accuracy,precision,recall,false_alarm,F1 = ModelEngine.calc_confusion_stats(observed_floods,
                                                                                        out_run['prob_daily'],
                                                                                        min_prob=0.05)
            skill = {'bs':bs,
                     'bss':bss,
                     'bs_se':bs_se,
                     'bss_se':bss_se,
                     'reliability':reliability,
                     'resolution':resolution,
                     'accuracy':accuracy,
                     'precision':precision,
                     'recall':recall,
                     'false alarm':false_alarm,
                     'F1':F1}
            
            return skill
        else:
            raise ValueError('Currently, the only accepted assessment metric is htf_days.')
          

        


class ModelEngine():    
    @staticmethod
    def add_trend(pred,slt,epoch_center):
        '''
        Function to add a sea level trend to tide predictions.
        Direct line-for-line translation of Greg's addTrend.m

        Parameters
        ----------
        pred : Pandas DataFrame
            The tide predictions, returned by pull_data(self).
        slt : float
            The sea level trend (in mm/yr), returned by pull_data(self)
        epoch_center : str
            The epoch center, returned by pull_data(self).

        Returns
        -------
        pred_adj : Pandas DatFrame
            The predictions with the trend included
        adj : numpy array
            The values added to the predictions.

        '''
        # Convert the epoch center given in fractional years to a datetime
        # object so we can work with it #
        yr = np.floor(epoch_center)
        yr_p = epoch_center-yr
        epoch_center = datetime.datetime(int(yr),1,1)+datetime.timedelta(days=yr_p*365.2425)
    
        # Change trend to meters #
        slt = round(float(slt)/1000,7)
        
        # Change from epoch center to start date #
        years_to_mid = (pred['time'].iloc[0]-epoch_center).total_seconds()/(365.2425*24*60*60)
        start_trend = slt*years_to_mid  
        
        # Change over total length of predictions #
        years_tot = (pred['time'].iloc[-1]-pred['time'].iloc[0]).total_seconds()/(365.2425*24*60*60)
        slt_total = slt*years_tot   
        
        # Compute the value to add at each time #
        adj = start_trend+(slt_total/len(pred))*(np.arange(0,len(pred))) 
        
        # Add the trend #
        pred_adj = pd.DataFrame({'time':pred['time'],'val': pred['val']+adj})        
    
        return pred_adj,adj
    
    class residual_distributions:
        @staticmethod
        def time(resids):
            '''
            Function to calculate non-tidal residual distribution parameters in 
            monthly partitions.

            Parameters
            ----------
            resids : pandas DataFrame
                The observed hourly non-tidal residuals (obs-[predictions+trend]).

            Returns
            -------
            dists : dict
                All of the time-distribution parameters. Fields are:
                    monthly_mu : pandas DataFrame
                        The mean non-tidal residual for each month of the dataset.
                    monthly_sigma : pandas DataFrame
                        The standard deviation of non-tidal residual for each month of 
                        the dataset. 
                    month_mu : pandas DataFrame
                        The non-tidal residual mean for each calendar month over the
                        observation period.
                    month_sigma : pandas DataFrame
                        The non-tidal residual standard deviation for each calendar 
                        month over the observation period.
                    anom_mu : pandas DataFrame
                        The anomaly of the non-tidal residual mean each month, relative
                        to that calendar month's mean (i.e. monthly_mu - month_mu
                        for a given month)
                    anom_sigma : pandas DataFrame
                        The anomaly of the non-tidal residual standard deviation each month, relative
                        to that calendar month's standard deviation (i.e. monthly_sigma - month_sigma
                        for a given month)           
            '''
            # Get the year and month of each residual observation #
            resids_years = pd.to_datetime(resids['time']).dt.year
            resids_months = pd.to_datetime(resids['time']).dt.month
            
            # Initialize the year by month arrays with the correct sizes (n_month by n_year)
            n_year = resids['time'].iloc[-1].to_pydatetime().year - resids['time'].iloc[0].to_pydatetime().year + 1
            monthyr_mu = np.empty([12,n_year])
            monthyr_sigma = np.empty([12,n_year])
            
            # Loop through each year/month combo, find the residual observations that
            # are in that year and month, find the avg and std, and save #
            monthyr = np.zeros([len(np.arange(1,n_year+1))*len(np.arange(1,13))],dtype='datetime64[ms]')
            c=-1
            for yr in np.arange(1,n_year+1):
                for mo in np.arange(1,13): 
                    c+=1
                    iyrmo = np.logical_and(resids_years==resids['time'].iloc[0].to_pydatetime().year+yr-1,resids_months==mo)
                    mu = resids['val'][iyrmo].mean()
                    sigma = resids['val'][iyrmo].std()
                    monthyr_mu[mo-1,yr-1] = mu
                    monthyr_sigma[mo-1,yr-1] = sigma
                    monthyr[c] = datetime.datetime(resids['time'].iloc[0].to_pydatetime().year+yr-1,
                                                   mo,1)

            monthly_mu = pd.DataFrame({'time':monthyr,
                                        'val':monthyr_mu.T.reshape(-1)})
            monthly_sigma = pd.DataFrame({'time':monthyr,
                                        'val':monthyr_sigma.T.reshape(-1)})
                    
            month_mu = pd.DataFrame({'time':np.arange(1,13),
                                      'val':np.nanmean(monthyr_mu,axis=1)})
            month_sigma = pd.DataFrame({'time':np.arange(1,13),
                                        'val':np.nanmean(monthyr_sigma,axis=1)})
            
            # Calculate the monthly anomolies #
            monthyr_anom_mu = monthyr_mu-np.array(month_mu['val']).reshape(-1,1)
            monthyr_anom_sigma = monthyr_sigma-np.array(month_sigma['val']).reshape(-1,1)
            anom_mu = pd.DataFrame({'time':monthyr,
                                    'val':monthyr_anom_mu.T.reshape(-1)})
            anom_sigma = pd.DataFrame({'time':monthyr,
                                    'val':monthyr_anom_sigma.T.reshape(-1)})
            
            dists = {'monthly_mu':monthly_mu,
                     'monthly_sigma':monthly_sigma,
                     'month_mu':month_mu,
                     'month_sigma':month_sigma,
                     'anom_mu':anom_mu,
                     'anom_sigma':anom_sigma}
            
            return dists
        
        @staticmethod
        def tide(resids,predictions,prctile):
            '''
            Function to calculate non-tidal residual distribution parameters in 
            tide level partitions.

            Parameters
            ----------
            resids : pandas DataFrame
                The observed hourly non-tidal residuals (obs-[predictions+trend]).
            predictions : pandas DataFrame
                The tide predictions ???(with the sea level trend incorporated)???.
            prctile : int
                The percentile binning width (e.g. 10 means divide into 0-10,10-20, etc.)
                
            Returns
            -------
            dists : dict
                All of the tide level-distribution parameters. Fields are: 
                    pctile_mu : pandas DataFrame
                        Tide-level non-tidal residual mean.
                    pctile_sigma : pandas DataFrame
                        Tide-level non-tidal residual standard deviation.
            
            '''
            # Calculate the percentiles of the predictions #
            prctiles = np.percentile(predictions['val'].dropna(),np.arange(0,100+prctile,prctile))
            
            # Make the first and last percentiles much smaller and larger to
            # ensure the min/max values are captured by the percentiles #
            # IS THIS NEEDED? #
            prctiles[0] -= 1
            prctiles[-1] += 1
            
            # Calculate the mean and standard deviation of the residuals within
            # each tide level percentile. Pandas makes this easy (no loops). #
            resids['prctile bin'] = pd.cut(predictions['val'],bins=prctiles)
            prctile_mu_raw = resids.groupby('prctile bin')['val'].mean().reset_index()
            prctile_sigma_raw = resids.groupby('prctile bin')['val'].std().reset_index()
            
            # Take the mean and standard deviation values relative to the mean
            # and standard deviation values of the entire dataset #
            prctile_mu_rel = prctile_mu_raw['val'] - resids['val'].mean()
            prctile_sigma_rel = prctile_sigma_raw['val'] - resids['val'].std()
            prctile_mu = pd.DataFrame({'prctile bin':prctile_mu_raw['prctile bin'],
                                       'val':prctile_mu_rel})
            prctile_sigma = pd.DataFrame({'prctile bin':prctile_sigma_raw['prctile bin'],
                                       'val':prctile_sigma_rel})
            dists = {'prctile_mu':prctile_mu,
                     'prctile_sigma':prctile_sigma}
            return dists
        
    @staticmethod
    def damped_persistence(anom_mu):
        # Calculate the 95% confidence value for the autocorrelation for a
        # data record of the given length. #
        conf95 = np.sqrt(2)*scipy.special.erfcinv(2*.05/2)
        # Do the auto correlation calculation #
        if np.isnan(anom_mu['val'].iloc[0]): # If the dates are not round years (do not start in January) #
            r = scipy.signal.correlate(anom_mu['val'].dropna(),anom_mu['val'].dropna(),mode='same')
            lags = scipy.signal.correlation_lags(len(anom_mu.dropna()),len(anom_mu.dropna()))
            upconf = conf95/np.sqrt(len(anom_mu.dropna()))
        else:
            r = scipy.signal.correlate(anom_mu['val'].interpolate(),anom_mu['val'].interpolate(),mode='same')
            lags = scipy.signal.correlation_lags(len(anom_mu),len(anom_mu))
            upconf = conf95/np.sqrt(len(anom_mu.interpolate()))
        # Take only the values that are +/-12 lags (months) from the midpoint (0 lags)
        r = r[int(len(r)/2)-12:int(len(r)/2)+13]
        lags = lags[int(len(lags)/2)-12:int(len(lags)/2)+13]
        # Re-scale the r values so that r(0) = 1
        r = r/r[12]
        # Take only the positive part, from lag=1 month to lag=12 months #
        r = r[13:len(r)]
        lags = lags[13:len(lags)]
        # Take the damped persistance of each month to be the r values, until
        # the r value drops below the 95% confidence level. Once it does, set 
        # that and all remaining month values to 0. #
        not_significant = np.where(r<=upconf)[0]
        if len(not_significant>0):
            first = min(not_significant)
            r[first:len(r)] = 0
        return r
    
    @staticmethod
    def calc_persistence_apply(anom_preceeding,predictions,out_train):
        if np.isnan(anom_preceeding['val']) or predictions['time'].iloc[0]-anom_preceeding['time']>datetime.timedelta(days=31):
            print('Warning: No observed SL anomoly value for the month preceeding the '+
                 'first prediction month, using a previous month or climatology instead.')
            anom_prev = out_train['dists_time']['anom_mu'][out_train['dists_time']['anom_mu']['time']<predictions['time'].iloc[0]].iloc[-12:]
            anom_prev_valid = anom_prev.dropna()
            if len(anom_prev_valid)>0:
                iLastGood = int(np.where(anom_prev_valid['val'].iloc[-1]==anom_prev['val'])[0])           
                amlyApply=anom_prev.iloc[iLastGood]['val']
                dampedApply=np.zeros([12]);
                dampedApply[0:iLastGood+1]=out_train['damped_per'][11-iLastGood:12];
                persistence_apply = amlyApply*dampedApply;
            else:
                persistence_apply = np.zeros(12)
        else:
            persistence_apply = anom_preceeding['val']*out_train['damped_per']
        return persistence_apply
    
    @staticmethod
    def calc_dist_params(out_train,months,persistence_apply):
        mu = np.zeros([12,len(out_train['dists_tide']['prctile_mu'])])
        sigma = np.zeros([12,len(out_train['dists_tide']['prctile_mu'])])
        for i in range(len(months)):
            month = months[i]
            for j in range(len(out_train['dists_tide']['prctile_mu'])):
                mu[month-1,j] = out_train['dists_time']['month_mu'].iloc[month-1]['val'] + persistence_apply[i] + out_train['dists_tide']['prctile_mu'].iloc[j]['val']
                sigma[month-1,j] = out_train['dists_time']['month_sigma'].iloc[month-1]['val'] +  out_train['dists_tide']['prctile_sigma'].iloc[j]['val']
        return mu,sigma 
    
    @staticmethod
    def calc_cdf(px,mu,sigma):
        if np.size(mu) != np.size(sigma):
            raise ValueError('mu and sigma must be the same size')
        
        if np.size(mu)>1:
            cy = np.zeros([np.shape(mu)[0],np.shape(mu)[1],len(px)])
            for imo in np.arange(0,np.shape(cy)[0]):
                for itide in np.arange(0,np.shape(cy)[1]):
                    cdf = scipy.stats.norm.cdf(px,loc=mu[imo,itide],scale=sigma[imo,itide])
                    cy[imo,itide,:] = 1-cdf
        else:
            cdf = scipy.stats.norm.cdf(px,loc=mu[imo,itide],scale=sigma[imo,itide])
            cy[imo,itide,:] = 1-cdf            
                    
        return cy
    
    @staticmethod 
    def calc_freeboard(flood_thresh,pred_adj):
        freeboard = pred_adj.copy()
        freeboard['val'] = flood_thresh - pred_adj['val']
        return freeboard

    @staticmethod
    def calc_hourly_prob(cy,px,pred_adj,freeboard,dists_tide):
        '''
        Apply cdfs to determine probability that the NTR is >freeboard
        for each hourly observation 
        '''
        pctile_bins = [dists_tide['prctile_mu']['prctile bin'][i].left for i in range(len(dists_tide['prctile_mu']))]
        pctile_bins.append(dists_tide['prctile_mu']['prctile bin'][len(dists_tide['prctile_mu']['prctile bin'])-1].right)           
        freeboard['prctile bin'] = pd.cut(pred_adj['val'],
                                         bins=pctile_bins,
                                         labels=False)
        freeboard['month bin'] = pd.cut(pred_adj['time'].dt.month,
                                         bins=np.arange(1,14),
                                         right=False,labels=False)
        def find_ipx(val):
            if not np.isnan(val):
                return min(np.where(px>val)[0])
            else:
                return np.nan
        freeboard['ipx'] = freeboard['val'].apply(find_ipx)
        
        prob_hourly1 = cy[freeboard['month bin'],
           freeboard['prctile bin'].fillna(0).astype(int),
           freeboard['ipx'].fillna(0).astype(int)]
        prob_hourly1[np.isnan(freeboard['val'])] = np.nan
        
        prob_hourly = pred_adj.copy()
        prob_hourly['val'] = prob_hourly1
        
        return prob_hourly
    
    @staticmethod
    def calc_daily_prob(prob_hourly,freeboard,resids):
    
        # Do the auto correlation calculation #
        r = scipy.signal.correlate(scipy.signal.detrend(resids['val'].interpolate()),scipy.signal.detrend(resids['val'].interpolate()),mode='same')
        lags = scipy.signal.correlation_lags(len(resids),len(resids),mode='same')
        
        # Take only the values that are +/-12 lags (months) from the midpoint (0 lags)
        r = r/max(r)
        r = r[int(len(r)/2)-24:int(len(r)/2)+25]
        lags = lags[int(len(lags)/2)-24:int(len(lags)/2)+25]
        r[24] = 0
        r = 1-r # The coefficient we want is the fraction that is uncorrelated #
        
        # Calculate daily cumulative probability
        yrmodays = prob_hourly['time'].dt.normalize()
        t_day = []
        prob_day = []
        freeboard_daily_max = []
        for d in yrmodays.unique():
            iThisDay = yrmodays==d
                     
            freeboard_daily_max.append(np.max(-1*freeboard['val'][iThisDay]))
            ifreeboard_daily_max = np.argmax(-1*freeboard['val'][iThisDay])
            t_day.append(freeboard['time'][iThisDay].iloc[0])
            
            r_sub = r[24-ifreeboard_daily_max:24-ifreeboard_daily_max+24]
            
            independent_frac = 1 - prob_hourly['val'][iThisDay] * r_sub
            
            prob_day.append(1 - np.prod(independent_frac))
        
        prob_daily = pd.DataFrame({'time':t_day,
                                   'val':prob_day,
                                   'max freeboard':freeboard_daily_max})
        
        return prob_daily
    
    @staticmethod
    def calc_observed_floods(data):
        yrmodays = data['hourly_height']['time'].dt.normalize()
        yn = []
        for d in yrmodays.unique():
            iThisDay = yrmodays==d
            freeboard_day = data['Flood thresh'] - data['hourly_height']['val'][iThisDay]
            if np.nanmin(freeboard_day)<=0:
                yn.append(1)
            else:
                yn.append(0)
                
        observed_floods = pd.DataFrame({'time':yrmodays.unique(),
                                        'val':yn})
        return observed_floods
    
    class brier_stats:
        def __init__(self,obs,pred):
            self.obs = obs
            self.pred = pred
            
        def calc_bs(self,obs,pred):
            return np.nanmean(np.square(pred['val']-obs['val']))
        
        def calc_bss(self,bs,obs,clim):
            bs_clim = self.calc_bs(obs,clim)
            bss = 1-(bs/bs_clim)
            return bss               
    
        def run(self):            
            bs = self.calc_bs(self.obs,self.pred)
            
            clim = self.obs.copy()
            clim['val'] = np.ones_like(self.obs['val'])*np.nanmean(self.obs['val'])
            bss = self.calc_bss(bs,self.obs,clim)
            
            n = len(self.obs)
            mean_obs = self.obs['val'].mean()
            var_obs = self.obs['val'].mean()*(1-self.obs['val'].mean())
            m1_1 = self.calc_moment(self.obs,self.pred,m=1,yn=1)
            m2_1 = self.calc_moment(self.obs,self.pred,m=2,yn=1)
            m2_0 = self.calc_moment(self.obs,self.pred,m=2,yn=0)
            m3_1 = self.calc_moment(self.obs,self.pred,m=3,yn=1)
            m4 = self.calc_moment(self.obs,self.pred,m=4,yn=None)
            d1,d2,d3 = self.calc_dcoefs(var_obs,n,bss)
            var_mse,var_var,cov_mse,var_bss = self.calc_quantities(mean_obs,var_obs,n,bs,
                                                      m1_1,m2_1,m2_0,m3_1,m4,
                                                      d1,d2,d3)
            bs_se,bss_se = self.calc_se(var_mse,var_bss)
            
            return bs,bss,bs_se,bss_se
            
        
        @staticmethod
        def calc_moment(obs,pred,m,yn):
            if yn:
                return np.nanmean(pred['val'][obs['val']==yn]**m)
            else:
                return np.nanmean(pred['val']**m)
        
        @staticmethod
        def calc_dcoefs(var_obs,n,bss):
            d1=(1/(var_obs**2))*((n/(n-1))**2)
            d2=(((1-bss)**2)/(var_obs**2))*((n/(n-1))**4)
            d3=(-2*(1-bss)/(var_obs**2))*((n/(n-1))**3)
            return d1,d2,d3
        
        @staticmethod
        def calc_quantities(mean_obs,var_obs,n,bs,m1_1,m2_1,m2_0,m3_1,m4,d1,d2,d3):
            var_mse = 1/n * (m4+mean_obs*(1-4*m3_1+6*m2_1-4*m1_1)-bs**2)
            var_var = ((n-1)/(n**3)) * ((n-1) + var_obs*(6-4*n)) * var_obs
            cov_mse = ((n-1)/(n**2)) * var_obs * (1-2*mean_obs) * ((m2_1-m2_0) + (1-2*m1_1))
            var_bss = np.abs(d1*var_mse + d2*var_var + d3*cov_mse)
            return var_mse,var_var,cov_mse,var_bss
        
        @staticmethod
        def calc_se(var_mse,var_bss):
            bs_se = var_mse**0.5
            bss_se = var_bss**0.5
            return bs_se,bss_se

    @staticmethod
    def calc_reliability(obs,pred):
        bins = np.arange(0,1.1,.1)
        pred['bin'] = pd.cut(pred['val'],bins=bins,right=False)
        obs['bin'] = pd.cut(pred['val'],bins=bins,right=False)       
        resolution =  pred.groupby('bin').size() / len(pred)
        reliability = obs.groupby('bin').mean()['val']
        return resolution,reliability
    
    @staticmethod
    def calc_confusion_stats(obs,pred,min_prob=0.05):
        
        # Find where the predicted daily probaability is > min_prob #
        pred['exceeded thresh'] = (pred['val']>min_prob).astype(int)
        
        # Generate a confusion matrix based on these predicted flood days
        C = confusion_matrix(obs['val'],pred['exceeded thresh'])
        n_true_neg = C[0,0]
        n_true_pos = C[1,1]
        n_false_neg = C[1,0]
        n_false_pos = C[0,1]
        
        # Calculate stats #
        accuracy = (n_true_pos+n_true_neg) / len(pred)
        precision = n_true_pos / (n_true_pos+n_false_pos)
        recall = n_true_pos / (n_true_pos+n_false_neg)
        false_alarm = n_false_pos / (n_true_neg+n_false_pos)
        F1 = 2 * ((precision*recall)/(precision+recall));

        return accuracy,precision,recall,false_alarm,F1

class CoraEngine(HTF_model):
    @staticmethod
    def get_timeseries(latlon,dt_start,dt_end,cora_data_dir,retrend): 
        if cora_data_dir is None or not os.path.exists(cora_data_dir+'/CORA_'+str(latlon[0])+'_'+str(latlon[1])+'_1979_2022.pkl'):
            print('Downloading CORA output. This takes a very long time...')
            catalog = intake.open_catalog("s3://noaa-nos-cora-pds/CORA_intake.yml",storage_options={'anon':True})
            ds = catalog['CORA-V1-500m-grid-1979-2022'].to_dask()       
            d = np.array(utils.haversine(ds['lat'],ds['lon'],latlon[0],latlon[1]))
            # Get the spatial index and time slice indices #
            i_d = int(np.where(d==min(d))[0])
            i_t_start = int(np.where(ds['time']==np.datetime64(dt_start))[0])
            i_t_end = int(np.where(ds['time']==np.datetime64(dt_end))[0])
            # Slice the data #
            z = ds['zeta'][i_t_start:i_t_end+1,i_d]
            t = ds['time'][i_t_start:i_t_end+1]
            # Load the data into memory #
            hourly_height = pd.DataFrame({'time':[],
                                'val':[]})
            chunk_size = 1000
            for i in range(0, len(t), chunk_size):
                tc = t[i:i + chunk_size].compute()
                zc = z[i:i + chunk_size].compute()
                df = pd.DataFrame({'time':tc,
                                   'val':zc})
                hourly_height = pd.concat([hourly_height,df],ignore_index=True)
        else:
            print('Loading saved CORA timeseries...')
            f = open(cora_data_dir+'/CORA_'+str(latlon[0])+'_'+str(latlon[1])+'_1979_2022.pkl','rb')
            ts = pickle.load(f)
            ts = CoraEngine.temp_retrend(ts,retrend)
            ts = ts[ts['time']>=dt_start]
            ts = ts[ts['time']<=dt_end]
            ts = ts.reset_index(drop=True)
            hourly_height = ts                
        return hourly_height

    @staticmethod
    def calc_datums(hourly_height,latlon,cora_data_dir):
        print('Calculating datums with the CO-OPS Tidal Analysis Datum Calculator...')
        # if cora_data_dir is None or not os.path.exists(cora_data_dir+'/CORA_'+str(latlon[0])+'_'+str(latlon[1])+'_1979_2022_datums.pkl'):
        datums_cora = TadcInterface(hourly_height,latlon[0],latlon[1]).run()
        with open(cora_data_dir+'/CORA_'+str(latlon[0])+'_'+str(latlon[1])+'_1979_2022_datums.pkl','wb') as f:
            pickle.dump(datums_cora,f)
        # else:
            # f = open(cora_data_dir+'/CORA_'+str(latlon[0])+'_'+str(latlon[1])+'_1979_2022_datums.pkl','rb')
            # datums_cora = pickle.load(f)
        return datums_cora
    
    @staticmethod
    def msl2mhhw(hourly_height_msl,datums_msl):
        mhhw = float(datums_msl[datums_msl['datum']=='MHHW']['value'])
        hourly_height_mhhw = hourly_height_msl.copy()
        hourly_height_mhhw['val'] = hourly_height_mhhw['val']-mhhw
        datums_mhhw = datums_msl.copy()
        for datum in datums_mhhw['datum']:
            datums_mhhw.loc[np.where(datums_mhhw['datum']==datum)[0][0],'value'] = datums_mhhw.loc[np.where(datums_mhhw['datum']==datum)[0][0],'value']-mhhw
        return hourly_height_mhhw,datums_mhhw
        
    @staticmethod
    def calc_predictions(hourly_height,latlon,time_recon,cora_data_dir,datums_msl):
        print('Calculating tidal constituents and predictions...')
        # Detrend #
        ig = np.where(~np.isnan(hourly_height['val']))
        t = (hourly_height['time'].iloc[ig]-hourly_height['time'].iloc[ig].iloc[0]).dt.seconds
        slope,intercept,r_value,p_value,std_err = scipy.stats.linregress(t,hourly_height['val'].iloc[ig])
        ts_detrend = hourly_height.copy()
        ts_detrend['val'].iloc[ig] = ts_detrend['val'].iloc[ig]-((t*slope)+intercept)
        # Deconstruct to get constituents #
        coef = utide.solve(ts_detrend['time'],ts_detrend['val'],
                           lat=latlon[0],nodal=True,trend=False,method='ols',
                           conf_int='linear',Rayleigh_min=0.95)
        # Reconstruct for the desired period #
        predictions = utide.reconstruct(time_recon,coef)
        predictions = pd.DataFrame({'time':time_recon,
                                    'val':predictions['h']-float(datums_msl[datums_msl['datum']=='MHHW']['value'])})      
        return predictions
    
    @staticmethod
    def temp_retrend(hourly_height,trend):
        if trend is not None:
            # Detrend the CORA timeseries #
            td = (hourly_height['time'].dt.to_pydatetime()-hourly_height['time'].dt.to_pydatetime()[0])
            tds = np.array([td[i].total_seconds() for i in range(len(hourly_height))])
            slope,intercept,r_value,p_value,std_err = scipy.stats.linregress(tds[~np.isnan(hourly_height['val'])],hourly_height['val'][~np.isnan(hourly_height['val'])])             
            hourly_height_dt = hourly_height.copy()
            hourly_height_dt['val'] = hourly_height['val']-(tds*slope)
            # Put the desired trend in #
            hourly_height_rt = hourly_height.copy()
            hourly_height_rt['val'] = hourly_height_dt['val']+(tds*trend)
            return hourly_height_rt
        else:
            return hourly_height
             
    @staticmethod
    def calc_slt(hourly_height):
        print('Computing the sea level trend...')
        def calc_seasonal_cycle(hourly_height):
            months = hourly_height['time'].dt.month
            month_avgs = []
            for month in np.arange(1,13):
                month_avgs.append(hourly_height['val'][months==month].mean())
            seasonal_cycle = pd.DataFrame({'time':np.arange(1,13),'val':month_avgs})
            return seasonal_cycle
        
        def calc_monthly_means(hourly_height):
            yrmos_all = hourly_height['time'].dt.to_period('M')
            vals = []
            for yrmo in yrmos_all.unique():
                vals.append(hourly_height['val'][yrmos_all==yrmo].mean())
            monthly_means = pd.DataFrame({'time':yrmos_all.unique(),'val':vals})
            return monthly_means
        
        seasonal_cycle = calc_seasonal_cycle(hourly_height)
        monthly_means = calc_monthly_means(hourly_height)
        use = monthly_means.copy()
        use['val'] = monthly_means['val'].values-np.tile(seasonal_cycle['val'],[1,int(len(monthly_means)/len(seasonal_cycle))]).reshape(-1,1)
        td = np.hstack([0,np.cumsum(np.ones_like(use['val'])*(1/12))])[0:-1] # Array of fractional years #
        slope,intercept,rvalue,pvalue,stderr = scipy.stats.linregress(td[~np.isnan(monthly_means['val'])],monthly_means['val'][~np.isnan(monthly_means['val'])])
        slt = slope*1000 # convert to mm/yr #       
        # td = (hourly_height['time'].dt.to_pydatetime()-hourly_height['time'].dt.to_pydatetime()[0])
        # tds = np.array([td[i].total_seconds() for i in range(len(hourly_height))])
        # slope,intercept,rvalue,pvalue,stderr = scipy.stats.linregress(tds[~np.isnan(hourly_height['val'])],hourly_height['val'][~np.isnan(hourly_height['val'])])
        # slt = (slope*1000)*60*60*24*365 # Convert m/s to mm/yr #
        # slt = 2.4163
        return slt
    
    @staticmethod
    def calc_epoch_center(years):
        # print('Assigning the epoch center as the middle of the dates')
        # y1 = utils.datestr2dt(str(years[0]))
        # y2 = utils.datestr2dt(str(years[1]))
        # dt = y2-y1
        # mid = y1+(dt/2)
        # epoch_center = utils.dt2decimalyr(mid)
        print('Assigning epoch center of the 1979-2022 data as 1992.5')
        epoch_center = 1992.5
        return epoch_center
    
    @staticmethod
    def calc_flood_thresh(datums,thresh_type,thresh_rel):
        print('Getting the flood threshold')
        if thresh_type == 'NOS':
            thresh_mllw = (1.04*float(datums[datums['datum']=='GT']['value']))+0.5
            conversion = float(datums[datums['datum']=='MHHW']['value']) - float(datums[datums['datum']=='MLLW']['value'])
            thresh1 = thresh_mllw-conversion
        else:
            thresh1 = float(datums[datums['datum']==thresh_type]['value'])
        thresh = thresh1+thresh_rel
        return thresh

class ApiInterface:
    '''
    Class to download data from CO-OPS API. Class allows request of 
    multiple datasets over the same time period.

    Parameters
    ----------
    station: INT
        The NWLONS station ID
    begin_date: STR
        The begin date for data retrieval, in the format 'yyyymmdd' (e.g. '20200101')
    end_date: STR
        The end date for data retrieval, in the format 'yyyymmdd' (e.g. '20231231')
    product: STR or list of STR
        The water level, met, or oceanographic product of interst.
        The choices are:
        'water_level' - Prelim or verified water levels
        'air_temperature' - Air temp as measured
        'water_temperature' - Water temp as measured
        'wind' - Wind Speed, direction, and gusts as measured
        'air_pressure' - Barometric pressure as measured
        'air_gap' - Air Gap at the station
        'conductivity' - water conductivity
        'visibility' - Visibility
        'humidity' - relative humidity
        'hourly_height' - Verified hourly height data
        'high_low' - verified high/low water level data
        'daily_mean' - verified daily mean water level data
        'monthly_mean' - Verified monthly mean water level data
        'one_minute_water_level' - One minute water level data
        'predictions' - 6 minute predicted water level data
        'datums' - accepted datums for the station
        'currents' - Current data for thee current station
        DEFAULT = 'water_level'
    units : STR
        The type of units to use. Either 'english' or 'metric'
        DEFAULT = 'metric'
    datum_bias: STR
        The datum to which to bias the data to. Options are 
        'MHHW' - mean higher high water
        'MHW' - mean high water
        'MTL' - mean tide level
        'MSL' - mean sea level
        'MLW' - mean low water
        'MLLW' - mean lower low water
        'NAVD' - North American Veritcal Datum of 1988
        'STND' - station datum
        DEFAULT = 'MHHW'
    time_zone: STR
        The time zone for the data. Options are:
        'gmt' - Greenwich Mean Time
        'lst' - local standard time
        'lst_ldt' - Local Standard or Local daylight, depending on time of year
         DEFAULT = 'gmt'

    Returns
    -------
    None.

    '''
    def __init__(self,station,begin_date,end_date,product='water_level',units='metric',
                     datum_bias='MHHW',time_zone='gmt'):
        self.station = station
        self.begin_date = begin_date
        self.end_date = end_date
        self.product = product
        self.units = units
        self.datum_bias = datum_bias
        self.time_zone = time_zone
               
    def download_and_format(self):
        if not isinstance(self.product, list):
            self.product = [self.product]
            
        data_all = {}
        for prod in self.product:         
            # If requesting an hourly or 6-minute product, there is a 30 day max interval for retrieval. 
            # So need to loop through each month of the interval to download and then
            # smoosh it all together #
            cond1 = (prod=='water_level' or prod=='hourly_height' or prod=='predictions')
            cond2 = utils.datestr2dt(self.end_date)-utils.datestr2dt(self.begin_date)>datetime.timedelta(days=30)
            if cond1 and cond2:
                # Get the start and end datetimes #
                begin_dt = utils.datestr2dt(self.begin_date)
                end_dt = utils.datestr2dt(self.end_date)
                # Force the end datetime to be at the end of the requested day #
                if prod=='water_level':
                    end_dt = datetime.datetime(end_dt.year,end_dt.month,end_dt.day,23,54)
                else:
                    end_dt = datetime.datetime(end_dt.year,end_dt.month,end_dt.day,23,0)
                # Generate a list of interval datetimes between start and end #
                datetimes_list = []
                current_datetime = begin_dt
                while current_datetime <= end_dt:
                    datetimes_list.append(current_datetime)
                    current_datetime += datetime.timedelta(days=30)
                datetimes_list.append(end_dt)
                # Download data for each datetime interval and put into a DataFrame #
                for i in range(len(datetimes_list)-1):                 
                    begin_dt_interval = datetimes_list[i]
                    end_dt_interval = datetimes_list[i+1]
                    url = self.build_url_dapi(str(self.station),utils.dt2datestr(begin_dt_interval),
                                    utils.dt2datestr(end_dt_interval),product=prod,
                                    units=self.units,datum_bias=self.datum_bias,
                                    time_zone=self.time_zone)
                    content = self.request_data(url)
                    data1 = self.format_content_dapi(content)
                    if i==0:
                        data = data1
                    else:
                        data = pd.concat([data,data1],ignore_index=True)
                data = data.drop_duplicates(subset='time', keep='first')
                data = self.fill_gaps(data,begin_dt,end_dt)              
            else:
                if prod in ['datums','supersededdatums','harcon','sensors','details',
                                   'notices','disclaimers','benchmarks','tidepredoffsets',
                                   'floodlevels']:
                     url = self.build_url_mdapi(str(self.station),
                                                None,None,product=prod,units=self.units)
                     content = self.request_data(url)
                     data = self.format_content_mdapi(content)
                elif prod in ['sealvltrends']:
                     url = self.build_url_dpapi(str(self.station),
                                                None,None,product=prod)
                     content = self.request_data(url)
                     data = self.format_content_dpapi(content)
                else:
                    url = self.build_url_dapi(str(self.station),self.begin_date,
                                    self.end_date,product=prod,
                                    units=self.units,datum_bias=self.datum_bias,
                                    time_zone=self.time_zone)
                    content = self.request_data(url)
                    data = self.format_content_dapi(content)
                    data = self.fill_gaps(data,utils.datestr2dt(self.begin_date),utils.datestr2dt(self.end_date))
                     
            data_all[prod] = data
            
        return data_all
                               
    def run(self):
        data = self.download_and_format()
        return data


    @staticmethod
    def build_url_dapi(station,begin_date,end_date,product='water_level',units='metric',
                     datum_bias='MHHW',time_zone='gmt'):
        
        # CO-OPS API server #
        server = 'https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?'
        
        if product=='predictions':
            url = (server + 'begin_date=' + begin_date +'&end_date=' + end_date +'&station=' + str(station) +
                 '&product=' + product +'&datum=' + datum_bias + '&time_zone=' + time_zone + '&units=' + 
                 units + '&format=json' +'&interval=h')
        else:
            url = (server + 'begin_date=' + begin_date +'&end_date=' + end_date +'&station=' + str(station) +
                 '&product=' + product +'&datum=' + datum_bias + '&time_zone=' + time_zone + '&units=' + 
                 units + '&format=json')
        
        return url

    @staticmethod
    def build_url_mdapi(station,begin_date=None,end_date=None,product='details',units='metric'):
        
        # CO-OPS metadata API server #
        server = 'https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations/'
        
        url = (server + str(station) + '/'+product+'.json?units='+units)
    
        return url  
    
    @staticmethod
    def build_url_dpapi(station,begin_date=None,end_date=None,product='sealvltrends'):
        
        # CO-OPS metadata API server #
        server = 'https://api.tidesandcurrents.noaa.gov/dpapi/prod/webapi/product/'
        
        url = (server + product + ".json?station=" + str(station) + "&affil=us")
    
        return url   
    
    @staticmethod
    def request_data(url):
        content = requests.get(url).json()
        return content
    
    @staticmethod 
    def format_content_dapi(content):
        if len(content)>1 or list(content.keys())[0]=='predictions': # len=1 indicates no data was found (just an eror message returned) #
            data_raw = content[list(content.keys())[-1]]
            data1 = []
            for val in ['t','v']:
                data1.append([data_raw[i][val] for i in range(len(data_raw))])
            data_arr = np.array(data1).T
            data_dict = {'time':[utils.datestr2dt(data_arr[i,0]) for i in range(len(data_arr))],
                    'val':[float(data_arr[i,1]) if len(data_arr[i,1])>0 else np.nan for i in range(len(data_arr))] }
        else:
            data_dict = {'time':[],
                    'val':[]}
                   
        return pd.DataFrame(data_dict)
    
    @staticmethod 
    def format_content_mdapi(content):
        data_dict = {}
        for key in list(content.keys()):
            data_dict[key] = content[key]
        return data_dict

    @staticmethod 
    def format_content_dpapi(content):
        data_dict = content[list(content.keys())[-1]]
        return data_dict
    
    @staticmethod
    def fill_gaps(data,begin_date,end_date):
        def create_fillseries(tstart,tend,dt):
            fill = pd.date_range(start=tstart, end=tend, freq=dt)
            fill2 = pd.DataFrame({'time':fill,'val':np.empty(len(fill))*np.nan})
            return fill2          
        data = data.reset_index(drop=True)
        # Get the data time interval #
        dt = data['time'][1]-data['time'][0] # This assumes there is no missing data between the first two entries #
        # Find gaps as those where the time between two values is > dt
        tdif = [data['time'][i+1]-data['time'][i] for i in range(len(data['time'])-1)]
        jumps = np.where(np.array(tdif)!=dt)[0]
        # For each gap, create a dummy vector to fill the gap at dt spacing.
        # Save all of these to insert later #
        fill_all = []
        for jump in jumps:
            t1 = data['time'][jump]
            t2 = data['time'][jump+1]
            fill = create_fillseries(t1+dt,t2-dt,dt)
            fill_all.append(fill)
        # Insert the dummy fill dfs into the data df. Do this working last-to-first
        # so we don't have to worry about re-indexing after inserting #
        for i in np.arange(len(fill_all)-1,-1,-1):
            insert_index = jumps[i]+1
            data_before = data.iloc[:insert_index]
            data_after = data.iloc[insert_index:]
            data = pd.concat([data_before, fill_all[i], data_after], ignore_index=True)
        # Now also need to make sure the start and end points requested have data,
        # if not need to fill to there #
        tf_start = data['time'].iloc[0]==begin_date
        tf_end = data['time'].iloc[-1]==end_date
        if not tf_start:
            fill = create_fillseries(begin_date,data['time'].iloc[0]-dt,dt)
            data = pd.concat([fill,data], ignore_index=True)
        if not tf_end:
            fill = create_fillseries(data['time'].iloc[-1]+dt,end_date, dt)
            data = pd.concat([data,fill], ignore_index=True)     
            
        return data


class TadcInterface(): 
    def __init__(self,ts,lat,lon):
        self.ts = self.prep_data(ts)
        self.lat = lat
        self.lon = lon
        self.path = pkg_resources.resource_filename(__name__, 'lib/CO-OPS-Tidal-Analysis-Datum-Calculator/')

    
    def run(self):
        self.make_TADC_data(self.ts)
        self.make_TADC_config()
        self.run_tadc()
        datums = self.parse_TADC_out()
        return datums
    
    def prep_data(self,ts):
        # if len(np.where(np.isnan(ts['val']))[0])/len(ts)*100<5:
            # Detrend, manually with a linear regression #
            t = np.array((ts['time']-ts['time'].iloc[0]).dt.total_seconds())
            m,b,r_val,p_val,std_err = scipy.stats.linregress(t[~np.isnan(ts['val'])],ts['val'][~np.isnan(ts['val'])])
            ts_dt = ts.copy()
            ts_dt = ts['val'] - (b+(m*t))
            # Add the mean back to the detrended data #
            ts_dt_withmean = ts_dt+np.nanmean(ts['val'])
            # Fill NaNs with the mean of the original timeseries #
            ts_dt_withmean_nanfilled = ts_dt_withmean.copy()
            ts_dt_withmean_nanfilled[np.isnan(ts_dt_withmean_nanfilled)] = np.nanmean(ts['val'])       
            ts_prepped = ts.copy()
            ts_prepped['val'] = ts_dt_withmean_nanfilled
            # Interpolate to even hourly spacing #
            ts_prepped = utils.interpolate_ts(ts_prepped,
                                              ts_prepped['time'].iloc[0].to_pydatetime(),
                                              ts_prepped['time'].iloc[-1].to_pydatetime().replace(hour=23,minute=0,second=0))
            return ts_prepped
        # else:
            # raise ValueError('Hourly height timeseries contains >5% NaNs')
            
    def make_TADC_data(self,ts):
        ts.to_csv(self.path+'ts.csv',index=False)

    def make_TADC_config(self):
        fs = self.path+'config.cfg'
        with open(fs) as f:
            lines = f.readlines()
            lines[22] = 'fname = ts.csv\n'
            lines[26] = 'control_station =  \n'
            lines[48] = 'subordinate_lon = '+str(self.lon)+'\n'
            lines[53] = 'subordinate_lat = '+str(self.lat)+'\n'   
        with open(fs, 'w') as f:
            for line in lines:
                f.write(f'{line}')
    
    def run_tadc(self):
        subprocess.run('cd '+self.path+' && python SDC.py',shell=True,capture_output=True)
                
    def parse_TADC_out(self):
        fs = self.path+'SDC.out' 
        with open(fs) as f:
            lines = f.readlines()
        lstart = [l for l in range(len(lines)) if lines[l][0:3]=='HWL'][0]
        lend = [l for l in range(len(lines)) if lines[l][0:3]=='LWL'][0]+1
        lines = lines[lstart:lend]
        datums = pd.DataFrame({'datum':[],'value':[]})
        for l in lines:
            d = l.replace('\n','').split(' ')[0]
            for i in np.arange(1,len(l.replace('\n','').split(' '))):
                try:
                    v = float(l.replace('\n','').split(' ')[i])
                except:
                    pass
                else:
                    break
            datums = pd.concat([datums,pd.DataFrame({'datum':[d],'value':[v]})],ignore_index=True)
        return datums
    

      
class utils:   
    @staticmethod
    def load_data(station):
        '''
        Function to get data for the station that, rather than being available
        via the CO-OPS API, comes bundled with this package in /data.

        Returns
        -------
        dfi : Pandas DataFrame
            All of the other data for the station, including sea level trend 
            and flood thresholds.

        '''
        data_path = pkg_resources.resource_filename(__name__, 'data/HighTideOutlookStationList_05_17_23_PAC_SLT.csv')
        df = pd.read_csv(data_path)
        dfi = df[df['St ID']==station].reset_index(drop=True)
        return dfi
    
    @staticmethod
    def datestr2dt(datestr):
        if len(datestr)==8:
            return datetime.datetime(int(datestr[0:4]),int(datestr[4:6]),int(datestr[6:8]))
        elif len(datestr)==16:
            return datetime.datetime(int(datestr[0:4]),int(datestr[5:7]),int(datestr[8:10]),int(datestr[11:13]),int(datestr[14:16]))
        
    @staticmethod
    def dt2datestr(dt):
        mo = dt.month
        day = dt.day
        if mo<10:
            smo = '0'
        else:
            smo = ''
        if day<10:
            sday = '0'
        else:
            sday = ''
        return str(dt.year)+smo+str(dt.month)+sday+str(dt.day)   
    
    @staticmethod
    def dt2decimalyr(dt):
        yr_ref = datetime.datetime(dt.year,1,1)
        time_delta = dt-yr_ref
        frac1 = time_delta.days/365.2425
        frac2 = time_delta.seconds/(60*60*24*365.2425)
        frac = frac1+frac2
        decimalyr = dt.year+frac
        return decimalyr
        

    @staticmethod
    def haversine(lat1, lon1, lat2, lon2):
        lat1, lon1, lat2, lon2 = map(np.radians, [lat1, lon1, lat2, lon2])
        R = 6371 
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        a = np.sin(dlat/2.0)**2 + np.cos(lat1) * np.cos(lat2) * np.sin(dlon/2.0)**2
        c = 2 * np.arcsin(np.sqrt(a))
        km = R * c
        return km        

    @staticmethod
    def interpolate_ts(ts,dt_start,dt_end):
        ti = pd.date_range(dt_start,dt_end,freq='h')
        zi = np.interp(ti,ts['time'],ts['val'])
        tsi = pd.DataFrame({'time':ti,'val':zi})       
        return tsi      
    
    @staticmethod
    def datumlist2datumval(datums,datum_want):
        val = np.array(datums)[np.array([datums[i]['name'] for i in range(len(datums))]) == datum_want][0]['value']
        return val
        
        
        

        
        
        
            
            
            
            
    
