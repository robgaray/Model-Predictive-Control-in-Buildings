# -------------------------------------------------------------
# Function: prepare_market_calendar.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Assigns every row of Main_df to its market interval (MarketUTC),
# and initialises and populates the Sched_* and Pilot_* market
# columns of Main_df. Supports two modes:
#   - Basic  (Complex_Market_Config == "no") : deterministic
#     market timeline from optimisation horizons.
#   - Complex (Complex_Market_Config == "yes") : timeline built
#     from the market-config tables. In complex mode, the
#     optimization horizon is computed from end_optimization.
# It runs after the month/period subset and before the price
# emulation, and before every step that asks which markets are
# active.
# -------------------------------------------------------------
# Rows and market intervals
# A row holds the state of the building at its instant and the
# energy of the time step that ends at that instant. Each row is
# therefore assigned to the market interval that contains its time
# step, i.e. the interval of the instant one step earlier. With
# this rule the energy of a market interval is exactly the energy
# of the time steps that fall inside it, and every price, commitment
# and settlement read per interval applies to that energy.
# The first row is the initial condition of the simulation. Its
# time step lies before the simulation, so its interval is the one
# before the first instant, and it holds no energy.
# A market clearing is an event at an instant, and it is keyed by
# the interval its instant falls in (instant_market_slot()).
# -------------------------------------------------------------
# Inputs
#   Main_df                  : data frame, with its time column.
#   computing                : List, parameters$computing. Uses
#                              main_resolution_sec, the time step
#                              [s].
#   market                   : List, parameters$market. The market
#                              resolution, the mode and the basic
#                              horizons of Scheduling and Piloting.
#   market_config_scheduling : data frame,
#                              parameters$market_config_scheduling,
#                              the markets of the complex mode.
#   market_config_piloting   : data frame,
#                              parameters$market_config_piloting,
#                              the markets of the complex mode.
# -------------------------------------------------------------
# Outputs
#   Main_df, as received, with:
#     - MarketUTC, the market interval of each row's time step
#       (POSIXct, UTC)
#     - the Sched_ and Pilot_ market columns, for the market that
#       clears on each row:
#         - the name
#         - the bid time
#         - the period bounds
#         - the horizon
#         - the aim
# -------------------------------------------------------------
# Code outline
# 1. Assign every row to the market interval of its time step.
# 2. Initialise both sets of market columns to their empty value.
# 3. Build the timeline of each role, from the horizons in the basic
#    mode or from the configuration table in the complex one.
# 4. Check that a market covers every market interval.
# -------------------------------------------------------------
# Usage instructions
# Main_df <- prepare_market_calendar(
#   Main_df                  = Main_df,
#   computing                = parameters$computing,
#   market                   = parameters$market,
#   market_config_scheduling = parameters$market_config_scheduling,
#   market_config_piloting   = parameters$market_config_piloting
# )
# -------------------------------------------------------------
prepare_market_calendar <- function(Main_df,
                                    computing,
                                    market,
                                    market_config_scheduling,
                                    market_config_piloting
                                    ) {

  # -----------------------------------------------------------
  # 1. Market interval of every row
  # -----------------------------------------------------------
  # MarketUTC is computed here and only here: every later step reads
  # it. The interval of a row is the one that contains its time step,
  # which ends at the row's instant and starts one step earlier.
  # -----------------------------------------------------------
  {
    step_sec   <- computing$main_resolution_sec
    market_sec <- market$market_resolution * 60

    Main_df$MarketUTC <- as.POSIXct(
      floor((as.numeric(Main_df$time) - step_sec) / market_sec) * market_sec,
      origin = "1970-01-01",
      tz     = "UTC"
    )

    rm(list = c("step_sec", "market_sec"))
  }

  # -----------------------------------------------------------
  # 2. Initialise / overwrite market columns in Main_df
  # -----------------------------------------------------------
  {
    market_cols <- c(
      "Sched_Market_Name",
      "Sched_Market_Bid_time",
      "Sched_Market_Period_Begin",
      "Sched_Market_Period_End",
      "Sched_Optimization_Horizon",
      "Sched_Market_Aim",
      "Pilot_Market_Name",
      "Pilot_Market_Bid_time",
      "Pilot_Market_Period_Begin",
      "Pilot_Market_Period_End",
      "Pilot_Optimization_Horizon",
      "Pilot_Market_Aim"
    )

    for (CONT_001 in market_cols) {
      Main_df[[CONT_001]] <- 0
    }
    rm(list = c("market_cols", "CONT_001"))
  }

  # -----------------------------------------------------------
  # 3. Market timeline of each role
  # -----------------------------------------------------------
  # 3.1. Scheduling
  # 3.2. Piloting
  # -----------------------------------------------------------

  # -----------------------------------------------------------
  # 3.1. Scheduling
  # Configures the Scheduling market values based on
  # Complex_Market_Config.
  # -----------------------------------------------------------
  {
    # Its options, yes or no, are checked when 03_Market_config.csv is
    # read.
    complex_market_config <- market$Complex_Market_Config

    time_min <- min(Main_df$time)
    time_max <- max(Main_df$time)

    # build_market_timeline is called to fill in the Sched_* columns of
    # Main_df over the full simulation range, in either basic or complex
    # mode as resolved above:
    #   - market name
    #   - bid time
    #   - period bounds
    #   - optimization horizon
    #   - aim
    Main_df <- build_market_timeline(
      role                   = "Sched",
      config_table           = market_config_scheduling,
      implementation_horizon = market$Implementation_horizon_scheduling,
      optimization_horizon   = market$Optimization_horizon_scheduling,
      anticipation           = market$Anticipation_scheduling,
      optimization_aim       = market$optimization_aim_scheduling,
      aim_label_energy       = "E",
      aim_label_flex         = "E+F",
      complex_market_config  = complex_market_config,
      time_min               = time_min,
      time_max               = time_max,
      Main_df                = Main_df
    )
  }

  # -----------------------------------------------------------
  # 3.2. Piloting
  # Configures the Piloting market values based on
  # Complex_Market_Config.
  # -----------------------------------------------------------
  {
    # build_market_timeline is called again, now to fill in the Pilot_*
    # columns of Main_df, reusing the same complex_market_config/
    # time_min/time_max resolved for the Scheduling market above.
    Main_df <- build_market_timeline(
      role                   = "Pilot",
      config_table           = market_config_piloting,
      implementation_horizon = market$Implementation_horizon_piloting,
      optimization_horizon   = market$Optimization_horizon_piloting,
      anticipation           = market$Anticipation_piloting,
      optimization_aim       = market$optimization_aim_piloting,
      aim_label_energy       = "O",
      aim_label_flex         = "O+F",
      complex_market_config  = complex_market_config,
      time_min               = time_min,
      time_max               = time_max,
      Main_df                = Main_df
    )

    rm(list = c("complex_market_config", "time_min", "time_max"))
  }

  # -----------------------------------------------------------
  # 4. Coverage of every market interval
  # -----------------------------------------------------------
  # The time step of every row after the first has to fall in the
  # control period of a market, or nothing decides its operation: the
  # run stops here, before the simulation, with an input data
  # validation error.
  # -----------------------------------------------------------
  {
    # validate_market_coverage is called to stop the run when a market
    # interval is covered by no Scheduling or Piloting market.
    validate_market_coverage(Main_df)
  }

  return(Main_df)
}
