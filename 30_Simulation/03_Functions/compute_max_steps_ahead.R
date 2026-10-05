# -------------------------------------------------------------
# Function: compute_max_steps_ahead.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Works out how far ahead any market of the simulation looks, as a
# number of market-resolution steps. It is the width of the price
# matrices and of the market commitment matrices: one column per
# step ahead of a market event.
# The distance of a market is measured from its bid time to the end
# of its optimization horizon, and it is read from the market
# configuration that the simulation actually uses:
#   - Basic mode (Complex_Market_Config = "no"): the Scheduling and
#     the Piloting market of 03_Market_config.csv.
#       hours = Anticipation + Optimization_horizon
#   - Complex mode (Complex_Market_Config = "yes"): every market of
#     04_Market_config_scheduling.csv and
#     05_Market_config_piloting.csv.
#       hours = closure + end + end_optimization
# The largest distance found is turned into steps of
# market_resolution, rounded up, so that a horizon that is not an
# exact multiple of the resolution still gets a column for its last
# partial step.
# -------------------------------------------------------------
# Inputs
#   parameters : Named list. Uses:
#                - market$market_resolution (min)
#                - market$Complex_Market_Config ("yes"/"no")
#                - market$Anticipation_scheduling,
#                  market$Optimization_horizon_scheduling,
#                  market$Anticipation_piloting and
#                  market$Optimization_horizon_piloting (h), in basic
#                  mode
#                - market_config_scheduling and market_config_piloting
#                  (data frames with closure, end and end_optimization,
#                  in h), in complex mode
# -------------------------------------------------------------
# Outputs
#   Integer scalar. The number of market-resolution steps ahead.
# -------------------------------------------------------------
# Code outline
# 1. Distance of the furthest market, in hours
# 2. Conversion to market-resolution steps
# -------------------------------------------------------------
# Usage instructions
# max_steps_ahead <- compute_max_steps_ahead(parameters)
# -------------------------------------------------------------
# Where this function/script is used
#   - 11_full_market_information_setup.R: width of the price matrices.
#   - 12_market_commitments_setup.R: width of the market commitment
#     matrices, when 11_full_market_information_setup.R has not set it.
# -------------------------------------------------------------
# functions/scripts called
# (none)
# -------------------------------------------------------------

compute_max_steps_ahead <- function(parameters) {

  # -------------------------------------------------------------
  # 1. Distance of the furthest market, in hours
  # -------------------------------------------------------------
  {
    if (identical(parameters$market$Complex_Market_Config, "yes")) {
      market_hours <- function(config_table) {
        if (is.null(config_table) || nrow(config_table) == 0) {
          return(0)
        }
        max(as.numeric(config_table$closure) +
              as.numeric(config_table$end) +
              as.numeric(config_table$end_optimization))
      }
      max_hours_ahead <- max(market_hours(parameters$market_config_scheduling),
                             market_hours(parameters$market_config_piloting))
      rm(market_hours)
    } else {
      max_hours_ahead <- max(
        parameters$market$Anticipation_scheduling + parameters$market$Optimization_horizon_scheduling,
        parameters$market$Anticipation_piloting   + parameters$market$Optimization_horizon_piloting
      )
    }

    if (length(max_hours_ahead) != 1 || is.na(max_hours_ahead) || max_hours_ahead <= 0) {
      stop("compute_max_steps_ahead: the market configuration gives no horizon ahead ",
           "of the market bid times. Check the horizons of 03_Market_config.csv, ",
           "or of 04_Market_config_scheduling.csv and 05_Market_config_piloting.csv ",
           "when Complex_Market_Config is yes")
    }
  }

  # -------------------------------------------------------------
  # 2. Conversion to market-resolution steps
  # -------------------------------------------------------------
  {
    max_steps_ahead <- as.integer(ceiling(max_hours_ahead * 60 / parameters$market$market_resolution))
    rm(max_hours_ahead)
  }

  return(max_steps_ahead)
}
