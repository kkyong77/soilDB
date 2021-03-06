# Plot Henry waterlevel data with precipitation data from nearest NOAA weather station
#  modified example to show summary of only large events -- in same graph as water table data
#
# @purpose: Show use of two new experimental soilDB-type functions for the NOAA API
#
#            - get_NOAA_stations_nearXY() - find all stations near a specified lat/lng and bounding box (limit 1000)
#
#            - get_NOAA_GHCND_by_stationyear() - get GHCND data (daily summaries) by station ID and year (limit 1000)
#
#           Note that using the NOAA API requires an API token specified as argument to above two functions.
#           A token can be obtained for free at the following link: https://www.ncdc.noaa.gov/cdo-web/token
#
# @last_update: 2020/06/10
#
# @authors: Andrew Brown, Dylan Beaudette
#           based on fetchHenry/fetchSCAN "Water Level and Precipitation" demo by Dylan E. Beaudette
#           (http://ncss-tech.github.io/AQP/soilDB/Henry-demo.html)

##### SETUP #####

# 1.  You will need your own API Token: https://www.ncdc.noaa.gov/cdo-web/token
noaa_api_token <- "GITYEROWNDANGTOKEN"

# # 2. You will need a Henry project/siteid/sso + water level sensor name + type

# this example is one of ben marshall's waterlevel sensors in Maryland
# henry_project <- "MD021" # modify the fetchHenry call to use usersiteid, sso, etc.
# henry_sensor_name <- "Hatboro"
# henry_sensor_type <- "waterlevel"

# this example is from wisconsin
henry_project <- "DSP - MLRA 95 - Water Table"
henry_sensor_name <- "Ionia"
henry_sensor_type <- "waterlevel" 
large_event_threshold <- 2.5

#################

# data wrangling
library(sp)
library(dplyr)

# API queries to HENRY and NOAA GHCND
library(httr)
library(jsonlite)
library(soilDB)

# plots
library(latticeExtra)

# get data from henry 
x <- fetchHenry(
    project = henry_project, 
    what = 'all',
    gran = 'day',
    pad.missing.days = FALSE
  )

# subset potential multi-sensor result by sensor type (waterlevel) and sensor name
x.sub <- subset(x[[henry_sensor_type]], sensor_name == henry_sensor_name)

# convert Henry date/time into Date class
x.sub$date_time <- as.Date(x.sub$date_time)

x.sub$sensor_value <- -(x.sub$sensor_depth + x.sub$sensor_value)

# extract Henry coordinates using sensor/site name 
henry_coords <- data.frame(id = henry_sensor_name, 
                           coordinates(x$sensors[x$sensors$name == henry_sensor_name, ]))

# promote to SpatialPointsDataFrame
coordinates(henry_coords) <- ~ wgs84_longitude + wgs84_latitude
proj4string(henry_coords) <- "+proj=longlat +datum=WGS84"

### define some new functions

# query the NOAA API to get station data for a bounding box around a lat/lng (limit 1000 records)
#  default is +/- 0.5 degree latitude and longitude (bbox = 1)
get_NOAA_stations_nearXY <- function(lat, lng, apitoken, bbox = 1) {
  coord <- data.frame(lat = lat, lng = lng)
  coordinates(coord) <- ~ lng + lat
  
  # determine dimension in each direction to build bbox
  bdim <- bbox / 2
  
  # build Google Maps API V3 LatLngBounds.toUrlValue string
  ext_string <- sprintf("%s,%s,%s,%s", lat - bdim, lng - bdim, lat + bdim, lng + bdim)
  
  # construct GET request
  r <- httr::GET(url = sprintf(
        "https://www.ncdc.noaa.gov/cdo-web/api/v2/stations?extent=%s&limit=1000",
        ext_string
      ), add_headers(token = apitoken))
  
  # retrieve content
  r.content <- httr::content(r, as = "text", encoding = "UTF-8")
  
  # convert JSON to data.frame
  d <- jsonlite::fromJSON(r.content)
  stations <- d$results
  
  if(nrow(stations) == 1000)
    message("maximum record limit reached (n = 1000) -- try a smaller bbox value")
  
  return(stations)
}

get_NOAA_GHCND_by_stationyear <- function(stationid, year, datatypeid, apitoken) {
    # generate ISO format start/end date from year
    startdate <- sprintf("%s-01-01", year)
    enddate <- sprintf("%s-12-31", year)
    
    message(sprintf('Downloading GHCND data for %s over interval %s to %s', 
                    stationid, startdate, enddate))
    
    # build multi-datatype URL
    datatypeids <- sprintf("&datatypeid=%s", datatypeid)
    datatypeid.url <- paste0(datatypeids, collapse="&")
    
    # construct GET request
    r <- httr::GET(url = paste0(sprintf(
          "https://www.ncdc.noaa.gov/cdo-web/api/v2/data?datasetid=GHCND&stationid=%s&startdate=%s&enddate=%s&limit=1000",
          stationid,
          startdate,
          enddate), datatypeid.url), add_headers(token = apitoken))
    
    # retrieve content
    r.content <- httr::content(r, as = "text", encoding = "UTF-8")
    
    # convert JSON to data.frame

    d <- jsonlite::fromJSON(r.content)  
    
    if(nrow(d$results) == 1000)
      message("maximum record limit reached (n = 1000) -- try using only one or two datatypeids")

    return(d$results)
  }

# download all the stations within a half-degree lat/lng of the henry coordinates
#  using get_NOAA_stations_nearXY()
stations <- get_NOAA_stations_nearXY(
    lat = henry_coords$wgs84_latitude,
    lng = henry_coords$wgs84_longitude,
    apitoken = noaa_api_token
  )

# remove stations with less than 90 percent data coverage
# and make sure they have data at least more recent than 2010
stations <-  filter(stations,
                    datacoverage >= 0.90,
                    stations$maxdate > as.Date("2010-01-01"))

# promote point locations to SpatialPointsDataFrame
stations.sp <- stations[, c("id", "longitude", "latitude")]
coordinates(stations.sp) <- ~ longitude + latitude
proj4string(stations.sp) <- "+proj=longlat +datum=WGS84"

# calculate spatial distance between all stations and the coordinates of Henry site
dmat <- sp::spDistsN1(stations.sp, henry_coords, longlat = TRUE)

# determine the 10 nearest stations (could also set a distance threshold -- in degrees)
idx.nearest <- order(dmat)[1:10]
noaa.stations <- stations[idx.nearest, ]

# create a date range based on the Henry data
#   using the limits of the water level data and pad 14 days
start.date <- min(x.sub$date_time) - 14
stop.date <- max(x.sub$date_time) + 14

# make date axis for graph
date.axis <- seq.Date(start.date, stop.date, by = '2 months')

# filter to get NOAA stations that have data [mindate, maxdate]
#  within the HENRY interval [start.date, stop.date]
noaa.stations.inrange <- filter(noaa.stations, 
                                mindate <= start.date, 
                                maxdate >= stop.date)

# the first row is the closest station with data coverage for full interval of Henry data
noaa.station <- noaa.stations.inrange[1, ]

# determine what years to download precipitation data for
#  based on the henry start and stop dates
first.year <- as.numeric(min(format(as.Date(date.axis), "%Y")))
last.year <- as.numeric(max(format(as.Date(date.axis), "%Y")))
year.seq <- as.character(first.year:last.year)

# now, loop through each year and download the GHCND data (daily summaries)
res <- do.call('rbind', lapply(year.seq, function(year) {
  get_NOAA_GHCND_by_stationyear(noaa.station$id,
                                year = year,
                                datatypeid = "PRCP",
                                apitoken = noaa_api_token)
}))

# filter result to get precipitation data
res.precip <- filter(res, datatype == "PRCP")

# convert 10ths of millimeters (integer storage of decimal) to centimeters
res.precip$value <- res.precip$value / 100

res.precip$big_event <- res.precip$value > large_event_threshold

# convert date to Date object for plotting
res.precip$date <- as.Date(res.precip$date)

# plot water level data, with custom panel function showing large rain events
xyplot(sensor_value ~ date_time,
    data = x.sub,
    type = c('l', 'g'),
    cex = 0.75,
    ylab = 'Water Level (cm)',
    xlab = '',
    scales = list(
      x = list(at = date.axis, format = "%b\n%Y"),
      y = list(tick.number = 10)
    ),
    panel = function(x, y, ...){
      panel.xyplot(x , y, span=.8, iter=5, ...)
      idx <- match(x, res.precip$date)
      panel.abline(v = x[res.precip$big_event[idx]], col="RED")
    }
  )
