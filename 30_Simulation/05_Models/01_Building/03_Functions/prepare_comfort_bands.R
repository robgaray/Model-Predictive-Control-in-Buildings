# -------------------------------------------------------------
# Function: prepare_comfort_bands.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Generates the service and scheduling temperature profiles used
# by the reward-related comfort calculations.
# -------------------------------------------------------------
# Inputs
#   asset_df                            : data frame, the table of the
#                                         building, with its
#                                         Occupancy, Scheduling and
#                                         Overall_Climate columns.
#   comfort                             : List. The comfort group of
#     the building, in its entry of parameters$assets, with the
#     service and setback comfort bands:
#     - Service_T_Low and Service_T_High [degC]
#     - Setback_T_Low and Setback_T_High [degC]
#   operational_temperature_corrections : List. The shifts applied to
#     the service band while the building is prepared,
#     those of the building, in its entry of parameters$assets:
#     - Service_AT_Low_Sched_HDD [degC]
#     - Service_AT_High_Sched_CDD [degC]
# -------------------------------------------------------------
# Outputs
#   asset_df, as received, with the reference temperature profiles
#   the comfort term of the reward is measured against:
#   - Service_T_Low/High: the occupancy band. The executed
#     operation, and the flexibility itineraries inside their
#     windows, are measured against it.
#   - Scheduling_T_Low/High: the more restrictive of the occupancy
#     band and the scheduling band. The plan, and the flexibility
#     itineraries outside their windows, are measured against it.
# -------------------------------------------------------------
# Code outline
# 1. Check the Occupancy, Scheduling and Overall_Climate columns.
# 2. Service band of each row: the service band where the building
#    is occupied, the setback band where it is not.
# 3. Scheduling band of each row: the service band where Scheduling
#    is 1, shifted by the climate of the day, and the service band
#    of step 2 everywhere else.
# 4. Plan band: the more restrictive of the bands of steps 2 and 3,
#    stored in Scheduling_T_*. The run stops if it is empty on any
#    row.
# -------------------------------------------------------------
# Usage instructions
# asset_df <- prepare_comfort_bands(
#   asset_df                            = asset_df,
#   comfort                             =
#     parameters$assets[[1]]$comfort,
#   operational_temperature_corrections =
#     parameters$assets[[1]]$operational_temperature_corrections
# )
# -------------------------------------------------------------
prepare_comfort_bands <- function(asset_df,
                                  comfort,
                                  operational_temperature_corrections
                                  ) {

  # -------------------------------------------------------------
  # 1. Check the Occupancy, Scheduling and Overall_Climate columns
  # -------------------------------------------------------------
  {
    if (!is.integer(asset_df$Occupancy) ||
        any(!asset_df$Occupancy %in% c(0L, 1L))) {
      stop("asset_df$Occupancy must be integer with values 0/1")
    }
    if (!is.integer(asset_df$Scheduling) ||
        any(!asset_df$Scheduling %in% c(0L, 1L))) {
      stop("asset_df$Scheduling must be integer with values 0/1")
    }
    if (any(!asset_df$Overall_Climate %in%
            c("Heating", "Cooling", "Intermediate"))) {
      stop("asset_df$Overall_Climate contains invalid values")
    }
  }

  # -------------------------------------------------------------
  # 2. Service band of each row
  # The service band where the building is occupied, the setback
  # band where it is not.
  # -------------------------------------------------------------
  {
    asset_df$Service_T_Low <- ifelse(
      asset_df$Occupancy == 1L,
      comfort$Service_T_Low,
      comfort$Setback_T_Low
    )
    asset_df$Service_T_High <- ifelse(
      asset_df$Occupancy == 1L,
      comfort$Service_T_High,
      comfort$Setback_T_High
    )
  }

  # -------------------------------------------------------------
  # 3. Scheduling band of each row
  # The service band, shifted by the climate of the day, where
  # Scheduling is 1, and the service band of step 2 everywhere else.
  # -------------------------------------------------------------
  {
    heating_like <- asset_df$Overall_Climate %in% c("Heating", "Intermediate")
    cooling_like <- asset_df$Overall_Climate %in% c("Cooling", "Intermediate")

    scheduling_low <- ifelse(
      asset_df$Scheduling == 1L & heating_like,
      comfort$Service_T_Low +
        operational_temperature_corrections$Service_AT_Low_Sched_HDD,
      ifelse(
        asset_df$Scheduling == 1L,
        comfort$Service_T_Low,
        asset_df$Service_T_Low
      )
    )
    scheduling_high <- ifelse(
      asset_df$Scheduling == 1L & cooling_like,
      comfort$Service_T_High -
        operational_temperature_corrections$Service_AT_High_Sched_CDD,
      ifelse(
        asset_df$Scheduling == 1L,
        comfort$Service_T_High,
        asset_df$Service_T_High
      )
    )

    rm(list = c("heating_like", "cooling_like"))
  }

  # -------------------------------------------------------------
  # 4. Plan band
  # The band the plan is measured against is the more restrictive
  # of the scheduling band and the occupancy band. The corrections
  # are 0 or more (their range in the parameter catalogue), so they
  # only narrow the scheduling band; the intersection makes sure
  # that, at each row, the plan never gets a band wider than the
  # occupancy one.
  # -------------------------------------------------------------
  {
    asset_df$Scheduling_T_Low  <- pmax(asset_df$Service_T_Low,  scheduling_low)
    asset_df$Scheduling_T_High <- pmin(asset_df$Service_T_High, scheduling_high)

    empty_band <- asset_df$Scheduling_T_Low >= asset_df$Scheduling_T_High
    if (any(empty_band)) {
      stop("The comfort band is empty (Scheduling_T_Low >= ",
           "Scheduling_T_High) on ", sum(empty_band),
           " rows, the first at ", format(asset_df$time[which(empty_band)[1]]),
           ". Check Service_T_Low/High and Setback_T_Low/High in ",
           "18_Comfort_parameters.csv and Service_AT_Low_Sched_HDD/",
           "Service_AT_High_Sched_CDD in ",
           "10_Operational_temperature_corrections.csv")
    }

    rm(list = c("scheduling_low", "scheduling_high", "empty_band"))
  }

  return(asset_df)
}
