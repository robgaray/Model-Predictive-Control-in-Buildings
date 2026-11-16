# -------------------------------------------------------------
# Function: param_file_pending.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Tells whether a flat parameter file, or a block of parameters, has
# something pending for the user: a value that took a default, a
# parameter found twice, or a value in its input that differs from
# the value saved. The state of the file that was last read from
# disk or saved is the baseline. An input that the browser has not
# built yet (its tab was never opened) holds no edit, so it counts as
# unchanged.
# -------------------------------------------------------------
# Inputs
#   df          : Data frame (parameter, value). The state of the file.
#   baseline_df : Data frame (parameter, value). The values that were
#                 last read from disk or saved.
#   prefix      : Character. The start of the id of each input.
#   input       : The Shiny input object.
#   flagged     : Character vector. The parameters that took a default
#                 or were found twice.
#   include     : Character vector. The parameters that count.
# -------------------------------------------------------------
# Outputs
#   Logical. TRUE when something is pending.
# -------------------------------------------------------------
# Code outline
# 1. Keep the parameters that count.
# 2. Look for a flagged parameter.
# 3. Compare each input with the baseline.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   param_file_pending(df, baseline_df, prefix, input, flagged, include)
# -------------------------------------------------------------

param_file_pending <- function(df, baseline_df, prefix, input, flagged,
                               include) {

  # -------------------------------------------------------------
  # 1. Keep the parameters that count
  # -------------------------------------------------------------
  {
    include <- include[include %in% as.character(df$parameter)]
    if (length(include) == 0) {
      return(FALSE)
    }
  }

  # -------------------------------------------------------------
  # 2. Look for a flagged parameter
  # -------------------------------------------------------------
  {
    if (any(include %in% flagged)) {
      return(TRUE)
    }
  }

  # -------------------------------------------------------------
  # 3. Compare each input with the baseline
  # -------------------------------------------------------------
  {
    for (CONT_001 in include) {
      typed <- input[[paste0(prefix, CONT_001)]]
      if (is.null(typed)) {
        next
      }
      # normalize_cell_values is called on both values so that two
      # ways of writing the same number are not taken as a change.
      if (!identical(normalize_cell_values(typed),
                     normalize_cell_values(
                       get_param_value(baseline_df, CONT_001)
                     ))) {
        return(TRUE)
      }
    }
    rm(CONT_001)
  }

  return(FALSE)
}
