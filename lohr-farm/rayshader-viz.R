
## TODO:
#  * adjust camera angle
#  * crop image before animation

## latest rayshader from GH required

## Notes:

# https://www.rayshader.com/

# https://github.com/tylermorganwall/rayshader
# https://github.com/tylermorganwall/rayshader/issues/30
# https://github.com/tylermorganwall/rayshader/issues/25

library(rayshader)
library(raster)
library(magick)
library(pbapply)
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

f <- list.files(p.input, pattern = '*.png$', full.names = FALSE)

## don't do anything while this is running, rgl window is fragile
# result is empty (black) renders

# iterate over frames
# ~ 3 minutes
.null <- pblapply(seq_along(f), function(i) {
  
  # current frame
  f.i <- f[i]
  of <- file.path(p.output, f.i)
  
  # load current overlay
  ov <- png::readPNG(file.path(p.input, f.i))
  
  # annotation
  time.i <- as.numeric(strsplit(f.i, '.', fixed=TRUE)[[1]][1])
  tt <- sprintf("1 in/hr rain event: %s minutes", time.i)
  
  elmat %>%
    sphere_shade(texture = "imhof4") %>%
    add_shadow(raymat) %>%
    add_shadow(ambmat) %>%
    add_overlay(ov, alphalayer = 0.8) %>%
    plot_3d(elmat, zscale = 3, windowsize = c(px.width, px.height),
            baseshape='rectangle', lineantialias=TRUE,
            theta = .theta, phi = .phi, zoom = .zoom, fov = .fov)
  
  ## TODO: consider render_highquality()
  
  render_snapshot(
    filename = of, clear = TRUE, 
    vignette = FALSE, instant_capture = TRUE,
    title_color = 'black', title_offset=c(125, 10), title_size = 25, 
    title_bar_color = grey(0.5), title_text = tt,
    title_position = 'southwest', weight = 700, gravity = 'southwest'
  )
})
  
  


## do this after a session, to clear rgl device
rgl::rgl.close()


## gifski
# doesn't work with delay < 1 second .. bug in C call?
# gifski(list.files('water-depth-render', full.names = TRUE), gif_file = 'a.gif', loop = TRUE, delay = 0.1)

## imagemagick
f.im <- list.files(path = 'water-depth-render', pattern = '\\.png', full.names = TRUE)
im.list <- lapply(f.im, image_read)
im <- do.call('c', im.list)

## remove white space-- depends on camera settings

# vertical strip, left side
im <- image_chop(im, geometry = '90x')

# horizontal strip, top
im <- image_chop(im, geometry = 'x20')
# crop 1-950px
im <- image_crop(im, geometry = '950x')

# resize
im.small <- image_resize(im, geometry = 'x900', filter = 'Cubic')

# animate
a <- image_animate(im.small, delay = 16, dispose = "previous", loop = 0, optimize = TRUE)
image_write(a, path = 'water-depth-variable-infiltration.gif')

## further optimization with gifsicle -- use linux machine
# see animation-notes.sh
# this probably requires further optimization steps by imagemagick: +dither +map


## av package / MP4

# save to temporary dir, slow
.td <- 'temp-export'
unlink(.td, recursive = TRUE)
dir.create(.td)
for(i in seq_along(im.small)) {
  image_write(im.small[i], path = file.path(.td, sprintf('%03d.png', i)))
}

# encode as MP4 ~ 8FPS
library(av)
f.render <- list.files(.td, pattern = '.png$', full.names = TRUE)
av_encode_video(input = f.render, output = 'water-depth-variable-infiltration.mp4', framerate = 8)

unlink(.td, recursive = TRUE)



