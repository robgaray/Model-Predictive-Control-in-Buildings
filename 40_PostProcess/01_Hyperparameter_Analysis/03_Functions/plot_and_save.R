# -------------------------------------------------------------
# Function: plot_and_save
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
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
#   width     : Integer. JPEG width in pixels. Default: 800.
#   height    : Integer. JPEG height in pixels. Default: 600.
#   quality   : Integer. JPEG quality (1-100). Default: 95.
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
#   PostProcess_hyperparameter_analysis.R
#   GUI_hyperparameter.R
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------
plot_and_save <- function(draw_fn, file_path,
                          width = 800, height = 600, quality = 95) {
  # Render on screen (works in interactive sessions; silently skipped
  # when running via Rscript without a display)
  tryCatch(draw_fn(), error = function(e) invisible(NULL))

  # Save to JPEG file
  jpeg(filename = file_path, width = width, height = height, quality = quality)
  on.exit(dev.off(), add = TRUE)
  draw_fn()
}
