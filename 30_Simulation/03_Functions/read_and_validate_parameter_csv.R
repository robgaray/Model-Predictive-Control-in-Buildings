# -------------------------------------------------------------
# Function: read_and_validate_parameter_csv.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Reads a simple parameter/value CSV configuration file and
# validates its raw values against the parameter catalogue. This is
# the common first step shared by every load_XX_*.R script that
# reads a plain parameter/value file (as opposed to a multi-column
# table such as 14_Use_Patterns.csv or the market config tables).
# -------------------------------------------------------------
# Inputs
# path              : Character. Path to the parameter/value CSV file.
# file_name         : Character. Base name of the config file, used to
#                     look up its validation rules (e.g.
#                     "09_Reward_parameters.csv").
# validation_config : Named list. The parameter catalogue, as
#                     load_parameter_catalogue() returns it.
# -------------------------------------------------------------
# Outputs
# Named list. parameter_name -> raw value (character or numeric),
# already validated against validation_config.
# -------------------------------------------------------------
# Code outline
# 1. Read the CSV file and build the named list of raw values
# 2. Validate that no parameter name is duplicated
# 3. Validate the raw values against validation_config
# -------------------------------------------------------------
# Usage instructions
# raw_values <- read_and_validate_parameter_csv(paths$reward_file,
# "09_Reward_parameters.csv", validation_config)
# -------------------------------------------------------------

read_and_validate_parameter_csv <- function(path, file_name, validation_config) {

  raw_df          <- read.csv(path, comment.char = "#", stringsAsFactors = FALSE)
  parameter_names <- trimws(raw_df$parameter)

  if (anyDuplicated(parameter_names) > 0) {
    stop(file_name, " contains duplicated parameter names: ",
         paste(unique(parameter_names[duplicated(parameter_names)]), collapse = ", "))
  }

  raw_values <- as.list(raw_df$value)
  names(raw_values) <- parameter_names
  rm(list = c("raw_df", "parameter_names"))

  # validate_parameter_config is called to check every raw value read
  # above against the type/range/options rules of the catalogue,
  # stopping execution here if any value is invalid, before the caller
  # ever receives the raw_values list.
  validate_parameter_config(raw_values, file_name, validation_config)

  return(raw_values)
}
