# Seasonal_High_Tide_Flooding_Prediction (Python)


This is the Python translation of the code for the NOAA Seasonal-to-Annual High Tide Flooding Prediction Model. The model predicts the daily likelihood of minor high tide flooding (exceeding the NOAA high tide flooding or HTF threshold) up to year in advance, given a hourly water level and tide prediction time series from a NOAA tide gauge available in the CO-OPS data API. This model is described in detail in the following journal article:

Dusek G, Sweet WV, Widlansky MJ, Thompson PR and Marra JJ (2022) A novel statistical approach to predict seasonal high tide flooding. *Front. Mar. Sci*. 9:1073792. doi: 10.3389/fmars.2022.1073792

This is open access and available at: https://www.frontiersin.org/articles/10.3389/fmars.2022.1073792/full


## Table of Contents
- [Installation](#installation)
- [Usage](#usage)
- [Disclaimer](#disclaimer)
- [License](#license)
- [Contact](#contact)


## Installation

You can install the package using pip:

```bash
pip install git+https://github.com/NOAA-CO-OPS/Seasonal_High_Tide_Flooding_Prediction.git@pyHTF
```

Or you can install it from source:

```bash
git clone https://github.com/NOAA-CO-OPS/Seasonal_High_Tide_Flooding_Prediction.git
cd Seasonal_High_Tide_Flooding_Prediction
git checkout pyHTF
pip install -e .
```


## Usage

Below is a representative example of using the package. This example trains the model at the Charleston, SC tide gauge using data from 1983 through 2001, assess the performance of the model (on the same data), and then uses the trained model to predict the probability of high tide flooding on each day of 2002 at that location.

```python
from HTF import HTF_model

model = HTF_model(station=8665530,
		years_fit=[19830101,20011231],
		years_assess=[19830101,20011231],
                years_pred=[20020101,20021231],
                assess_method='DusekEtAl',
                assess_metric='htf_days',
                holdout_num=None,
                prctile_bin_val='pred_adj')
model.train()
model.assess()
model.predict()

print('The daily likelihood of HTF is predicted to be:')
print(model.out_predict['prob_daily'])
```


## Disclaimer
#### NOAA Open Source Disclaimer:

This repository is a scientific product and is not official communication of the National Oceanic and Atmospheric Administration, or the United States Department of Commerce. All NOAA GitHub project code is provided on an ?as is? basis and the user assumes responsibility for its use. Any claims against the Department of Commerce or Department of Commerce bureaus stemming from the use of this GitHub project will be governed by all applicable Federal law. Any reference to specific commercial products, processes, or services by service mark, trademark, manufacturer, or otherwise, does not constitute or imply their endorsement, recommendation or favoring by the Department of Commerce. The Department of Commerce seal and logo, or the seal and logo of a DOC bureau, shall not be used in any manner to imply endorsement of any commercial product or activity by DOC or the United States Government.


## License

Software code created by U.S. Government employees is not subject to copyright in the United States (17 U.S.C. �105). The United States/Department of Commerce reserve all rights to seek and obtain copyright protection in countries other than the United States for Software authored in its entirety by the Department of Commerce. To this end, the Department of Commerce hereby grants to Recipient a royalty-free, nonexclusive license to use, copy, and create derivative works of the Software outside of the United States.


## Contact

For additional information, contact:

Greg Dusek\
NOAA Center for Operational Oceanographic Products and Services\
gregory.dusek@noaa.gov
