#! /usr/bin/python3 



import os
script_dir = os.path.dirname(os.path.realpath(__file__))
os.chdir(script_dir)

import ee
service_account = os.getenv("account")
credentials = ee.ServiceAccountCredentials(service_account, os.getenv("path"))
ee.Initialize(credentials)

#from pydrive.auth import GoogleAuth
#from pydrive.drive import GoogleDrive

# authenticate to Google Drive (of the Service account)
#gauth = GoogleAuth()
#scopes = ['https://www.googleapis.com/auth/drive']
#gauth.credentials = ee.ServiceAccountCredentials(service_account, '.private-key.json',scopes=scopes)

#drive = GoogleDrive(gauth)


import sys
print(sys.version)

import folium
import requests
import geopandas as gpd

#import pyepsg
import geemap
from IPython.display import Image
import pandas
from datetime import date
import calendar

## Set start/end date(s)
dt = date.today()
year = dt.year
month = dt.month
day = dt.day

d0 = date(year, month-1, 1)
d1 = date(year, month-1, calendar.monthrange(year, month-1)[1])

#delta = d1 - d0

#days = delta.days

#startDate = ee.Date.fromYMD(year-1,month,day) # Date at current month -1 
# endDate = ee.Date.fromYMD(year,month,day) # Current date
startDate = ee.Date.fromYMD(year,month-1,1) # last day 2 month ago  
endDate = ee.Date.fromYMD(year,month,1) # last day last month

days = endDate.difference(startDate, 'days').getInfo()



## Get AOI and set bounding box
aoi_in = str(0)
aoi_name = 'makueni'
path = '/home/oyogo/Documents/zangu_projects/gpm_data_download/MakueniResourceHub/data/shp/makueni_county_bnd/{}'.format
aoi = gpd.read_file(path('Makueni_county'+'.shp'))
aoi = aoi.dissolve(by = 'COUNTY_NAM')
aoi_bnds = aoi.bounds
#print(aoi_bnds)

llx, lly, urx, ury = aoi.bounds.minx[0], aoi.bounds.miny[0], aoi.bounds.maxx[0], aoi.bounds.maxy[0]
area = ee.Geometry.Polygon([[llx,lly], [llx,ury], [urx,ury], [urx,lly]])

## Image collection
gpm = (
    ee.ImageCollection('NASA/GPM_L3/IMERG_V06').
    filterBounds(area).
    select("precipitationCal").
    filterDate(startDate, endDate)
)

## Function to iterate over collection, calculating daily sums
def gpmSum(imageCollection):
    mylist = ee.List([])
    for n in range(days): #ee.List.sequence(0, nDays):
        ini = startDate.advance(n, 'day')
        end = ini.advance(1, 'day')
        w = imageCollection.filterDate(ini,end).select(0).sum()
        mylist = mylist.add(w.set('system:time_start', ini))
    return ee.ImageCollection.fromImages(mylist)

## Create stack with daily sums
dailyGPM = ee.ImageCollection(gpmSum(gpm))
dailyGPM_stack = dailyGPM.toBands().multiply(0.5)
dailyGPM.first().getInfo()

## Save to google drive
#img_todrive = {
    #'description': 'gpm_rwanda_'+str(startyear)+"_"+str(endyear),
 #   'folder': 'EarthEngine/GPM_stack',
  #  'scale': 11000,
   # 'maxPixels': 1e13,
    
    #'region': area,
    #'fileFormat': 'GeoTIFF'
#}



#task = ee.batch.Export.image.toDrive(dailyGPM_stack, 'gpmStack_'+aoi_name+"_"+str(d0)+"_"+str(d1), **img_todrive)
#task.start()

url = dailyGPM_stack.getDownloadUrl({
    'region': area,
    'scale': 11000,
    'format': 'GEO_TIFF'
})
response = requests.get(url)
imgcollection_name = 'gpmStack_'+aoi_name+"_"+str(d0)+"_"+str(d1)
filenameTif = 'gpmdata/' + imgcollection_name + '.tif'
with open(filenameTif,'wb') as fd:
  fd.write(response.content)

#print(task.status())
#print('Done!')



