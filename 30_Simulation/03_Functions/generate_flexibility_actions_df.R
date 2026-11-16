# -------------------------------------------------------------
# Function: generate_flexibility_actions_df.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds Flexibility_actions_df on the given time grid. This is a
# synthetic dataframe (not loaded from a data file): Flex_Act is an
# engine-level explicit-flexibility tracking signal, stable across
# building models, so unlike Building_variables_df it is not driven by
# an external variable registry.
# Initialized to 0 here; set to 1 for rows covered by an accepted
# flexibility event by prepare_flexibility_prices().
# -------------------------------------------------------------
# Inputs
#   time : POSIXct vector. The master 5' time grid of Main_df.
# -------------------------------------------------------------
# Outputs
#   Data frame with two columns, Flex_Act initialized to 0:
#     - time
#     - Flex_Act
# -------------------------------------------------------------
# Code outline
# 1. Build one column per flexibility action variable, at its
#    initial value, over the time vector.
# -------------------------------------------------------------
# Usage instructions
#   df <- generate_flexibility_actions_df(registry_path, time)
# -------------------------------------------------------------

generate_flexibility_actions_df <- function(time) {
  n <- length(time)
  data.frame(
    time     = time,
    Flex_Act = rep(0, n)
  )
}
