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
#   parameters$reward : the service and setback comfort bands.
#   parameters$operational_temperature_corrections : the shifts
#     applied to the service band while the building is prepared.
# -------------------------------------------------------------
# Outputs
#   Main_df, with the reference temperature profiles the comfort
#     term of the reward is measured against:
#     - Service_T_Low/High: the occupancy band. The executed
#       operation, and the flexibility itineraries inside their
#       windows, are measured against it.
#     - Scheduling_T_Low/High: the more restrictive of the occupancy
#       band and the scheduling band. The plan, and the flexibility
#       itineraries outside their windows, are measured against it.
# -------------------------------------------------------------
# Code outline
# 1. Check the Occupancy, Scheduling and Overall_Climate columns.
# 2. Service band of each row: the service band where the building
#    is occupied, the setback band where it is not.
# 3. Scheduling band of each row: the service band where Scheduling
#    is 1, shifted by the climate of the day, and the service band
#    of step 2 everywhere else.
# 4. Plan band: the more restrictive of the bands of steps 2 and 3,
#    stored in Scheduling_T_*. The run stops if it is empty on any row.
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
  corrections  <- parameters$operational_temperature_corrections

  scheduling_low <- ifelse(
    Main_df$Scheduling == 1L & heating_like,
    parameters$reward$Service_T_Low + corrections$Service_AT_Low_Sched_HDD,
    ifelse(
      Main_df$Scheduling == 1L,
      parameters$reward$Service_T_Low,
      Main_df$Service_T_Low
    )
  )
  scheduling_high <- ifelse(
    Main_df$Scheduling == 1L & cooling_like,
    parameters$reward$Service_T_High - corrections$Service_AT_High_Sched_CDD,
    ifelse(
      Main_df$Scheduling == 1L,
      parameters$reward$Service_T_High,
      Main_df$Service_T_High
    )
  )

  # The band the plan is measured against is the more restrictive of
  # the scheduling band and the occupancy band. The scheduling
  # corrections may be negative, which would make the scheduling band
  # wider than the occupancy band; the intersection keeps the occupancy
  # band as a floor in that case.
  Main_df$Scheduling_T_Low  <- pmax(Main_df$Service_T_Low,  scheduling_low)
  Main_df$Scheduling_T_High <- pmin(Main_df$Service_T_High, scheduling_high)

  empty_band <- Main_df$Scheduling_T_Low >= Main_df$Scheduling_T_High
  if (any(empty_band)) {
    stop("The comfort band is empty (Scheduling_T_Low >= Scheduling_T_High) on ",
         sum(empty_band), " rows, the first at ", format(Main_df$time[which(empty_band)[1]]),
         ". Check Service_T_Low/High and Setback_T_Low/High in 09_Reward_parameters.csv",
         " and Service_AT_Low_Sched_HDD/Service_AT_High_Sched_CDD in",
         " 10_Operational_temperature_corrections.csv")
  }

  rm(heating_like, cooling_like, corrections, scheduling_low, scheduling_high, empty_band)

  cat("Reference temperature profiles generated\n")
}
