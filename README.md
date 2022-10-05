# GPM Data download & processing pipeline   
The pipeline has two scripts: 
 * A python script for downloading the data and 
 * R script for wrangling the data and versioning it on the server. 
The two scripts are run as cron jobs whereby the download script (python) runs on the second day of each month and the processing script (R) running the third day of each month.  

## Data download  
The a python script fetches the images from NASA and preprocesses it on GEE (Google Earth Engine). The resulting data can either be sent to google drive or downloaded using a url.   

### Service account  
To use gee in a workflow, a service account is created. With this, the Python script is run from a server without having someone respond to the prompts on the browser (what happens when you authenticate to GEE with a user account).   

Use the steps detailed [here](https://developers.google.com/identity/protocols/oauth2/service-account#creatinganaccount) to reate a service account. 

Note: Ensure you give an absolute path to your private key on the script.

## Data wrangling  
The data processing and versioning is done using R. The R and Python scripts are linked to a common folder to which the python script downloads the data and from which the R scipts accesses the data for preprocessing.  The data is then versioned such that one can revert back to previous state in case of any corruption. 

## Automation    
With crontab, schedule a cronjob that runs say once a month. With this in place, we can have the script run and we'll have our data up to date. 
 
References:  
1. https://www.labnol.org/google-api-service-account-220404  
2. 