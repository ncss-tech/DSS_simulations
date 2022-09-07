


# 0. create / use existing location / mapset, can contain nothing

# 1. open Rstudio from within GRASS terminal

# 2. bootstrap location / mapset with DEM


library(rgrass7)
library(terra)
library(sf)

setwd('E:')


initGRASS(gisBase = 'C:/Program Files/QGIS 3.22.5/apps/grass/grass78/', gisDbase = 'e:/GRASS', location = 'lohr_farm', mapset = 'PERMANENT')




execGRASS('g.region', flags = c('a', 'p'), parameters = list(raster = 'elev3m'))

