# -------------------------------------------------------------
# Function: build_group_editor.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds a panel with the inputs of a chosen group of parameters of
# a file, so a long file can be shown as several groups. The panel
# carries a title, or none when the title is NULL. The labels take
# their units from the catalogue, and the parameters with a list of
# options are dropdowns.
# -------------------------------------------------------------
# Inputs
#   df               : Data frame. The table the function works
#                      on (see above).
#   prefix           : Character. Prefix of the input ids of the
#                      table or tab.
#   title            : Character. Title of the panel, or NULL for a
#                      panel with no title.
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
#                      file, as the catalogue names it; NULL shows
#                      no units. Default NULL.
#   max_per_row      : Integer. Number of inputs on each row.
# -------------------------------------------------------------
# Outputs
#   A wellPanel with the title, when there is one, and the grid of
#   inputs.
# -------------------------------------------------------------
# Code outline
# 1. Describe one input per parameter of the group.
# 2. Lay them out with build_input_grid() under the title, when
#    there is one.
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
#     file_key,
#     max_per_row)
# -------------------------------------------------------------

build_group_editor <- function(df, prefix, title, parameters, options_list = list(),
                                defaulted = character(0), duplicated = character(0),
                                file_key = NULL, max_per_row) {
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
    if (!is.null(title)) h4(title),
    build_input_grid(input_defs, max_per_row = max_per_row)
  )
}
