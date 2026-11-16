# -------------------------------------------------------------
# Function: check_parameter_relations_gui.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Checks, before saving, the relations two parameters have to keep
# with each other, with the rows of Validation_parameter_relations.csv
# that the simulation applies when it loads the configuration. Each
# row reads
#   left (+ gap) relation right
# A row whose files the GUI does not edit is skipped. A column of a
# table (such as the heating setpoint of the modes) is checked on
# every row of the table. It never stops the app: it returns one
# readable message per relation that fails.
# -------------------------------------------------------------
# Inputs
#   relations      : Data frame. Content of
#                    Validation_parameter_relations.csv, comment rows
#                    skipped, with the columns left_file,
#                    left_parameter, relation, right_file,
#                    right_parameter, gap_file and gap_parameter. Its
#                    units row is skipped here.
#   values_by_file : Named list. For each file the GUI edits, named by
#                    its file name, one of:
#                      - a data frame with the columns parameter and
#                        value
#                      - a table whose columns are the parameters
#                      - for a file with a block of parameters above
#                        a table, a list with the elements parameters
#                        (the data frame of the block) and table
#                        (the data frame of the table)
# -------------------------------------------------------------
# Outputs
#   Character vector. One message per relation that fails; empty when
#   every relation holds.
# -------------------------------------------------------------
# Code outline
# 1. Find a parameter of a file, in its block or in its table
# 2. Check each relation whose files are all edited here
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   check_parameter_relations_gui(relations, values_by_file)
# -------------------------------------------------------------

check_parameter_relations_gui <- function(relations, values_by_file) {

  # 1. Find a parameter of a file, in its block or in its table
  # A name that is a column of the table is taken from the table, and
  # any other from the block.
  # -------------------------------------------------------------
  {
    value_of <- function(file_name, name) {
      table <- values_by_file[[file_name]]
      if (!is.data.frame(table) && is.list(table)) {
        if (name %in% names(table$table)) {
          table <- table$table
        } else {
          table <- table$parameters
        }
      }
      if (all(c("parameter", "value") %in% names(table))) {
        value <- table$value[trimws(as.character(table$parameter)) == name]
      } else {
        value <- table[[name]]
      }
      suppressWarnings(as.numeric(value))
    }

    compare <- list(
      "<"  = function(a, b) a <  b,
      "<=" = function(a, b) a <= b,
      ">"  = function(a, b) a >  b,
      ">=" = function(a, b) a >= b
    )
  }

  # 2. Check each relation whose files are all edited here
  # -------------------------------------------------------------
  {
    messages <- character(0)
    relations <- relations[trimws(relations$relation) %in% names(compare), ,
                           drop = FALSE]

    for (CONT_001 in seq_len(nrow(relations))) {
      row       <- lapply(relations[CONT_001, ], function(x) trimws(as.character(x)))
      has_gap   <- row$gap_parameter != "-"
      files     <- c(row$left_file, row$right_file, if (has_gap) row$gap_file)
      if (!all(files %in% names(values_by_file))) next

      left  <- value_of(row$left_file, row$left_parameter)
      right <- value_of(row$right_file, row$right_parameter)
      gap   <- if (has_gap) value_of(row$gap_file, row$gap_parameter) else 0

      # A value that is not a number is already reported by the
      # checks of each file, so only numbers are compared here.
      if (length(left) == 0 || length(right) == 0 || length(gap) == 0) next
      holds <- compare[[row$relation]](left + gap, right)
      if (any(!holds, na.rm = TRUE)) {
        messages <- c(messages, paste0(
          row$left_parameter,
          if (has_gap) paste0(" + ", row$gap_parameter) else "",
          " must be ", row$relation, " ", row$right_parameter,
          if (length(holds) > 1) paste0(" on every row (fails on row ",
                                        which(!holds)[1], ")") else "",
          " (", row$left_file, ")."
        ))
      }
    }
  }

  return(messages)
}
