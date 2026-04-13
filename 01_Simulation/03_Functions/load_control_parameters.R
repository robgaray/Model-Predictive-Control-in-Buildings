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
# All values are coerced to numeric.
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
#                    control_type                 – control strategy type (1 = setpoint, 2 = modes)
#                    set_point_default_cooling    – default cooling setpoint (°C)
#                    set_point_default_heating    – default heating setpoint (°C)
#                    mode_default                 – default control mode index
#                    optimization_aim             – optimization objective code
#                    flexibility_event_length_max – maximum duration of a flexibility event (h)
#                    flexibility_recover_timespan – duration of the recovery period after a flexibility event (h)
#                    thermal_stabilization_timespan – duration of the thermal stabilisation period (h)
#                    flexibility_commitment       – fraction of flexibility commitment (-)
#                    minimum_flexibility          – minimum flexibility power (kW)
#                    minimum_spare_capacity       – minimum spare capacity power (kW)
#                    flexibility_splits           – number of flexibility fraction steps for parametric evaluation
#
# Outputs
#   A named list with the following elements:
#     set_point_range_heating   : Numeric vector of length 2. [low, high] bounds.
#     set_point_range_cooling   : Numeric vector of length 2. [low, high] bounds.
#     Deadband                  : Numeric scalar. Deadband width (°C).
#     control_type              : Numeric scalar. Control strategy type.
#     set_point_default_cooling : Numeric scalar. Default cooling setpoint (°C).
#     set_point_default_heating : Numeric scalar. Default heating setpoint (°C).
#     mode_default              : Numeric scalar. Default mode index.
#     optimization_aim          : Numeric scalar. Optimization objective code.
#     flexibility_event_length_max : Numeric scalar. Maximum duration of a flexibility event (h).
#     flexibility_recover_timespan : Numeric scalar. Duration of the recovery period after a flexibility event (h).
#     thermal_stabilization_timespan : Numeric scalar. Duration of the thermal stabilisation period (h).
#     flexibility_commitment    : Numeric scalar. Fraction of flexibility commitment (-).
#     minimum_flexibility       : Numeric scalar. Minimum flexibility power (kW).
#     minimum_spare_capacity    : Numeric scalar. Minimum spare capacity power (kW).
#     flexibility_splits        : Numeric scalar. Number of flexibility fraction steps for parametric evaluation.
# -------------------------------------------------------------
# Code outline
# 1. Read CSV configuration file
# 2. Convert to named list with numeric values
# -------------------------------------------------------------
# Usage instructions
# params <- load_control_parameters(file_path)
# -------------------------------------------------------------
# Where this function/script is used
# Called by control_optimization_parameters.R and control_optimization_parameters_SCC.R
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If any expected parameter is absent from the file, the corresponding
#     list element will be NA (due to missing value coercion via as.numeric).
#   - All values are read as character and then coerced to numeric; non-numeric
#     entries in the 'value' column will produce NA with a coercion warning.
#   - Comment lines (starting with '#') in the CSV are skipped via the
#     comment.char = "#" argument to read.csv().
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

load_control_parameters <- function(control_file) {
  
  # Setpoint parameters
  {
    df <- read.csv(control_file, comment.char = "#",
                   stringsAsFactors = FALSE)
    
    values <- as.list(df$value)
    names(values) <- df$parameter
    rm(df)
    values <- lapply(values, as.numeric)
    
    set_point_range_heating <- c(values$set_point_range_heating_low,
                                 values$set_point_range_heating_high)
    
    set_point_range_cooling <- c(values$set_point_range_cooling_low,
                                 values$set_point_range_cooling_high)
    
    Deadband <- values$Deadband
    
    control_type <- values$control_type
    
    set_point_default_cooling <- values$set_point_default_cooling
    set_point_default_heating <- values$set_point_default_heating
    
    mode_default <- values$mode_default
    
    optimization_aim <- values$optimization_aim
    
    flexibility_event_length_max  <- values$flexibility_event_length_max
    flexibility_recover_timespan      <- values$flexibility_recover_timespan
    thermal_stabilization_timespan    <- values$thermal_stabilization_timespan
    flexibility_commitment    <- values$flexibility_commitment
    minimum_flexibility       <- values$minimum_flexibility
    minimum_spare_capacity    <- values$minimum_spare_capacity
    flexibility_splits        <- values$flexibility_splits
    rm(values)
  }
  
  cat("setpoint bands loaded\n")
  
  return(list(
    set_point_range_heating   = set_point_range_heating,
    set_point_range_cooling   = set_point_range_cooling,
    Deadband                  = Deadband,
    control_type              = control_type,
    set_point_default_cooling = set_point_default_cooling,
    set_point_default_heating = set_point_default_heating,
    mode_default              = mode_default,
    optimization_aim          = optimization_aim,
    flexibility_event_length_max  = flexibility_event_length_max,
    flexibility_recover_timespan      = flexibility_recover_timespan,
    thermal_stabilization_timespan    = thermal_stabilization_timespan,
    flexibility_commitment    = flexibility_commitment,
    minimum_flexibility       = minimum_flexibility,
    minimum_spare_capacity    = minimum_spare_capacity,
    flexibility_splits        = flexibility_splits
  ))
}
