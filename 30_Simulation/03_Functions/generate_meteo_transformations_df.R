# -------------------------------------------------------------
# Function: generate_meteo_transformations_df.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Builds Meteo_transformations_df on the given time grid. This is a
# synthetic dataframe (not loaded from a data file): its columns are
# computed downstream from Meteo_df by existing engine logic
# (T_ext_24h by load_all_parameters.R, Text_forec/_ant and
# SolarR_forec/_ant by context_forecast_step()/imperfect_forecast()),
# which is unaffected by this change - only the initial placeholder
# generation moves here. See
# 01_Agent_Comments/20260722b_Plan_Señales_por_Procedencia.md, Part D.
# -------------------------------------------------------------
# Inputs
#   time : POSIXct vector. The master 5' time grid of Main_df.
# -------------------------------------------------------------
# Outputs
#   Data frame. Columns: time, T_ext_24h, Text_forec, Text_forec_ant,
#   SolarR_forec, SolarR_forec_ant, all initialized to 0.
# -------------------------------------------------------------
# Where this function/script is used
# Called by assemble_main_df.R to build Meteo_transformations_df on the
# master time grid before it is merged into Main_df.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

generate_meteo_transformations_df <- function(time) {
  n <- length(time)
  data.frame(
    time             = time,
    T_ext_24h        = rep(0, n),
    Text_forec       = rep(0, n),
    Text_forec_ant   = rep(0, n),
    SolarR_forec     = rep(0, n),
    SolarR_forec_ant = rep(0, n)
  )
}
