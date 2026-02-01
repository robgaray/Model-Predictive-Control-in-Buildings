# -------------------------------------------------------------
# Function: convert_setpoints.R
# Part of the Model Predictive Control in buildings repository
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function converts high-level setpoints to low-level setpoints with histeresis
# Also, length correction is performed.
# -------------------------------------------------------------
# INPUT
# setpoints_heating : Vector or time series containing the heating setpoints
# setpoints_cooling : Vector or time series containing the cooling setpoints
# Deadband          : A single value that defines the deadband associated
#                     to histeresis thermostats. 1 by default.
#                     This is used to convert "exact" setpoints to approximate
#                     setpoints, and avoid excessive activation/deactivation of
#                     HVAC systems.
# periods_target    : Vector of timestamps, not strictly required, but useful if
#                     the output time series has different length thah the input
#                     dataframe. This is required for indexation compatibility.
# pad_xxx           : Padding values to use if the output time series containts
#                     timestamps not present in setpoint_modes_df.
#                     The following are available:
#                         pad_heating: 0 by default
#                         pad_cooling: 50 by default
#
# OUTPUT
# Data frame (df) with columns:
# 'period', 'mode', 'set_point_heating', 'set_point_cooling',
# 'set_point_heating_low', 'set_point_heating_high',
# 'set_point_cooling_low', 'set_point_cooling_high'
# -------------------------------------------------------------
convert_setpoints <- function(setpoints_heating,
                              setpoints_cooling,
                              Deadband = 1,
                              periods_target = NULL,
                              pad_heating = 0,
                              pad_cooling = 50
                              ) {
  
  # Adapt for length of output data frame
  n_hours     <- length(periods_target)
  n_setpoints <- length(setpoints_heating)
  
  df <- data.frame(period = periods_target)
  
  if (n_setpoints >= n_hours) {
    df$set_point_heating <- setpoints_heating[1:n_hours]
    df$set_point_cooling <- setpoints_cooling[1:n_hours]
  } else {
    df$set_point_heating <- c(setpoints_heating,
                              rep(pad_heating, n_hours - n_setpoints))
    df$set_point_cooling <- c(setpoints_cooling,
                              rep(pad_cooling, n_hours - n_setpoints))
  }
  
  # Apply deadbands
  {
    df$set_point_heating_low  <- df$set_point_heating - Deadband / 2
    df$set_point_heating_high <- df$set_point_heating + Deadband / 2
    df$set_point_cooling_low  <- df$set_point_cooling - Deadband / 2
    df$set_point_cooling_high <- df$set_point_cooling + Deadband / 2
  }
  
  return(df)
}
