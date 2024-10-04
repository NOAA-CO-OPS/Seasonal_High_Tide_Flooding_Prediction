# -*- coding: utf-8 -*-
"""
Created on Mon Sep  9 14:17:12 2024

@author: Matthew.Conlin
"""

from HTF import HTF_model

stations = [8670870,8665530,8661070,8658163,8651370]
bss_dusek = []
bss_xvalid = []
for station in stations:
    model_dusek = HTF_model(8665530,
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


    model_xvalid = HTF_model(8665530,
                    years_fit=[19830101,20011231],
                    years_assess=[19830101,20011231],
                    years_pred=[20020101,20021231],
                    assess_method='cross_validation',
                    assess_metric='htf_days',
                    fold_size=2,
                    prctile_bin_val='pred_adj',
                    cora_data_dir=None)
    model_xvalid.train()
    model_xvalid.assess()

    skill_dusek = model_dusek.out_assess['f(lead)'].iloc[0]['out_assess']
    skill_xvalid = model_xvalid.out_assess
    
    bss_dusek.append(skill_dusek['bss'])
    bss_xvalid.append(skill_xvalid['bss'])



