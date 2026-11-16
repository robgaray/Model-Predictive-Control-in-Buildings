# -------------------------------------------------------------
# Function: render_label.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Wraps an input label in red, with a short note, when its value
# came from the defaults rather than from the file, or when its
# parameter was duplicated in the file and the first value is the
# one shown.
# -------------------------------------------------------------
# Inputs
#   label            : Character. The label text.
#   is_default       : Logical. Whether the value came from the
#                      defaults.
#   is_duplicate     : Logical. Whether the parameter was
#                      duplicated in the file. Default FALSE.
# -------------------------------------------------------------
# Outputs
#   The label, or a tags$span with the label in red and the note.
# -------------------------------------------------------------
# Code outline
# 1. Choose the note.
# 2. Wrap the label in red when a note applies.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   render_label(label, is_default, is_duplicate)
# -------------------------------------------------------------

render_label <- function(label, is_default, is_duplicate = FALSE) {
  if (isTRUE(is_default) || isTRUE(is_duplicate)) {
    note <- if (isTRUE(is_default) && isTRUE(is_duplicate)) {
      " (default value; duplicated parameter)"
    } else if (isTRUE(is_default)) {
      " (default value)"
    } else {
      " (duplicated parameter, first value used)"
    }
    tags$span(
      style = "color:#c0392b; font-weight:600;",
      label,
      tags$em(note, style = "font-weight:400; font-size:85%;")
    )
  } else {
    label
  }
}
