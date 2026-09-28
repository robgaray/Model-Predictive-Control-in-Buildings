# -------------------------------------------------------------
# Script: 07_reference_temperature_profiles.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Generates the service and scheduling temperature profiles used
# by the reward-related comfort calculations.
# Sourced by Main.R before simulation.
# -------------------------------------------------------------
# Inputs
#   Main_df, with its Occupancy, Scheduling and Overall_Climate
#     columns.
#   parameters$reward : the service and setback comfort bands, and
#     the shifts applied to them while the building is prepared.
# -------------------------------------------------------------
# Outputs
#   Main_df, with the reference temperature profiles the comfort
#     term of the reward is measured against.
# -------------------------------------------------------------
# Code outline
# 1. Check the Occupancy, Scheduling and Overall_Climate columns.
# 2. Service band of each row: the service band where the building
#    is occupied, the setback band where it is not.
# 3. Scheduling band of each row: the service band where Scheduling
#    is 1, shifted by the climate of the day, and the service band
#    of step 2 everywhere else.
# -------------------------------------------------------------
# Usage instructions
#   Not called: sourced by Main.R before the simulation, and
#   after the occupancy and scheduling profiles it reads.
# -------------------------------------------------------------
# Where this function/script is used
# Sourced by 30_Simulation/Main.R.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

{
  if (!is.integer(Main_df$Occupancy) || any(!Main_df$Occupancy %in% c(0L, 1L))) {
    stop("Main_df$Occupancy must be integer with values 0/1")
  }
  if (!is.integer(Main_df$Scheduling) || any(!Main_df$Scheduling %in% c(0L, 1L))) {
    stop("Main_df$Scheduling must be integer with values 0/1")
  }
  if (any(!Main_df$Overall_Climate %in% c("Heating", "Cooling", "Intermediate"))) {
    stop("Main_df$Overall_Climate contains invalid values")
  }

  Main_df$Service_T_Low <- ifelse(
    Main_df$Occupancy == 1L,
    parameters$reward$Service_T_Low,
    parameters$reward$Setback_T_Low
  )
  Main_df$Service_T_High <- ifelse(
    Main_df$Occupancy == 1L,
    parameters$reward$Service_T_High,
    parameters$reward$Setback_T_High
  )

  heating_like <- Main_df$Overall_Climate %in% c("Heating", "Intermediate")
  cooling_like <- Main_df$Overall_Climate %in% c("Cooling", "Intermediate")

  Main_df$Scheduling_T_Low <- ifelse(
    Main_df$Scheduling == 1L & heating_like,
    parameters$reward$Service_T_Low + parameters$reward$Service_AT_Low_Sched_HDD,
    ifelse(
      Main_df$Scheduling == 1L,
      parameters$reward$Service_T_Low,
      Main_df$Service_T_Low
    )
  )
  Main_df$Scheduling_T_High <- ifelse(
    Main_df$Scheduling == 1L & cooling_like,
    parameters$reward$Service_T_High - parameters$reward$Service_AT_High_Sched_CDD,
    ifelse(
      Main_df$Scheduling == 1L,
      parameters$reward$Service_T_High,
      Main_df$Service_T_High
    )
  )

  rm(heating_like, cooling_like)

  cat("Reference temperature profiles generated\n")
}
