
## TODO:
#  * adjust camera angle
#  * adjust opacity, colors are washed out

## latest rayshader from GH required

## Notes:

# https://www.rayshader.com/

# https://github.com/tylermorganwall/rayshader
# https://github.com/tylermorganwall/rayshader/issues/30
# https://github.com/tylermorganwall/rayshader/issues/25

library(rayshader)
library(raster)
library(magick)
library(progress)
# library(gifski)
library(magick)

elev <- raster('gis-data/elev_3m_utm.tif')

# a little vertical exaggeration
elev <- elev * 3

# convert raster -> matrix
elmat <- raster_to_matrix(elev)

# thematic map, as PNG, exact same dimensions
ov <- png::readPNG('water-depth-frames/022.png')
 

# compute shadows
raymat <- ray_shade(elmat, multicore = TRUE, zscale = 0.3)
ambmat <- ambient_shade(elmat, multicore = TRUE, zscale = 0.3)


## testing
elmat %>%
  sphere_shade(texture = "imhof4") %>%
  add_shadow(raymat) %>%
  add_shadow(ambmat) %>%
  add_overlay(ov, alphalayer = 0.8) %>%
  plot_map()





# theta (z-axis rotation)
# phi (azimuth)

# camera parameters
.theta <- 15
.phi <- 60
.zoom <- 0.6
.fov <- 48


# adjust until right
# render_camera(theta = 25, phi = 50, zoom = 0.65, fov = 48)


## output size
px.width <- 1200
px.height <- 800


##
## 3D r.sim output
##
p.input <- 'water-depth-frames'
p.output <- 'water-depth-render'
unlink(p.output, recursive = TRUE)
dir.create(p.output)

f <- list.files(p.input, pattern = '*.png$')
n <- length(f)
pb <- progress_bar$new(total = n)

for(i in seq_along(f)) {
  
  f.i <- f[i]
  of <- file.path(p.output, f.i)
  
  ov <- png::readPNG(file.path(p.input, f.i))
  
  ## annotation
  time.i <- as.numeric(strsplit(f.i, '.', fixed=TRUE)[[1]][1])
  tt <- sprintf("1 in. rain event: %s minutes", time.i)
  
  elmat %>%
    sphere_shade(texture = "imhof4") %>%
    add_shadow(raymat) %>%
    add_shadow(ambmat) %>%
    add_overlay(ov, alphalayer = 0.6) %>%
    plot_3d(elmat, zscale = 3, windowsize = c(px.width, px.height),
            baseshape='rectangle', lineantialias=TRUE,
            theta = .theta, phi = .phi, zoom = .zoom, fov = .fov)
  
  
  render_snapshot(
    filename = of, clear=TRUE, 
    vignette=FALSE, instant_capture = TRUE,
    title_color='black', title_offset=c(10, 10), title_size=25, title_bar_color=grey(0.5), title_text=tt,
    gravity='northeast', weight=700
  )
  
  # progress bar
  pb$tick()
}
pb$terminate()

## do this after a session, to clear rgl device
rgl::rgl.close()


## gifski
# doesn't work with delay < 1 second .. bug in C call?
# gifski(list.files('water-depth-render', full.names = TRUE), gif_file = 'a.gif', loop = TRUE, delay = 0.1)

## imagemagick
f <- list.files(path = 'water-depth-render', pattern = '\\.png', full.names = TRUE)
im.list <- lapply(f, image_read)
im <- do.call('c', im.list)

# resize
im.small <- image_resize(im, geometry = 'x900', filter = 'Cubic')

# animate
a <- image_animate(im.small, delay = 16, dispose = "previous", loop = 0, optimize = TRUE)
image_write(a, path = 'water-depth-variable-infiltration.gif')

# further optimization with gifsicle -- use linux machine




