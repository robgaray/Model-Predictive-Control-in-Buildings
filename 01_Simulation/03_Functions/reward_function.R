# -------------------------------------------------------------
# Function: reward_function.R
# Part of the Model Predictive Control in buildings repository
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function calculates a reward function on the adequacy of
# a particular building HVAC operation.
# It is designed to be used for numeric(1) values.
# It considers the following criteria:
#   cost of energy
#   the occupancy (if the building is NOT occupied, confort
#   is not relevant)
#   if the building is in confort or not
# The criteria is weighted considering the following parameters:
#   Alpha_confort: weight of the confort term
# The reward is multiplied with the timestep length for
# compatibility with different time steps.
# -------------------------------------------------------------
reward_function <- function(building_occupied,
                            cost_heating,
                            building_comfort,
                            delta_t,
                            parameters
                            ) {
  
  # 1. Get the Alpha coefficient from the parameter list
  # If this is not available, a default value is used and a warning provided.
  if(!is.null(parameters$Alpha_confort)) {
    Alpha_confort <- parameters$Alpha_confort
  } else {
    warning("Alpha_confort was not found. A default value of Alpha_confort=10 is used.")
    Alpha_confort <- 10
  }
  
  # 2. Performance rule
  # performance = -1 if the building is occupied and not comfortable
  performance <- ifelse(building_occupied == 1 & building_comfort == 0, -1, 0) * delta_t
  
  # 3. Reward calculation
  # Reward = performance (weighted) - coste
  # Cost is already in energy cost per timestep
    reward <- Alpha_confort * performance - cost_heating
  
  return(reward)
}