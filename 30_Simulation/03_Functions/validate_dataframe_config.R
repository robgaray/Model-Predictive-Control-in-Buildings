# -------------------------------------------------------------
# Function: validate_dataframe_config.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Validates the columns of a data frame (e.g. Meteo_df, Energy_Prices_df)
# against the rules defined in a Validation_<name>.csv file, following
# the same file_name/parameter_name/type/output/options convention as
# Parameter_config.csv (see validate_parameter_config()), but applied to
# every value of a column vector instead of a single scalar.
# For each matching rule the function checks:
#   - Integer : column is numeric and every value is within [min, max]
#   - Real    : column is numeric and every value is within [min, max]
#     (when options is set)
# Validation failures trigger stop() for output == "Error" or
# warning() for output == "Warning".
# -------------------------------------------------------------
# Arguments
#   df                Data frame. The loaded dataframe to validate
#                     (e.g. Meteo_df).
#   file_name         Character. Base name of the dataframe file, used
#                     to look up its validation rules (e.g.
#                     "Meteo_df.rds").
#   validation_config Data frame. Content of a Validation_<name>.csv
#                     file (same columns as Parameter_config.csv).
# -------------------------------------------------------------
# Returns
#   invisible(TRUE) on success; stops on first Error-class failure.
# -------------------------------------------------------------
# Where this function/script is used
# Called by load_meteo_df.R and load_energy_prices_df.R.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

validate_dataframe_config <- function(df, file_name, validation_config) {

  rules <- validation_config[trimws(as.character(validation_config$file_name)) == file_name, ]

  if (nrow(rules) == 0) {
    return(invisible(TRUE))
  }

  for (CONT_001 in seq_len(nrow(rules))) {

    col_name    <- trimws(as.character(rules$parameter_name[CONT_001]))
    type        <- trimws(as.character(rules$type[CONT_001]))
    output      <- trimws(as.character(rules$output[CONT_001]))
    options_str <- trimws(as.character(rules$options[CONT_001]))

    if (!col_name %in% names(df)) {
      msg <- paste0("Column '", col_name, "' not found in ", file_name)
      if (output == "Error") stop(msg) else warning(msg)
      next
    }

    col_values <- df[[col_name]]

    if (!is.numeric(col_values)) {
      msg <- paste0("Column '", col_name, "' must be numeric in ", file_name)
      if (output == "Error") stop(msg) else warning(msg)
      next
    }

    if ((type == "Integer" || type == "Real") &&
        !is.na(options_str) && nzchar(options_str)) {
      range_vals <- as.numeric(trimws(strsplit(options_str, ",")[[1]]))
      if (length(range_vals) == 2) {
        out_of_range <- col_values < range_vals[1] | col_values > range_vals[2]
        if (any(out_of_range, na.rm = TRUE)) {
          msg <- paste0("Column '", col_name, "' has ", sum(out_of_range, na.rm = TRUE),
                        " value(s) outside [", range_vals[1], ", ", range_vals[2],
                        "] in ", file_name)
          if (output == "Error") stop(msg) else warning(msg)
        }
      }
    }
  }

  rm(CONT_001)
  invisible(TRUE)
}
