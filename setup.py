# -*- coding: utf-8 -*-
"""
Created on Mon Aug 12 15:24:02 2024

@author: Matthew.Conlin
"""

from setuptools import setup, find_packages

setup(
    name='HTF',
    version='2.0.4',
    packages=find_packages(),
    package_data={
        'HTF': ['data/HighTideOutlookStationList_05_17_23_PAC_SLT.csv'],
    },
    include_package_data=True,
    install_requires=['datetime','intake','numpy',
                      'openpyxl','pandas','pytest',
                      'requests','scipy','scikit-learn',
                      'utide'],
)
