# -*- coding: utf-8 -*-
"""
Created on Mon Sep  9 14:17:12 2024

@author: Matthew.Conlin
"""

import matplotlib.pyplot as plt
import numpy as np
from HTF import HTF_model

stations = [8670870,8665530,8651370]
skill_dusek = []
skill_xvalid = []
for station in stations:
    print('Working on station '+str(station))
    model_dusek = HTF_model(station,
                    years_fit=[19830101,20011231],
                    years_assess=[19830101,20011231],
                    years_pred=None,
                    assess_method='DusekEtAl',
                    assess_metric='htf_days',
                    fold_size=2,
                    prctile_bin_val='pred_adj',
                    cora_data_dir=None)
    model_dusek.train()
    model_dusek.assess()


    model_xvalid = HTF_model(station,
                    years_fit=[19830101,20011231],
                    years_assess=[19830101,20011231],
                    years_pred=None,
                    assess_method='cross_validation',
                    assess_metric='htf_days',
                    fold_size=2,
                    prctile_bin_val='pred_adj',
                    cora_data_dir=None)
    model_xvalid.train()
    model_xvalid.assess()

    skill_dusek.append(model_dusek.out_assess['f(lead)'].iloc[0]['out_assess'])
    skill_xvalid.append(model_xvalid.out_assess)
    

fig,ax = plt.subplots(1,figsize=(4,3))
plt.subplots_adjust(left=0.2,bottom=0.15,top=0.95,right=0.95)
ax.tick_params(axis='both',labelsize=8)
ax.bar(np.arange(1,len(stations)+1),
       [skill_dusek[i]['bss'] for i in range(len(stations))],
       width=-0.2,align='edge',label='Dusek')
ax.bar(np.arange(1,len(stations)+1),
       [skill_xvalid[i]['bss'] for i in range(len(stations))],
       width=0.2,align='edge',label='xValid')
ax.set_xticks(np.arange(1,len(stations)+1))
ax.set_xticklabels(stations)
ax.legend(fontsize=8)
ax.set_ylabel('BSS',fontsize=8)


