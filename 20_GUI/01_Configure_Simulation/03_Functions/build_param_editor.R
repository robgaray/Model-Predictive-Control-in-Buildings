# -------------------------------------------------------------
# Function: build_param_editor.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds the editor of a flat parameter file: one input per
# parameter, labelled with its unit, in red when its value is a
# default. With max_per_row 1 the inputs are stacked; otherwise
# build_input_grid() lays them out.
# -------------------------------------------------------------
# Inputs
#   df               : Data frame. The table the function works
#                      on (see above).
#   prefix           : Character. Prefix of the input ids of the
#                      table or tab.
#   max_per_row      : Integer. Inputs per row. Default 1.
#   options_list     : Named list. Allowed options of each
#                      closed-list parameter, which is then shown
#                      as a dropdown. Default list().
#   defaulted        : Character vector. Parameters whose value
#                      came from the defaults. Default
#                      character(0).
#   duplicated       : Character vector. Parameters found more
#                      than once in the file. Default
#                      character(0).
#   file_key         : Character. File name of the configuration
#                      file, as Parameter_Units.csv names it;
#                      NULL shows no units. Default NULL.
# -------------------------------------------------------------
# Outputs
#   A tags$div with the inputs.
# -------------------------------------------------------------
# Code outline
# 1. Describe one input per parameter.
# 2. Stack them, or lay them out with build_input_grid().
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   build_param_editor(
#     df,
#     prefix,
#     max_per_row,
#     options_list,
#     defaulted,
#     duplicated,
#     file_key)
# -------------------------------------------------------------
# Where this function/script is used
# GUI_config.R
# -------------------------------------------------------------
# functions/scripts called
# label_with_unit(), render_label(), build_input_grid()
# -------------------------------------------------------------

build_param_editor <- function(df, prefix, max_per_row = 1, options_list = list(),
                                defaulted = character(0), duplicated = character(0),
                                file_key = NULL) {
  input_defs <- lapply(
    seq_len(nrow(df)),
    function(CONT_002) {
      param_name <- as.character(df$parameter[CONT_002])
      list(
        id           = paste0(prefix, param_name),
        label        = if (is.null(file_key)) param_name else label_with_unit(param_name, file_key),
        value        = as.character(df$value[CONT_002]),
        options      = options_list[[param_name]],
        is_default   = param_name %in% defaulted,
        is_duplicate = param_name %in% duplicated
      )
    }
  )

  if (max_per_row <= 1) {
    return(
      tags$div(
        lapply(
          input_defs,
          function(item) {
            if (!is.null(item$options)) {
              selectInput(
                inputId  = item$id,
                label    = render_label(item$label, item$is_default),
                choices  = item$options,
                selected = item$value
              )
            } else {
              textInput(
                inputId = item$id,
                label   = render_label(item$label, item$is_default),
                value   = item$value
              )
            }
          }
        )
      )
    )
  }

  build_input_grid(input_defs, max_per_row = max_per_row)
}
