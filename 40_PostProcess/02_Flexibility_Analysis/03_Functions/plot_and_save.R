# -------------------------------------------------------------
# Function: plot_and_save.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Renders a plot on the current graphics device (screen) and
# then saves it to a JPEG file.
# The plot is built by a user-supplied zero-argument function,
# which allows all plot-specific variables to be captured via
# closures before calling plot_and_save.
# -------------------------------------------------------------
# Inputs
#   draw_fn   : Function. Zero-argument function that executes
#               the complete plot.
#   file_path : Character. Full path where the JPEG will be
#               saved.
#   width     : Integer. JPEG width in pixels. Default: 1200.
#   height    : Integer. JPEG height in pixels. Default: 800.
#   quality   : Integer. JPEG quality (1-100). Default: 90.
# -------------------------------------------------------------
# Outputs
#   Saves a JPEG file at file_path. Returns NULL invisibly.
# -------------------------------------------------------------
# Code outline
#   1. Render on screen (silently skipped if headless)
#   2. Save to JPEG file
# -------------------------------------------------------------
# Usage instructions
#   plot_and_save(draw_fn, "output.jpg")
# -------------------------------------------------------------
# Where this function/script is used
#   Called by PostProcess_flexibility_analysis.R
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------
plot_and_save <- function(draw_fn, file_path,
                          width = 1200, height = 800, quality = 90) {
  # Render to screen (silently ignored when no display is available)
  tryCatch(draw_fn(), error = function(e) invisible(NULL))
  # Save to JPEG
  jpeg(filename = file_path, width = width, height = height, quality = quality)
  on.exit(dev.off(), add = TRUE)
  draw_fn()
}
