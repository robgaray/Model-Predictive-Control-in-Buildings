# -------------------------------------------------------------
# Function: build_file_editor.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds the editor of a whole flat parameter file, or of the block
# of parameters of a file that holds a table below it, from the
# parameter catalogue: the parameters of the file and their order
# are the rows of the catalogue for that file that have a default
# value (the columns of a table have - instead), the groups are its
# blocks (in the order in which they first appear), and the
# parameters of type Options are dropdowns with the options of the
# catalogue. The parameters of a file with no block (the block is -)
# go in one group with no title.
# When the catalogue holds no row for the file, the parameters are
# the ones in the table, in one group with no title and with no
# dropdowns: the app keeps working with what the file holds.
# -------------------------------------------------------------
# Inputs
#   df               : Data frame (parameter, value). The values of
#                      the file, as the safe loader returns them.
#   prefix           : Character. Prefix of the input ids of the
#                      file.
#   file_label       : Character. File name of the configuration
#                      file, as the catalogue names it.
#   validation_config: Named list. The rules of the catalogue and
#                      the integer tolerance, as load_gui_catalogue()
#                      returns them.
#   defaulted        : Character vector. Parameters whose value
#                      came from the defaults.
#   duplicated       : Character vector. Parameters found more
#                      than once in the file.
#   max_per_row      : Integer. Number of inputs on each row.
#   hidden           : Character vector. Parameters of the file that
#                      the editor does not show, because another tab
#                      holds their inputs (character(0) for none).
# -------------------------------------------------------------
# Outputs
#   A tagList with one panel per block of the file.
# -------------------------------------------------------------
# Code outline
# 1. Take the rows of the catalogue for the file, or the parameters
#    of the table when there are none, without the hidden ones.
# 2. Take the options of the closed-list parameters.
# 3. Build one panel per block with build_group_editor().
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   build_file_editor(
#     df,
#     prefix,
#     file_label,
#     validation_config,
#     defaulted,
#     duplicated,
#     max_per_row,
#     hidden)
# -------------------------------------------------------------

build_file_editor <- function(df, prefix, file_label, validation_config,
                              defaulted, duplicated, max_per_row, hidden) {

  # 1. Take the rows of the catalogue for the file, or the parameters
  # of the table when there are none, without the hidden ones
  # -------------------------------------------------------------
  {
    rules <- validation_config$rules
    rows  <- rules[rules$file == file_label & rules$default != "-", ,
                   drop = FALSE]

    if (nrow(rows) == 0) {
      parameters <- trimws(as.character(df$parameter))
      blocks     <- rep("-", length(parameters))
    } else {
      parameters <- rows$parameter
      blocks     <- rows$block
    }
    shown      <- !parameters %in% hidden
    parameters <- parameters[shown]
    blocks     <- blocks[shown]
    rm(rules, shown)
  }

  # 2. Take the options of the closed-list parameters
  # -------------------------------------------------------------
  {
    options_list <- list()
    for (CONT_001 in parameters) {
      # validation_options is called to take the allowed options of
      # the parameter from the catalogue, NULL when it has none.
      parameter_options <- validation_options(
        validation_config = validation_config,
        file_name         = file_label,
        param_name        = CONT_001
      )
      if (!is.null(parameter_options)) {
        options_list[[CONT_001]] <- parameter_options
      }
      rm(parameter_options)
    }
  }

  # 3. Build one panel per block with build_group_editor()
  # -------------------------------------------------------------
  {
    panels <- lapply(
      unique(blocks),
      function(block) {
        # build_group_editor is called to lay out the inputs of this
        # block in one panel, titled with the block unless the file
        # has no blocks.
        build_group_editor(
          df           = df,
          prefix       = prefix,
          title        = if (block == "-") NULL else block,
          parameters   = parameters[blocks == block],
          options_list = options_list,
          defaulted    = defaulted,
          duplicated   = duplicated,
          file_key     = file_label,
          max_per_row  = max_per_row
        )
      }
    )
    rm(rows, parameters, blocks, options_list)
  }

  return(do.call(tagList, panels))
}
