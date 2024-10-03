# -*- coding: utf-8 -*-
"""
Created on Tue Oct  1 13:47:35 2024

@author: Matthew.Conlin
"""

from HTF.HTF import HTF_model
import matplotlib.pyplot as plt
import numpy as np

thresh_vals = np.arange(-0.5,0.5,0.1)
skill = []
for thresh_rel_mhhw in thresh_vals:
    model = HTF_model(loc=8665530,
    		years_fit=[19830101,20011231],
    		years_assess=[19830101,20011231],
    		years_pred=[20020101,20021231],
            thresh_type='MHHW',
            thresh_rel=thresh_rel_mhhw,
    		assess_method='DusekEtAl',
    		assess_metric='htf_days',
    		fold_size=None,
    		prctile_bin_val='pred_adj',
            cora_data_dir=None)

    model.train()
    model.assess()
    skill.append(model.out_assess)
    
fig,ax = plt.subplots(1,figsize=(4,2))
ax.set_title('NWLON 8665530 Charleston Harbor, SC',fontsize=8,fontweight='normal')
plt.subplots_adjust(bottom=0.2)
ax.plot(thresh_vals,[skill[i]['bss'] for i in range(len(skill))],'.-')
ax.grid('on')
ax.set_xlabel('Threshold relative to MHHW (m)',fontsize=8)
ax.set_ylabel('BSS',fontsize=8)
ax.tick_params(axis='both',labelsize=8)


    
    