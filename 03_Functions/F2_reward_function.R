f2_reward_function <- function(building_occupied,cost_heating,building_comfort,delta_t) {
  
  # Performance rule
  performance <- ifelse(building_occupied == 1 & building_comfort == 0, -1, 0) * delta_t
  
  # Reward = performance - cost
  reward <- performance - cost_heating
  
  return(reward)
}
