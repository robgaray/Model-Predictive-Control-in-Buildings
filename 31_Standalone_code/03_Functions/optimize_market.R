# -------------------------------------------------------------
# Function: optimize_market.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Optimizes the energy and flexibility commitments of a building for
# one market. It is the entry point of the standalone market script:
# called at i0, it optimizes the building from i_begin_horizon to
# i_end_horizon and commits from i_begin_horizon to i_end_control.
# All inputs and outputs are given per market interval. Inside, the
# building is simulated on a finer time step (main_resolution_sec),
# which is not visible from outside.
# The plan and the two flexibility itineraries come in and go out, so
# that the output of one market is the input of the next one.
# -------------------------------------------------------------
# Inputs
#   inputs : Named list with four blocks. Every vector has one value
#            per market interval, from i0 to the last interval before
#            i_end_horizon, together with its time vector:
#     - market      : aim ("E", "E+F", "O", "O+F"), i0,
#                     i_begin_horizon, i_end_control, i_end_horizon
#                     (UTC), T_ext_24h (degC), Overall_Climate
#                     ("Heating", "Cooling", "Intermediate") and,
#                     optionally, random_seed (0 or absent: not fixed)
#     - context     : time, Text (degC), SolarR (W/m2), Occupancy (0/1)
#     - prices      : time and the 15 price signals (EUR/kWh and 0-1)
#     - itineraries : plan, plan_flex_down and plan_flex_up, all three
#                     required, each with time, Ti, Te (degC, at
#                     the start of the interval), the six setpoints
#                     (degC) and Elec_total (kWh); plan also carries
#                     Elec_flex_down and Elec_flex_up (kWh)
#   paths  : Named list, as returned by initialize_standalone().
# -------------------------------------------------------------
# Outputs
#   Named list:
#     - itineraries : plan, plan_flex_down and plan_flex_up, per
#                     interval from i_begin_horizon to the closing
#                     interval at i_end_control, as returned by
#                     aggregate_to_slots()
#     - operations  : the operations of this market per committed
#                     interval, as returned by
#                     compute_market_operations()
# -------------------------------------------------------------
# Code outline
# 1. Parameters and inputs
# 2. Working table
# 3. Market
# 4. Output
# -------------------------------------------------------------
# Usage instructions
# paths  <- initialize_standalone(standalone_path, NULL)
# result <- optimize_market(inputs, paths)
# -------------------------------------------------------------
# Where this function/script is used
#   - call_script_console.R: called with the content of the input JSON file.
#   - call_script_from_R.R and call_script_from_Python_rpy2.py:
#     called directly.
# -------------------------------------------------------------
# functions/scripts called
#   - load_parameters(): reads and validates the configuration
#   - validate_inputs(): checks and normalizes the inputs
#   - expand_to_steps(): builds the working table
#   - build_comfort_bands(): adds the comfort bands of the reward
#   - resolve_marginal_context(): commitments, prices and discount
#   - run_market_process(): runs the market
#   - aggregate_to_slots(): builds the output itineraries
#   - compute_market_operations(): builds the output operations
# -------------------------------------------------------------

optimize_market <- function(inputs,
                            paths
                            ) {

  # -------------------------------------------------------------
  # 1. Parameters and inputs
  # -------------------------------------------------------------
  {
    # load_parameters is called to read and validate every
    # configuration file of the script.
    parameters <- load_parameters(paths$config_path)

    # validate_inputs is called to check the inputs and bring them to
    # one data frame per block on the market interval grid.
    checked <- validate_inputs(inputs, parameters)

    parameters$debug_and_config$random_seed <- checked$market$random_seed
    if (checked$market$random_seed != 0) {
      set.seed(checked$market$random_seed)
    }
  }

  # -------------------------------------------------------------
  # 2. Working table
  # -------------------------------------------------------------
  {
    # expand_to_steps is called to spread the inputs over the internal
    # time steps, from i0 to i_end_horizon.
    period_chunk <- expand_to_steps(checked, parameters)

    # build_comfort_bands is called to add the comfort bands the
    # reward compares the indoor temperature with.
    period_chunk <- build_comfort_bands(period_chunk,
                                        parameters,
                                        checked$market$Overall_Climate)

    row_index <- list(
      i_begin_horizon = match(as.numeric(checked$market$i_begin_horizon), as.numeric(period_chunk$time)),
      i_end_control   = match(as.numeric(checked$market$i_end_control),   as.numeric(period_chunk$time)),
      i_end_horizon   = match(as.numeric(checked$market$i_end_horizon),   as.numeric(period_chunk$time))
    )
  }

  # -------------------------------------------------------------
  # 3. Market
  # -------------------------------------------------------------
  {
    # resolve_marginal_context is called to fix, before the optimizer
    # runs, the commitments, prices and discount every candidate is
    # valued against.
    marginal_context <- resolve_marginal_context(checked, parameters)

    # run_market_process is called to fly the plan to i_begin_horizon
    # and optimize or evaluate the horizon according to the aim.
    period_chunk <- run_market_process(period_chunk     = period_chunk,
                                       aim_raw          = checked$market$aim,
                                       row_index        = row_index,
                                       parameters       = parameters,
                                       marginal_context = marginal_context)
  }

  # -------------------------------------------------------------
  # 4. Output
  # -------------------------------------------------------------
  {
    # aggregate_to_slots is called to bring the itineraries back to
    # one value per market interval.
    itineraries <- aggregate_to_slots(period_chunk, checked, parameters)

    # compute_market_operations is called to turn the move of the plan
    # into the operations this market sends to the grid.
    operations <- compute_market_operations(checked, itineraries)
  }

  rm(parameters, checked, period_chunk, row_index, marginal_context)

  return(list(
    itineraries = itineraries,
    operations  = operations
  ))
}
