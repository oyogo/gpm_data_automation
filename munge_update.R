#library(googledrive) ## This needs to be authenticated first...
library(data.table)
library(stringr)
library(raster)
library(snowfall)
library(sf)
library(nngeo)
library(exactextractr)
library(lubridate)
library(zoo)
library(RSQLite)

setwd("/home/oyogo/Documents/zangu_projects/gpm_data_download") 

#drive_auth(path = "/home/oyogo/Documents/zangu_projects/gpm_data_download/.private-key.json") # authenticate with user account. However, for a server set-up I'll have to use a service account. 
# start date: format(Sys.Date() - 30, '%Y-%m-01')
# end date : as.Date(format(Sys.Date(), '%Y-%m-01')) - 1
#startdate : ceiling_date(as.Date(format(Sys.Date(), '%Y-%m-%d')), "month") - months(2) - days(1)
#enddate : ceiling_date(as.Date(format(Sys.Date(), '%Y-%m-%d')), "month") - months(1) - days(1)

period <- paste0(floor_date(as.Date(format(Sys.Date(), '%Y-%m-%d')), "month") - months(1),
                 "_",
                 ceiling_date(as.Date(format(Sys.Date(), '%Y-%m-%d')), "month") - months(1) - days(1)) 


gpm_update_stack <- function(period){
  
  #drive_download(paste0("~/EarthEngine/GPM_stack/gpmStack_makueni_",period,".tif"), path = paste0("./data/gpm/",period,".tif"), overwrite = TRUE)

  start.date <- str_split(period, "_", simplify = TRUE)[,1]
  end.date <- str_split(period, "_", simplify = TRUE)[,2]
  
  #sqlite.path = "./data/lh_module_db.db"
  adm.bnd.path = "./shp/makueni_county_bnd/Makueni_county_wards.shp"
  #stack.path = paste0("./data/gpm/",period,".tif")
  stack.path = paste0("./gpmdata/gpmStack_makueni_",period,".tif")

  #con.sqlite <- dbConnect(RSQLite::SQLite(), sqlite.path)
  
  days.seq <- paste0("d", seq(as.Date(start.date), as.Date(end.date), by = "days"))
  
  poly.bnd <- st_read(adm.bnd.path) %>%
    st_transform(crs = 4326) %>%
    dplyr::select(CAW)
  
  bnd.box <- extent(poly.bnd %>% st_transform(4326))
  
  gpm <- crop(brick(stack.path), bnd.box)
  names(gpm) <- days.seq

  gpm.df <- data.table(rasterToPoints(gpm))
 
  gpm.df.sf <- st_as_sf(gpm.df, coords = c("x", "y"), crs = 4326) # %>%
 
  gpm.df.sf <- st_join(poly.bnd, gpm.df.sf, join = st_nn, k = 1, maxdist = 2000)
  
  gpm.coord <- gpm.df.sf %>%
    st_centroid() %>%
    st_coordinates() %>%
    data.frame()
  
  gpm.df.dt <- data.table(gpm.df.sf %>% st_drop_geometry())
  
  gpm.df.dt <- gpm.df.dt[, x := gpm.coord$X]
  gpm.df.dt <- gpm.df.dt[, y := gpm.coord$Y]
  
  gpm.df.long <- data.table::melt(gpm.df.dt, id.vars = c("x", "y", "CAW"))
  gpm.df.long <- gpm.df.long[!is.na(CAW), ]
  gpm.df.long <- gpm.df.long[, Date := as.Date(str_remove(gpm.df.long$variable, "d"), format = "%Y.%m.%d")]
  gpm.df.long <- gpm.df.long[, Year := year(Date)]
  gpm.df.long <- gpm.df.long[, Month := month.abb[month(Date)]]
  gpm.df.long <- gpm.df.long[, Day := day(Date)]
  gpm.df.long <- gpm.df.long[, doy := strftime(Date, format = "%j")]
  
  gpm.df.long <- gpm.df.long[, value := ifelse(is.na(value), 0, value)]
  gpm.df.long <- gpm.df.long[, cumDaily := cumsum(value), by = c("x", "y", "Year")]
  gpm.df.long <- gpm.df.long[, sumMonthly := sum(value), by = c("x", "y", "Month", "Year")]
  gpm.df.long <- gpm.df.long[, sumAnnual := sum(value), by = c("x", "y", "Year")]
  
  gpm.df.long <- gpm.df.long[, roll3 := rollmean(value, k = 3, align = "left", fill = NA), by = c("x", "y")]
  
  # RSQLite::dbWriteTable(conn = con.sqlite, name = "gpm_ts_admin", value = gpm.df.long, append = TRUE)
  #fwrite(gpm.df.long, "./data/csv/makueni_daily_gpm_api.csv", append = TRUE)
  fwrite(gpm.df.long, "./gpmdata/fromurl.csv", append = TRUE)
 
}


gpm_update_stack(period = period)
