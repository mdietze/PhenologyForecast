create.ndvi.data <- function(site.number,useMODISTools = FALSE){
  # The function create.ndvi.data loads the MODIS data for the site site.number
  # and calculates the NDVI values for that site. Output is saved in 
  # ndvi_data_siteX.csv, where X is the site number
  
  if(useMODISTools){
    # First, we need to know the file name of the MODIS data that we just downloaded.
    # Look in the "Subset Download..." file:
    subset.filename <- Sys.glob("Subset Download*") # The file that says where the MODIS data was just saved
  
    # Load that file...
    file.info <- read.csv(subset.filename) 
  
    # Find the filename of the modis data file:
    modis.filename <- paste(as.character(file.info$SubsetID[1]),"_MOD09A1.asc",sep="")
  
    # Load the modis data:
    modis_dat = read.csv(modis.filename,header=FALSE)
  
    # find the unique ID number. There is a unique ID number associated with every 
    # day (shared by all vars for that day)
    id_num <- unique(modis_dat$V5)
    id_num <- id_num[!is.na(id_num)]
    year_dat = as.numeric(substr(id_num,1,4)) # find the year associated with that day
  
    # Initialize arrays
    band_1_data= rep(NA,length(id_num))
    band_2_data = rep(NA,length(id_num))
    DOY_data = rep(NA,length(id_num))
    date_format = as.Date(rep(NA,length(id_num)))
  
    for (p in 1:length(id_num) ) { # for loop over each day.  
    
      day_index = which(id_num[p]==modis_dat$V5) # for each ID number, find the rows that match that ID number (i.e. from the same day)
      day_data = modis_dat[as.numeric(day_index),] # extract the modis data for that index (that day)
    
      band_1_index = grep('b01',day_data$V1) # get index band 1
      band_2_index = grep('b02',day_data$V1) # get index band 2
      DOY_index = grep('day_of_year',day_data$V1) # get index DOY
    
      band_1_data[p] = mean(as.numeric(day_data[band_1_index,6:ncol(day_data)])) # Average over all pixels
      band_2_data[p] = mean(as.numeric(day_data[band_2_index,6:ncol(day_data)])) # Average over all pixels
      DOY_data[p] = day_data[DOY_index,6] 
    
      date_info = paste(year_dat[p],DOY_data[p]) # Convert DOY, year to date
      date_format[p] = strptime(date_info, "%Y %j")
    }
  } else {
    
    ## process the data from PEcAn.data.remote netCDF
    
    ## load
    load(paste0("./MODIS/",site.number,".RData"))
    
    ## extract variables
    band_1_data = site.data$b01
    band_2_data = site.data$b02
    date_format = strptime(site.data$date, "%Y %j")
    
  }

  # Calculate the NDVI!
  NDVI_cal = (band_2_data - band_1_data) / (band_2_data + band_1_data)
  
  MODIS_DATA_ST <- data.frame(date = date_format, ndvi = NDVI_cal)

  # Need to delete leap days...
  leap_days <- is.na(MODIS_DATA_ST)
  MODIS_DATA_ST <- as.data.frame(subset.data.frame(MODIS_DATA_ST,!leap_days[,2]))
  # leap days deleted!      
  
  # Also delete any dates that are NA (why do these exist??)
  MODIS_DATA_ST <- as.data.frame(subset.data.frame(MODIS_DATA_ST,!leap_days[,1]))
  
  # Finally, remove any dates from the future (there are some of these...)
  MODIS_DATA_ST <- as.data.frame(subset.data.frame(MODIS_DATA_ST,
                                                   as.Date(MODIS_DATA_ST$date) < (Sys.Date()+1)))
  
  
  # Create a vector of possible data observation dates
  source("global_input_parameters.R")
  start.date <- as.Date(global_input_parameters$data.start.date)
  current.year <- format(Sys.time(), "%Y")
  end.date <- as.Date(paste(current.year,"-12-31",sep=""))
  daily.dates = seq(start.date, end.date, by="days")
  
  # Finds indices of dates of modis data that are observed (and match possible_days)
  days.with.modis.data = match(as.Date(as.character(MODIS_DATA_ST$date)),daily.dates)
  days.with.modis.data = days.with.modis.data[!is.na(days.with.modis.data)] 
 
  # make time series vector of modis data, the same length as daily.dates
  ndvi = rep(NA,length(daily.dates))
  ndvi[days.with.modis.data] = MODIS_DATA_ST$ndvi
    
  # Make data frame of modis time series with dates 
  NDVI.data = data.frame(date = daily.dates, ndvi = ndvi)
  
  # Save NDVI data:
  write.csv(NDVI.data, file = sprintf("ndvi_data_site%i.csv",site.number),row.names=FALSE)
    
}
