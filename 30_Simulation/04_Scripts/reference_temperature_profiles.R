# -------------------------------------------------------------
# Script: reference_temperature_profiles.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Generates the service and scheduling temperature profiles used
# by the reward-related comfort calculations.
# Sourced by Main.R before simulation.
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
