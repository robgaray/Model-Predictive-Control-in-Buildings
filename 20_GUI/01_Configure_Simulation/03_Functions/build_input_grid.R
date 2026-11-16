# -------------------------------------------------------------
# Function: build_input_grid.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Lays out a list of inputs in rows of max_per_row columns. An
# input with options (a closed list) becomes a dropdown
# (selectInput); any other becomes a text input.
# -------------------------------------------------------------
# Inputs
#   input_defs       : List of input descriptions, each with:
#                        - id
#                        - label
#                        - value
#                        - options
#                        - is_default
#                        - is_duplicate
#   max_per_row      : Integer. Inputs per row. Default 4.
# -------------------------------------------------------------
# Outputs
#   A tags$div with one fluidRow per row of inputs, or NULL when
#   there is no input.
# -------------------------------------------------------------
# Code outline
# 1. Split the inputs into rows.
# 2. Build each input as a dropdown or a text input.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   build_input_grid(input_defs, max_per_row)
# -------------------------------------------------------------

build_input_grid <- function(input_defs, max_per_row = 4) {
  if (length(input_defs) == 0) {
    return(NULL)
  }

  row_groups <- split(
    input_defs,
    ceiling(seq_along(input_defs) / max_per_row)
  )

  tags$div(
    lapply(
      row_groups,
      function(row_items) {
        fluidRow(
          lapply(
            row_items,
            function(item) {
              column(
                width = floor(12 / max_per_row),
                if (!is.null(item$options)) {
                  selectInput(
                    inputId  = item$id,
                    label    = render_label(item$label, item$is_default, item$is_duplicate),
                    choices  = item$options,
                    selected = item$value
                  )
                } else {
                  textInput(
                    inputId = item$id,
                    label   = render_label(item$label, item$is_default, item$is_duplicate),
                    value   = item$value
                  )
                }
              )
            }
          )
        )
      }
    )
  )
}
