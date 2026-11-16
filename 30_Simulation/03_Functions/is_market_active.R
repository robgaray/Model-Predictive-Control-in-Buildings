# -------------------------------------------------------------
# Function: is_market_active.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
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
# Code outline
# 1. Trim the name and decide: anything that is not empty, not NA
#    and not "0" marks an active market.
# -------------------------------------------------------------

is_market_active <- function(market_name_raw) {
  market_name_chr <- trimws(as.character(market_name_raw)[1])
  !is.na(market_name_chr) && market_name_chr != "" && market_name_chr != "0"
}
