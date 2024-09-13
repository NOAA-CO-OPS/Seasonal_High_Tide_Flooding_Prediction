# -*- coding: utf-8 -*-
"""
Created on Mon Sep  9 14:17:12 2024

@author: Matthew.Conlin
"""

from junk.HTF_testing_allow_cora_input_allow_thresh_input import HTF_model
from matplotlib.patches import Rectangle
import matplotlib.pyplot as plt
import numpy as np

model_dusek = HTF_model(8665530,
                years_fit=[19830101,20011231],
                years_assess=None,
                years_pred=[20020101,20021231],
                assess_method='DusekEtAl',
                assess_metric='htf_days',
                fold_size=1,
                prctile_bin_val='pred_adj')
model_dusek.train()
model_dusek.assess()

model_xvalid = HTF_model(8665530,
                years_fit=[19830101,20011231],
                years_assess=None,
                years_pred=[20020101,20021231],
                assess_method='cross_validation',
                assess_metric='htf_days',
                fold_size=2,
                prctile_bin_val='pred_adj')
model_xvalid.train()
model_xvalid.assess()

fig,ax = plt.subplots(1)
ax.set_xlim(1983,2002)
for i in range(len(model_xvalid.skill)):
    r = Rectangle((1983+(2*i),model_xvalid.skill[i]['bss']),2,0,facecolor='k',edgecolor='k')
    ax.add_patch(r)
bss_all = np.array([model_xvalid.skill[i]['bss'] for i in range(len(model_xvalid.skill))])
bss_mean = np.mean(bss_all[~np.isinf(bss_all)])
ax.plot([1983,2002],[bss_mean,bss_mean],'k--')    
ax.plot([1983,2002],[model_dusek.skill['bss'],model_dusek.skill['bss']],'r--')    



