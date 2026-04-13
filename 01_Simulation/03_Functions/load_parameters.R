# -------------------------------------------------------------
# Function: load_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function reads a CSV configuration file containing model
# parameters and returns them as a named list.
# The CSV file must have at least two columns: 'parameter' and 'value'.
# Lines beginning with '#' are treated as comments and ignored.
# All values are coerced to numeric.
# -------------------------------------------------------------
# Inputs
#   file : Character. Path to the CSV configuration file that defines
#          the model parameters. The file is expected to have columns
#          'parameter' (parameter names) and 'value' (numeric values).
#          Comment lines starting with '#' are ignored.
#          Typical parameters include building thermal model coefficients
#          (e.g. Ci, Ce, Rie, Rea, Aw, Ae), heat pump performance
#          parameters (Q_hp_heat_1, COP_hp_heat_1_coef1, etc.),
#          ventilation resistances, shading factors, and comfort bounds.
#
# Outputs
#   parameters : Named list. Each element corresponds to one row in the
#                CSV file, with the parameter name as key and the numeric
#                value as the element value.
# -------------------------------------------------------------
# Code outline
# 1. Read CSV file with comment lines skipped
# 2. Convert to named list
# 3. Coerce values to numeric
# -------------------------------------------------------------
# Usage instructions
# parameters <- load_parameters(file_path)
# -------------------------------------------------------------
# Where this function/script is used
# Called by data_model_parameters.R to load model, reward, and forecast parameters.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - All values are read as character and coerced to numeric; non-numeric
#     entries will produce NA with a coercion warning.
#   - Comment lines (starting with '#') in the CSV are skipped via the
#     comment.char = "#" argument to read.csv().
#   - No validation of parameter ranges or completeness is performed;
#     the caller is responsible for ensuring all required parameters
#     are present in the file.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

load_parameters <- function(file) {
  
  # Model parameters
  {
    df <- read.csv(file, comment.char = "#",
                   stringsAsFactors = FALSE)
    
    parameters <- as.list(df$value)
    names(parameters) <- df$parameter
    rm(df)
    parameters <- lapply(parameters, as.numeric)
  }
  
  cat("model parameters loaded\n")
  return(parameters)
}
