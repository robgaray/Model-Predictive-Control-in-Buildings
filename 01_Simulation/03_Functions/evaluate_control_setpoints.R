# -------------------------------------------------------------
# Function: evaluate_control_setpoints.R
# Part of the Model Predictive Control in buildings repository
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function evaluates the optimality of a particular setpoint
# sequence over a particular period.
# This is a wrapper function that allows to integrate an optimizer with
# a simulation code in "period_calculation".
# It performs the following steps:
#   1. Converts the setpoints to setpoints with histeresis
#   2. Calls the period_calculation function to simulate the building
#      and energy system operation over the period
#   3. Sums-up the reward over the period
#   4. Sums-up the reward over the period
# -------------------------------------------------------------
# INPUT:
# period_chunk: Data frame containing the data for the period to evaluate
# setpoints_heating: Vector or time series containing the heating setpoints
# setpoints_cooling: Vector or time series containing the cooling setpoints
# parameters: List containing the model parameters to be passed-on to the simulator.
# Deadband: Numeric value defining the deadband for histeresis controllers
# -------------------------------------------------------------
evaluate_control_setpoints <- function(period_chunk,
                                       setpoints_heating,
                                       setpoints_cooling,
                                       parameters,
                                       Deadband
                                       ) {
  # Creates the set_point_df using the provided setpoint ranges 
  {
    periods_target <- sort(unique(period_chunk$MarketUTC))
    
    set_point_df <- convert_setpoints(
      setpoints_heating = setpoints_heating,
      setpoints_cooling = setpoints_cooling,
      Deadband          = Deadband,
      periods_target    = periods_target
    )
  }
  
  # Calculate the evolution of the building and the energy system
  period_chunk <- period_calculation(period_chunk, set_point_df, parameters)
  
  # Calculate reward
  reward <- sum(period_chunk$reward)
  
  # Take reward as output for the GA optimization
  return(reward)
}
