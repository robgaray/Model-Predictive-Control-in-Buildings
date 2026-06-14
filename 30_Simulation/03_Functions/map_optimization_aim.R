# -------------------------------------------------------------
# Function: map_optimization_aim.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK5
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Maps raw market aim values to internal optimization aim labels.
# Accepted input values (case-insensitive): O, E, O+F, E+F.
# Any other value produces an error.
# -------------------------------------------------------------
# Inputs
# aim_raw      : Scalar value with market aim code.
# column_name  : Character. Source column name for error messages.
# row_index    : Integer. Current simulation row for error messages.
# -------------------------------------------------------------
# Outputs
# Character. "energy", "flexibility", "operation" of
#            "operationflex".
# -------------------------------------------------------------
# Usage instructions
# map_optimization_aim(aim_raw, column_name, row_index)
# -------------------------------------------------------------
# Where this function/script is used
# Called by run_market_process(), load_15_market_config.R,
# market_columns_setup.R.
# -------------------------------------------------------------
# functions/scripts called
# (none)
# -------------------------------------------------------------

map_optimization_aim <- function(aim_raw,
                                 column_name,
                                 row_index) {
  aim_chr <- toupper(trimws(as.character(aim_raw)[1]))

  if (aim_chr %in% c("E", "O")) {
    return("energy")
  }

  if (aim_chr %in% c("E+F", "O+F")) {
    return("flexibility")
  }
  
  if(aim_chr %in% c("VACIO", "VACIO")) {
    return("operation")
  }
  
  if(aim_chr %in% c("VACIO", "VACIO")) {
    return("operationflex")
  }

  stop("Invalid market aim '", aim_chr, "' at row ", row_index,
       " in column ", column_name,
       ". Accepted values: O, E, O+F, E+F.")
}
