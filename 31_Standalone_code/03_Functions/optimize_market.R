# -------------------------------------------------------------
# Function: optimize_market.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Optimizes the energy and flexibility commitments of a system of
# assets for one market. The system is one or more of the assets of
# the asset registry (buildings and photovoltaic installations) behind
# one connection to the grid, and the call names the assets it
# operates. It is the entry point of the standalone market script:
# called at i0, it optimizes the system from i_begin_horizon to
# i_end_horizon and commits from i_begin_horizon to i_end_control.
# All inputs and outputs are given per market interval. Inside, the
# assets are simulated on a finer time step (main_resolution_sec),
# which is not visible from outside.
# The plan and the two flexibility itineraries of the system and of
# each asset come in and go out, so that the output of one market is
# the input of the next one.
# -------------------------------------------------------------
# Inputs
#   inputs : Named list with five blocks. Every vector has one value
#            per market interval, from i0 to the last interval before
#            i_end_horizon, together with its time vector:
#     - market  : aim ("E", "E+F", "O", "O+F"), i0, i_begin_horizon,
#                 i_end_control, i_end_horizon (UTC), T_ext_24h
#                 (degC) and, optionally, random_seed (0 or absent:
#                 not fixed)
#     - context : time, Text (degC), SolarR (W/m2)
#     - prices  : time and the 15 price signals (EUR/kWh and 0-1)
#     - system  : itineraries, with plan (time, Elec_total, the net
#                 electricity of the system, and Elec_flex_down and
#                 Elec_flex_up, the flexibility already sold, in
#                 kWh), plan_flex_down and plan_flex_up (time and
#                 Elec_total)
#     - assets  : one block per asset of the call, named by its
#                 asset id in the asset registry. A building holds
#                 Overall_Climate ("Heating", "Cooling",
#                 "Intermediate"), its context (time, Occupancy 0/1)
#                 and its itineraries: plan, plan_flex_down and
#                 plan_flex_up, each with time, Ti, Te (degC, at the
#                 start of the interval), the six setpoints (degC)
#                 and Elec_total (kWh). A photovoltaic installation
#                 holds its itineraries, each with time, Elec_PV and
#                 Elec_total (kWh)
#   paths  : Named list, as returned by initialize_standalone(). Its
#            worker_cluster is the cluster of worker processes of
#            the session when parallel = 1.
# -------------------------------------------------------------
# Outputs
#   Named list:
#     - system     : itineraries of the system (plan,
#                    plan_flex_down and plan_flex_up) per interval
#                    from i_begin_horizon to the closing interval at
#                    i_end_control, as returned by
#                    aggregate_to_slots()
#     - assets     : the itineraries of each asset of the call, as
#                    returned by aggregate_to_slots()
#     - operations : the operations of the system in this market per
#                    committed interval, as returned by
#                    compute_market_operations()
# -------------------------------------------------------------
# Code outline
# 1. Parameters and inputs
# 2. Piece of the call
# 3. Market
# 4. Output
# -------------------------------------------------------------
# Usage instructions
# paths  <- initialize_standalone(standalone_path, NULL)
# result <- optimize_market(inputs, paths)
# close_standalone(paths)
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

    # The assets the call operates are the only ones the process
    # works on.
    parameters$assets <- parameters$assets[names(checked$assets)]

    parameters$debug_and_config$random_seed <- checked$market$random_seed
    if (checked$market$random_seed != 0) {
      set.seed(checked$market$random_seed)
    }
  }

  # -------------------------------------------------------------
  # 2. Piece of the call
  # -------------------------------------------------------------
  {
    # expand_to_steps is called to spread the inputs over the internal
    # time steps, from i0 to i_end_horizon, in the table of the system
    # and in the table of each asset. The comfort bands the reward
    # compares the indoor temperature of a building with are added to
    # its table there.
    piece <- expand_to_steps(checked, parameters)

    row_index <- list(
      i_begin_horizon = match(as.numeric(checked$market$i_begin_horizon), as.numeric(piece$system$time)),
      i_end_control   = match(as.numeric(checked$market$i_end_control),   as.numeric(piece$system$time)),
      i_end_horizon   = match(as.numeric(checked$market$i_end_horizon),   as.numeric(piece$system$time))
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
    piece <- run_market_process(piece            = piece,
                                aim_raw          = checked$market$aim,
                                row_index        = row_index,
                                parameters       = parameters,
                                marginal_context = marginal_context,
                                worker_cluster   = paths$worker_cluster)
  }

  # -------------------------------------------------------------
  # 4. Output
  # -------------------------------------------------------------
  {
    # aggregate_to_slots is called to bring the itineraries of the
    # system and of each asset back to one value per market interval.
    itineraries <- aggregate_to_slots(piece, checked, parameters)

    # compute_market_operations is called to turn the move of the plan
    # of the system into the operations this market sends to the grid.
    operations <- compute_market_operations(checked, itineraries)
  }

  rm(list = c("parameters", "checked", "piece", "row_index",
              "marginal_context"))

  return(list(
    system     = itineraries$system,
    assets     = itineraries$assets,
    operations = operations
  ))
}
