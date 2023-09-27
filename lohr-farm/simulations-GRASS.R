
## works with: 
# terra_1.6-28
# rgrass7_0.2-10

## TODO:
# try out rgrass package: https://cran.r-project.org/web/packages/rgrass/vignettes/use.html


## getting closer to a consistent interface to GRASS GIS on gov machine, but still very annoying

# 0. create / use existing location / mapset, can contain nothing

# 1. open Rstudio from within OSGeo4W-shell

# 2. bootstrap location / mapset with DEM
# r.in.gdal ...

# 3. close rstudio or change location / mapset

# 4. process accordingly



## TODO:
#  * tinker with rainfall intensity grid
#  * how can we use manning's n with varying land cover / management?
#  * export legend


library(rgrass7)
library(terra)
library(sf)
library(viridisLite)
library(pbapply)


# GRASS working directory
.h <- 'e:/working_copies/DSS_simulations/lohr-farm/'
setwd(.h)

initGRASS(gisBase = 'C:/Program Files/QGIS 3.22.5/apps/grass/grass78/', gisDbase = 'e:/GRASS', location = 'lohr_farm', mapset = 'PERMANENT', home = .h)

# stringexecGRASS(string = 'g.list type=rast')

# fix python path, maybe only this is needed, seems to work
# https://gis.stackexchange.com/questions/189420/is-it-possible-to-start-the-grass-gui-from-r
Sys.setenv(PYTHONHOME = "C:\\Program Files\\QGIS 3.22.5\\apps\\Python39")

# start GUI if needed
# execGRASS('g.gui')


## setup region
execGRASS('g.region', flags = c('a', 'p'), parameters = list(raster = 'elev3m'))

## land cover --> infiltration rate
execGRASS('v.in.ogr', flags = c('overwrite'), parameters = list(input = 'gis-data/land-cover.shp', output = 'cover'))
execGRASS('v.to.rast', flags = c('overwrite'), parameters = list(input = 'cover', output = 'cover', use = 'attr', attribute_column = 'infil'))

# background values are 0.2 mm/hr
# otherwise use infiltration rate defined in 'cover'
execGRASS('r.mapcalc', flags = c('overwrite'), parameters = list(expression = 'i_rate = if(isnull(cover), 0.2, cover)'))


# partial derivatives
# r.slope.aspect --o elevation=elev3m dx=elev3m_dx dy=elev3m_dy aspect=elev3m_aspect slope=elev3m_slope
execGRASS('r.slope.aspect', flags = c('overwrite'), parameters = list(elevation='elev3m', dx='elev3m_dx', dy='elev3m_dy', aspect='elev3m_aspect', slope='elev3m_slope'))

## TODO:
# * discharge maps redundant?
# * reasonable infiltration rates ~ land cover in example
# * 


# cleanup previous, in case steady state is reached sooner / later
execGRASS('g.remove', flags = 'f', parameters = list(type = 'rast', pattern = 'water_depth*'))
execGRASS('g.remove', flags = 'f', parameters = list(type = 'rast', pattern = 'discharge*'))


# time series
# 60 minutes of simulation
# 1" of rain
# r.sim.water --o -t elevation=elev3m dx=elev3m_dx dy=elev3m_dy \
# depth=water_depth discharge=discharge \
# nprocs=8 output_step=1 \
# rain_value=25.4 infil_value=0.2 niterations=60 hmax=0.1

# https://grass.osgeo.org/grass82//manuals/r.sim.water.html

# try variable manning's N
# http://www.fsl.orst.edu/geowater/FX3/help/8_Hydraulic_Reference/Mannings_n_Tables.htm

# 1" per hour rainfall intensity
# variable infiltration rate based on land cover
# all resulting maps share the same, special color ramp
execGRASS('r.sim.water', flags = c('overwrite', 't'), parameters = list(elevation='elev3m', dx='elev3m_dx', dy='elev3m_dy', depth='water_depth', discharge='discharge', nprocs = 16, rain_value = 25.4, infil = 'i_rate', output_step = 1, niterations = 60, hmax = 0.1))


# output is a character vector
.r <- execGRASS('g.list', parameters = list(type = 'rast', pattern = 'water_depth.??'), intern = TRUE)

# output dir for simulation frames
.p <- 'water-depth-frames'
unlink(.p, recursive = TRUE)
dir.create(.p)

# set NULL cells to transparent
# I think that this is working
Sys.setenv(GRASS_RENDER_TRANSPARENT = TRUE)


## TODO: this is quite slow: ~ 3 minutes / 90 images
# iterate over maps in simulation
.nothing <- pblapply(seq_along(.r), function(i) {
  
  # current map
  .m <- .r[i]
  
  # current output file
  .f <- file.path(.p, sprintf("%03d.png", i))
  
  # start device output
  .null <- execGRASS('d.mon', flags = c('overwrite'), parameters = list(start = 'cairo', output = .f, width = 6, height = 5, resolution = 96), intern = TRUE)
  
  # thematic display of current frame
  .null <- execGRASS('d.rast', parameters = list(map = .m, values = '0.004-999'), intern = TRUE)
  .null <- execGRASS('d.vect', parameters = list(map = 'cover', fill_color = 'none', color = 'black'), intern = TRUE)
  
  # stop device
  .null <- execGRASS('d.mon', parameters = list(stop = 'cairo'), intern = TRUE)
  
})




# try reading raster data directly from GRASS
d <- read_RAST('elev3m_dx', return_format = 'terra')
plot(d, col = mako(25))

