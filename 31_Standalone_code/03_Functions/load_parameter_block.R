# -------------------------------------------------------------
# Function: load_parameter_block.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads the block of parameters of a configuration file that holds a
# table below it. The file starts with the header
# parameter,value,unit, the block runs to the first blank line, and
# the table follows that line. The block is validated against the
# rules the parameter catalogue holds for it, as a flat parameter
# file is, and each value is returned in the type of its rule.
# In the catalogue, the rows of a file with a table that have a
# default value are the parameters of its block, and the rows with -
# are the columns of its table. The columns are not validated here:
# the script that reads the table does it.
# The run stops, naming the file, when:
#   - the file does not start with a block that is closed by a blank
#     line before a table
#   - a row of the block names a column of the table, which means the
#     blank line that closes the block is missing
#   - a parameter is duplicated, missing, unknown or invalid
# -------------------------------------------------------------
# Inputs
#   path              : Character. Path of the configuration file. Its
#                       base name is the one its rules are filed under
#                       in the catalogue.
#   validation_config : Named list. The parameter catalogue, as
#                       load_parameter_catalogue() returns it.
# -------------------------------------------------------------
# Outputs
#   Named list. One element per parameter of the block, in the order
#   of the file, in the type of its rule.
# -------------------------------------------------------------
# Code outline
# 1. Read the file and split it into its block and its table
# 2. Separate the rules of the block from those of the table
# 3. Read the block and check it
# 4. Give each value the type of its rule
# -------------------------------------------------------------
# Usage instructions
# deadband <- load_parameter_block(paths$setpoint_mode_file,
#                                  validation_config)
# -------------------------------------------------------------

load_parameter_block <- function(path, validation_config) {

  file_name <- basename(path)

  # 1. Read the file and split it into its block and its table
  # -------------------------------------------------------------
  {
    lines <- readLines(path)

    # split_config_sections is called to find the lines of the block
    # and those of the table.
    sections <- split_config_sections(lines)

    if (length(sections$block) == 0 || length(sections$table) == 0) {
      stop(file_name, " must start with its block of parameters, under ",
           "the header parameter,value,unit, and close it with a blank ",
           "line before its table")
    }
  }

  # 2. Separate the rules of the block from those of the table
  # -------------------------------------------------------------
  {
    rules         <- validation_config$rules[
      validation_config$rules$file == file_name, ]
    is_block_rule <- !rules$default %in% c("", "-")
    block_rules   <- rules[is_block_rule, ]
    column_rules  <- rules[!is_block_rule, ]
  }

  # 3. Read the block and check it
  # -------------------------------------------------------------
  {
    raw_df <- read.csv(
      text             = paste(lines[sections$block], collapse = "\n"),
      comment.char     = "#",
      stringsAsFactors = FALSE
    )
    parameter_names <- trimws(raw_df$parameter)

    in_table <- parameter_names[parameter_names %in% column_rules$parameter]
    if (length(in_table) > 0) {
      stop(file_name, ": ", in_table[1], " is a column of its table; the ",
           "block of parameters must end with a blank line before the table")
    }
    if (anyDuplicated(parameter_names) > 0) {
      stop(file_name, " contains duplicated parameter names: ",
           paste(unique(parameter_names[duplicated(parameter_names)]),
                 collapse = ", "))
    }

    raw_values        <- as.list(raw_df$value)
    names(raw_values) <- parameter_names

    # validate_parameter_config is called with the rules of the block
    # only, so that a parameter that is missing, unknown or invalid
    # stops the run as it does in a flat file, and the columns of the
    # table are not asked for here.
    block_config       <- validation_config
    block_config$rules <- rbind(
      validation_config$rules[validation_config$rules$file != file_name, ],
      block_rules
    )
    validate_parameter_config(
      values            = raw_values,
      file_name         = file_name,
      validation_config = block_config
    )

    rm(list = c("raw_df", "parameter_names", "in_table", "block_config",
                "lines", "sections", "rules", "is_block_rule", "column_rules"))
  }

  # 4. Give each value the type of its rule
  # -------------------------------------------------------------
  {
    # type_parameter_values is called to convert each raw value to the
    # type its rule gives it.
    values <- type_parameter_values(
      raw_values = raw_values,
      rules      = block_rules
    )

    rm(list = c("raw_values", "block_rules", "file_name"))
  }

  return(values)
}
