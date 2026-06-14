# -------------------------------------------------------------
# Function: is_market_active.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Determines whether a market configuration value represents an
# active market.
# -------------------------------------------------------------
# Inputs
# market_name_raw : Any scalar value to evaluate.
# -------------------------------------------------------------
# Outputs
# Logical. TRUE if market is active, FALSE otherwise.
# -------------------------------------------------------------
# Usage instructions
# is_market_active(market_name_raw)
# -------------------------------------------------------------
# Where this function/script is used
# Called by simulation.R and run_market_process().
# -------------------------------------------------------------
# functions/scripts called
# (none)
# -------------------------------------------------------------

is_market_active <- function(market_name_raw) {
  market_name_chr <- trimws(as.character(market_name_raw)[1])
  !is.na(market_name_chr) && market_name_chr != "" && market_name_chr != "0"
}
