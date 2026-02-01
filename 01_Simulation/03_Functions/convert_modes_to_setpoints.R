# -------------------------------------------------------------
# Function: convert_modes_to_setpoints.R
# Part of the Model Predictive Control in buildings repository
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# HVAC modes are use to define heating and cooling setpoints
# This function performs a conversion between modes to setpoints
# When more than one mode is active, the one with highest value is selected
# Once the setpoints are defined, the script converts high-level setpoints
# to low-level setpoints with histeresis.
# Also, length correction is performed.
# -------------------------------------------------------------
# INPUT
# setpoint_modes_df : Time series data frame which defines which mode 'maxmode'
#                     is active in each timestep
# setpoint_modes    : Data frame containing a (small) table that defines which
#                     are the heating and cooling setpoint values associated
#                     with each mode.
#                     If not specifically done otherwise, this data frame is
#                     directly loaded from a configuration file at the begining
#                     of the script.
# Deadband          : A single value that defines the deadband associated
#                     to histeresis thermostats.
#                     This is used to convert "exact" setpoints to approximate
#                     setpoints, and avoid excessive activation/deactivation of
#                     HVAC systems.
# periods_target    : Vector of timestamps, not strictly required, but useful if
#                     the output time series has different length thah the input
#                     dataframe. This is required for indexation compatibility.
# pad_xxx           : Padding values to use if the output time series containts
#                     timestamps not present in setpoint_modes_df.
#                     The following are available:
#                         pad_mode: 0 by default
#                         pad_heating: 0 by default
#                         pad_cooling: 50 by default
#
# OUTPUT
# Data frame (df) with columns:
# 'period', 'mode', 'set_point_heating', 'set_point_cooling',
# 'set_point_heating_low', 'set_point_heating_high',
# 'set_point_cooling_low', 'set_point_cooling_high'
# -------------------------------------------------------------

convert_modes_to_setpoints <- function(setpoint_modes_df,
                                       setpoint_modes,
                                       Deadband,
                                       periods_target = NULL,
                                       pad_mode = 0,
                                       pad_heating = 0,
                                       pad_cooling = 50
                                       ) {
  
  # Merge dataframes with modes and setpoints
  df <- merge(setpoint_modes_df,
              setpoint_modes,
              by.x = "maxmode",
              by.y = "mode",
              all.x = TRUE
              )
  
  # Rename columns
  {
    colnames(df)[colnames(df) == "heating"] <- "set_point_heating"
    colnames(df)[colnames(df) == "cooling"] <- "set_point_cooling"
  }
  
  # Adapt for length of output data frame
  if (!is.null(periods_target)) {
    
    n_periods     <- length(periods_target)
    n_setpoints   <- nrow(df)
    
    out <- data.frame(period = periods_target)
    
    if (n_setpoints >= n_periods) {
      # Output data frame is shorter or equal to input data frame
      out$mode              <- df$maxmode[1:n_periods]
      out$set_point_heating <- df$set_point_heating[1:n_periods]
      out$set_point_cooling <- df$set_point_cooling[1:n_periods]
    } else {
      # Output data frame is longer than input data frame
      out$mode              <- c(df$maxmode,               rep(pad_mode,    n_periods - n_setpoints))
      out$set_point_heating <- c(df$set_point_heating,     rep(pad_heating, n_periods - n_setpoints))
      out$set_point_cooling <- c(df$set_point_cooling,     rep(pad_cooling, n_periods - n_setpoints))
    }
    
    df <- out
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
