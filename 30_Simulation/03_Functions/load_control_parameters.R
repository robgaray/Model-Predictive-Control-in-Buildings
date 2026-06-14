# -------------------------------------------------------------
# Function: load_control_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function reads a CSV configuration file containing control
# parameters and returns them as a named list.
# The CSV file must have at least two columns: 'parameter' and 'value'.
# Lines beginning with '#' are treated as comments and ignored.
# Numeric values are coerced to numeric. The control_type parameter
# is read as text ("modes" or "setpoints") and returned as-is.
# -------------------------------------------------------------
# Inputs
#   control_file : Character. Path to the CSV configuration file that
#                  defines control parameters. Expected parameters in
#                  the file are:
#                    set_point_range_heating_low  – lower bound of heating setpoint range (°C)
#                    set_point_range_heating_high – upper bound of heating setpoint range (°C)
#                    set_point_range_cooling_low  – lower bound of cooling setpoint range (°C)
#                    set_point_range_cooling_high – upper bound of cooling setpoint range (°C)
#                    Deadband                     – deadband width for histeresis control (°C)
#                    control_type                 – control strategy type ("modes" or "setpoints")
#                    set_point_default_cooling    – default cooling setpoint (°C)
#                    set_point_default_heating    – default heating setpoint (°C)
#                    optimization_aim             – optimization objective code
#                    flexibility_event_length_max – maximum duration of a flexibility event (h)
#                    flexibility_recover_timespan – duration of the recovery period after a flexibility event (h)
#                    thermal_stabilization_timespan – duration of the thermal stabilisation period (h)
#                    minimum_flexibility          – minimum flexibility power (kW)
#                    flexibility_splits           – number of flexibility fraction steps for parametric evaluation
#
# Outputs
#   A named list with the following elements:
#     set_point_range_heating   : Numeric vector of length 2. [low, high] bounds.
#     set_point_range_cooling   : Numeric vector of length 2. [low, high] bounds.
#     Deadband                  : Numeric scalar. Deadband width (°C).
#     control_type              : Character scalar. "modes" or "setpoints".
#     set_point_default_cooling : Numeric scalar. Default cooling setpoint (°C).
#     set_point_default_heating : Numeric scalar. Default heating setpoint (°C).
#     optimization_aim          : Numeric scalar. Optimization objective code.
#     flexibility_event_length_max : Numeric scalar. Maximum duration of a flexibility event (h).
#     flexibility_recover_timespan : Numeric scalar. Duration of the recovery period after a flexibility event (h).
#     thermal_stabilization_timespan : Numeric scalar. Duration of the thermal stabilisation period (h).
#     minimum_flexibility       : Numeric scalar. Minimum flexibility power (kW).
#     flexibility_splits        : Numeric scalar. Number of flexibility fraction steps for parametric evaluation.
# -------------------------------------------------------------
# Code outline
# 1. Read CSV configuration file
# 2. Extract control_type as text; convert all other values to numeric
# -------------------------------------------------------------
# Usage instructions
# params <- load_control_parameters(file_path)
# -------------------------------------------------------------
# Where this function/script is used
# Called by control_optimization_parameters.R and control_optimization_parameters_SCC.R
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - control_type must be "modes" or "setpoints"; any other value will produce
#     an error when validated by validate_parameter_config().
#   - All non-text values are read as character and then coerced to numeric;
#     non-numeric entries in the 'value' column will produce NA with a coercion
#     warning.
#   - Comment lines (starting with '#') in the CSV are skipped via the
#     comment.char = "#" argument to read.csv().
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

load_control_parameters <- function(control_file) {
  
  # Read CSV and separate text vs numeric parameters
  {
    df <- read.csv(control_file, comment.char = "#",
                   stringsAsFactors = FALSE)
    
    values <- as.list(df$value)
    names(values) <- df$parameter
    rm(df)
    
    control_type <- trimws(as.character(values$control_type))
    
    text_params <- c("control_type")
    numeric_values <- lapply(
      values[!names(values) %in% text_params],
      as.numeric
    )
    rm(values)
    
    set_point_range_heating <- c(numeric_values$set_point_range_heating_low,
                                 numeric_values$set_point_range_heating_high)
    
    set_point_range_cooling <- c(numeric_values$set_point_range_cooling_low,
                                 numeric_values$set_point_range_cooling_high)
    
    Deadband <- numeric_values$Deadband
    
    set_point_default_cooling <- numeric_values$set_point_default_cooling
    set_point_default_heating <- numeric_values$set_point_default_heating
    
    flexibility_event_length_max  <- numeric_values$flexibility_event_length_max
    flexibility_recover_timespan      <- numeric_values$flexibility_recover_timespan
    thermal_stabilization_timespan    <- numeric_values$thermal_stabilization_timespan
    minimum_flexibility       <- numeric_values$minimum_flexibility
    flexibility_splits        <- numeric_values$flexibility_splits
    rm(numeric_values)
  }
  
  cat("setpoint bands loaded\n")
  
  return(list(
    set_point_range_heating   = set_point_range_heating,
    set_point_range_cooling   = set_point_range_cooling,
    Deadband                  = Deadband,
    control_type              = control_type,
    set_point_default_cooling = set_point_default_cooling,
    set_point_default_heating = set_point_default_heating,
    flexibility_event_length_max  = flexibility_event_length_max,
    flexibility_recover_timespan      = flexibility_recover_timespan,
    thermal_stabilization_timespan    = thermal_stabilization_timespan,
    minimum_flexibility       = minimum_flexibility,
    flexibility_splits        = flexibility_splits
  ))
}
