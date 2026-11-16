# -------------------------------------------------------------
# Function: photovoltaic_solar_geometry.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Writes the geometry of the sun in the table of a photovoltaic
# installation: the elevation and the azimuth of the sun and the
# cosine of the angle of incidence of its rays on the modules, for
# every row of the table. It is the operation prepare_year of the
# contract of the type Photovoltaic (see model_type_contract()),
# whose contract entry takes Main_df too and does not pass it on.
# The geometry only depends on the instant of each row and on the
# location and the orientation of the installation, so it is
# computed once for the whole year, before the period is cut, and
# the model reads it from the table in every step.
# -------------------------------------------------------------
# Inputs
#   asset_df : Data frame. The table of the installation, with its
#              time column.
#   asset    : Named list. The parameters of the installation, its
#              entry of parameters$assets. This function reads its
#              group photovoltaic:
#              - Latitude
#              - Longitude
#              - Irradiance_time_offset
#              - Tilt
#              - Azimuth
# -------------------------------------------------------------
# Outputs
#   Data frame. asset_df with the columns Sun_elevation (deg),
#   Sun_azimuth (deg) and Cos_incidence (-) added.
# -------------------------------------------------------------
# Code outline
# 1. Compute the geometry of the sun
# 2. Write it into the table
# -------------------------------------------------------------
# Usage instructions
# asset_df <- photovoltaic_solar_geometry(
#   asset_df = asset_df,
#   asset    = asset
# )
# -------------------------------------------------------------

photovoltaic_solar_geometry <- function(asset_df,
                                        asset) {

  # -------------------------------------------------------------
  # 1. Compute the geometry of the sun
  # -------------------------------------------------------------
  {
    photovoltaic_parameters <- asset$photovoltaic

    # solar_position is called to compute the elevation and the
    # azimuth of the sun, and the incidence of its rays on the
    # modules, at the instant each row of the table stands for.
    position <- solar_position(
      time        = asset_df$time,
      latitude    = photovoltaic_parameters$Latitude,
      longitude   = photovoltaic_parameters$Longitude,
      time_offset = photovoltaic_parameters$Irradiance_time_offset,
      tilt        = photovoltaic_parameters$Tilt,
      azimuth     = photovoltaic_parameters$Azimuth
    )
  }

  # -------------------------------------------------------------
  # 2. Write it into the table
  # -------------------------------------------------------------
  {
    asset_df$Sun_elevation <- position$Sun_elevation
    asset_df$Sun_azimuth   <- position$Sun_azimuth
    asset_df$Cos_incidence <- position$Cos_incidence

    rm(list = c("photovoltaic_parameters", "position"))
  }

  return(asset_df)
}
