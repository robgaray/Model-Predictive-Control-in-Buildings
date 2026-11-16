# -------------------------------------------------------------
# Function: building_prepare_period.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Prepares the table of a Building for the simulated period: its
# occupancy, its scheduling window and the reference temperature
# profiles the comfort term of the reward is measured against. It is
# the operation prepare_period of the contract of the type Building
# (see model_type_contract()). It runs once the table has been cut
# to the simulated period, after the operation prepare_year has
# tagged the climate of each day on the whole year.
# -------------------------------------------------------------
# Inputs
#   asset_df : data frame. The table of the building, cut to the
#              simulated period, with the column Overall_Climate.
#   asset    : List. The parameters of the building, its entry of
#              parameters$assets. This function reads its groups
#              use_patterns, operational_temperature_corrections and
#              comfort.
# -------------------------------------------------------------
# Outputs
#   asset_df, as received, with Occupancy, Scheduling and the
#   columns Service_T_Low/High and Scheduling_T_Low/High filled.
# -------------------------------------------------------------
# Code outline
# 1. Occupancy profile.
# 2. Scheduling profile.
# 3. Reference temperature profiles.
# -------------------------------------------------------------
# Usage instructions
# asset_df <- building_prepare_period(
#   asset_df = asset_df,
#   asset    = parameters$assets[[1]]
# )
# -------------------------------------------------------------
building_prepare_period <- function(asset_df,
                                    asset
                                    ) {

  # -------------------------------------------------------------
  # 1. Occupancy profile
  # -------------------------------------------------------------
  {
    # prepare_occupancy is called to map each timestamp to its
    # month, weekday and hour in the use patterns of the building,
    # and so give its table the Occupancy that the scheduling
    # profile and the reference temperatures are built from.
    asset_df <- prepare_occupancy(
      asset_df     = asset_df,
      use_patterns = asset$use_patterns
    )
  }

  # -------------------------------------------------------------
  # 2. Scheduling profile
  # -------------------------------------------------------------
  {
    # prepare_scheduling is called to mark, for each day with
    # occupied rows, the window from the first to the last occupied
    # row shifted by the anticipation, which the reference
    # temperature profiles use.
    asset_df <- prepare_scheduling(
      asset_df                            = asset_df,
      operational_temperature_corrections =
        asset$operational_temperature_corrections
    )
  }

  # -------------------------------------------------------------
  # 3. Reference temperature profiles
  # -------------------------------------------------------------
  {
    # prepare_comfort_bands is called to compute the
    # Service_T_*/Scheduling_T_* comfort setpoint bands of the
    # building, needed by the reward function during the simulation
    # loop, from the comfort bands of the building, the occupancy,
    # the scheduling window and the climate of each row.
    asset_df <- prepare_comfort_bands(
      asset_df                            = asset_df,
      comfort                             = asset$comfort,
      operational_temperature_corrections =
        asset$operational_temperature_corrections
    )
  }

  return(asset_df)
}
