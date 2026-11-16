# -------------------------------------------------------------
# Function: generate_meteo_transformations_df.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds Meteo_transformations_df on the given time grid. This is a
# synthetic dataframe (not loaded from a data file): its columns are
# computed downstream from Meteo_df by existing engine logic:
#   - T_ext_24h, by load_all_parameters()
#   - Text_forec/_ant and SolarR_forec/_ant, by
#     context_forecast_step()/imperfect_forecast()
#   - T_ext_24h_forec, by context_forecast_step()
# This function only creates those columns, as placeholders.
# -------------------------------------------------------------
# Inputs
#   time : POSIXct vector. The master 5' time grid of Main_df.
# -------------------------------------------------------------
# Outputs
#   Data frame with these columns, all but time initialized to 0:
#     - time
#     - T_ext_24h
#     - Text_forec
#     - SolarR_forec
#     - T_ext_24h_forec
# -------------------------------------------------------------
# Code outline
# 1. Build one column per derived weather variable, over the time
#    vector, from the columns the input series provides.
# -------------------------------------------------------------
# Usage instructions
#   df <- generate_meteo_transformations_df(time)
# -------------------------------------------------------------

generate_meteo_transformations_df <- function(time) {
  n <- length(time)
  data.frame(
    time            = time,
    T_ext_24h       = rep(0, n),
    Text_forec      = rep(0, n),
    SolarR_forec    = rep(0, n),
    T_ext_24h_forec = rep(0, n)
  )
}
