# -------------------------------------------------------------
# Function: build_group_editor.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds a titled panel with the inputs of a chosen group of
# parameters of a file, four per row, so a long file can be shown
# as several groups.
# -------------------------------------------------------------
# Inputs
#   df               : Data frame. The table the function works
#                      on (see above).
#   prefix           : Character. Prefix of the input ids of the
#                      table or tab.
#   title            : Character. Title of the panel.
#   parameters       : Character vector. The parameters shown in
#                      the group, in order.
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
#   A wellPanel with the title and the grid of inputs.
# -------------------------------------------------------------
# Code outline
# 1. Describe one input per parameter of the group.
# 2. Lay them out with build_input_grid() under the title.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   build_group_editor(
#     df,
#     prefix,
#     title,
#     parameters,
#     options_list,
#     defaulted,
#     duplicated,
#     file_key)
# -------------------------------------------------------------
# Where this function/script is used
# GUI_config.R
# -------------------------------------------------------------
# functions/scripts called
# label_with_unit(), get_param_value(), build_input_grid()
# -------------------------------------------------------------

build_group_editor <- function(df, prefix, title, parameters, options_list = list(),
                                defaulted = character(0), duplicated = character(0),
                                file_key = NULL) {
  input_defs <- lapply(
    parameters,
    function(CONT_003) {
      list(
        id           = paste0(prefix, CONT_003),
        label        = if (is.null(file_key)) CONT_003 else label_with_unit(CONT_003, file_key),
        value        = get_param_value(df, CONT_003),
        options      = options_list[[CONT_003]],
        is_default   = CONT_003 %in% defaulted,
        is_duplicate = CONT_003 %in% duplicated
      )
    }
  )

  wellPanel(
    h4(title),
    build_input_grid(input_defs, max_per_row = 4)
  )
}
