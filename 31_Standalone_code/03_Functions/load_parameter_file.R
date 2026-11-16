# -------------------------------------------------------------
# Function: load_parameter_file.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads one parameter/value configuration file: it reads the file,
# validates every value against the rules the parameter catalogue
# holds for it, and returns each value in the type of its rule. No
# parameter name is written here: the names are those of the file,
# and the types those of the catalogue, so adding a parameter is one
# line of the file and one row of the catalogue.
# -------------------------------------------------------------
# Inputs
#   path              : Character. Path of the configuration file. Its
#                       base name is the one its rules are filed under
#                       in the catalogue.
#   validation_config : Named list. The parameter catalogue, as
#                       load_parameter_catalogue() returns it.
# -------------------------------------------------------------
# Outputs
#   Named list. One element per parameter, in the order of the file,
#   in the type of its rule.
# -------------------------------------------------------------
# Code outline
# 1. Read and validate the file
# 2. Give each value the type of its rule
# -------------------------------------------------------------
# Usage instructions
# parameters$reward <- load_parameter_file(paths$reward_file,
#                                          validation_config)
# -------------------------------------------------------------

load_parameter_file <- function(path, validation_config) {

  # 1. Read and validate the file
  # -------------------------------------------------------------
  {
    file_name <- basename(path)

    # read_and_validate_parameter_csv is called to read the file and
    # check every value against its rules, stopping on the first
    # breach before any value is converted.
    raw_values <- read_and_validate_parameter_csv(
      path,
      file_name,
      validation_config
    )
  }

  # 2. Give each value the type of its rule
  # -------------------------------------------------------------
  {
    rules <- validation_config$rules[validation_config$rules$file == file_name, ]

    # type_parameter_values is called to convert each raw value to the
    # type its rule gives it.
    values <- type_parameter_values(
      raw_values = raw_values,
      rules      = rules
    )

    rm(list = c("file_name", "raw_values", "rules"))
  }

  return(values)
}
