# -------------------------------------------------------------
# Function: reward_function.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function calculates a reward function on the adequacy of
# a particular building HVAC operation over a planning period.
# It reads a period_chunk data frame and operates in two modes
# depending on parameters$control$optimization_aim:
#   "energy"      - minimise energy cost while maintaining comfort
#   "flexibility" - additionally account for flexibility revenue
# Comfort is always evaluated over the full simulated energy flow
# (Elec_total_plan, Elec_total_plan_flex), since the building's
# thermal evolution depends on the full energy applied. The economic
# terms are always valued at their marginal (differential) cash flow
# relative to whatever was already committed for the same market
# intervals by an earlier market process, at the current market's
# prices - see compute_marginal_energy_cost() and
# resolve_marginal_context(). marginal_context is mandatory: there is
# no no-context fallback. A previous fallback that valued the full
# candidate commitment directly (ignoring the differential baseline)
# was removed because it could silently mask a missing or broken
# marginal-cost chain upstream (e.g. a caller that forgot to call
# resolve_marginal_context()) instead of surfacing it as an error.
# In addition to the energy price, the base-energy term also accounts
# for the marginal distribution cost (Elec_unit_cost_distribution),
# via compute_marginal_distribution_cost() - see
# 01_Agent_Comments/20260722c_Plan_Costes_Distribucion_Recompensa.md.
# This is a decision-time-only consideration (it is never written to
# market_commitments, only to Reward): buying or selling energy always
# adds distribution cost, unbuying ("descompra") or unselling
# ("desventa") always reduces it, regardless of direction - it does
# not apply to the explicit-flexibility term.
# -------------------------------------------------------------
# Sign convention
# Every economic term (Elec_Cost_plan, Elec_Cost_distribution_plan,
# Elec_flex_revenue_plan) already carries the sign of its cash flow:
# positive = income, negative = expense (see calc_differential_cost(),
# compute_marginal_distribution_cost() and value_flex_operation()).
# Reward is therefore a pure sum of the comfort term and every economic
# term, never a mix of "+" and "-" that has to be remembered per term -
# see 00_Agent_Input/20260818_comentarios_observaciones_anteriores.md.
# The explicit-flexibility term is valued via compute_marginal_flex_revenue(),
# not compute_marginal_energy_cost(): explicit flexibility is a service
# sold to the grid in two independent down/up legs, not a single
# position that flips sign like energy import/export - see
# value_flex_operation()'s header for the full explanation of why the
# two cannot share the same valuation machinery.
# -------------------------------------------------------------
# Inputs
#   period_chunk             : Data frame. Planning-period data with *_plan (and,
#                              for "flexibility" mode, *_plan_flex) columns produced
#                              by period_calculation() and flex_evaluation().
#                              Required columns:
#                                time             - POSIXct. Simulation timestamps.
#                                MarketUTC        - POSIXct. Market interval of each row.
#                                Occupancy        - Numeric (0/1). Occupancy flag.
#                                Comfort_plan     - Numeric (0/1). Comfort flag (plan).
#                                Elec_total_plan  - Numeric. Total electricity (plan).
#                              Additional columns required for "flexibility" mode:
#                                Comfort_plan_flex    - Numeric (0/1). Comfort flag (plan_flex).
#                                Elec_total_plan_flex - Numeric. Total electricity (plan_flex).
#   parameters               : Named list. Must contain:
#                                parameters$reward$Alpha_Service_Min : Numeric. Weight applied to the
#                                                                  comfort penalty term. Mandatory:
#                                                                  stop() is raised if absent.
#                                parameters$control$optimization_aim : Character. "energy",
#                                                                       "flexibility", or
#                                                                       "operationflex".
#   simulation_control       : Named list. Simulation control object. Must contain:
#                                simulation_control$indexes_local$i_flex : Integer scalar. Row number in
#                                  period_chunk at which the flexibility event starts.
#                                  Defaults to 1 when NULL or absent.
#                                simulation_control$flexibility$flexibility_event_length : Numeric
#                                  scalar. Duration of the flexibility event (h). Only used to decide
#                                  whether a "flexibility" aim still behaves as "energy" (see
#                                  EXCEPTIONS below); not used for any economic calculation.
#   marginal_context          : Named list. Mandatory (no default). As returned by
#                                resolve_marginal_context(): market_utc, E_orig_base_by_market,
#                                E_orig_expflex_by_market, P_import_buy_by_market,
#                                P_import_sell_by_market, P_export_buy_by_market,
#                                P_export_sell_by_market, distribution_rate_by_market,
#                                p_up_buy_by_market, p_up_sell_by_market, p_down_buy_by_market,
#                                p_down_sell_by_market (the four flex prices are per-leg: "up"/"down",
#                                not "import"/"export" - see value_flex_operation()). stop()s if NULL.
# -------------------------------------------------------------
# Outputs
#   period_chunk : Data frame. The input data frame with a 'Reward' column
#                  added (or overwritten) containing the per-row reward value
#                  for each timestep, plus the following intermediate result
#                  columns (all modes):
#                    Elec_Cost_plan              - Numeric. Electricity cost. The whole
#                                                  interval-aggregated marginal cost is
#                                                  concentrated on the last row (this column
#                                                  is not meaningful per-timestep; only its
#                                                  sum matters).
#                    Elec_Cost_distribution_plan - Numeric. Marginal distribution cost
#                                                  (base-energy term only), same last-row
#                                                  concentration as Elec_Cost_plan.
#                  Additional columns added in "flexibility" mode:
#                    Elec_flex_plan             - Numeric. Energy difference (plan - plan_flex).
#                    Elec_flex_revenue_plan      - Numeric. Flexibility revenue (same
#                                                  last-row concentration as Elec_Cost_plan).
#                  The caller is responsible for summing the Reward column
#                  when a scalar reward is required.
# -------------------------------------------------------------
# Code outline
# 1. Extract Alpha_Service_Min parameter
# 2. Extract i_flex and flexibility_event_length from simulation_control
# 3. Calculate delta_t per timestep
# 4. Compute electricity cost (marginal) and distribution cost (marginal)
# 5. Mode-specific reward (energy or flexibility)
# 6. Store per-row reward in data frame
# -------------------------------------------------------------
# Usage instructions
# result_df <- reward_function(period_chunk, parameters, simulation_control, marginal_context)
# -------------------------------------------------------------
# Where this function/script is used
# Called by evaluate_control.R
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If marginal_context is NULL, stop() is called immediately (see header).
#   - If parameters$reward$Alpha_Service_Min is NULL, stop() is called
#     immediately (no default value is used).
#   - delta_t for the first row is set to 0 (no prior timestep).
#   - If optimization_aim is neither "energy" nor "flexibility"/"operationflex", stop() is called.
#   - In "energy" mode, the comfort penalty is based on Comfort_plan.
#   - In "flexibility" mode, the comfort penalty applies if EITHER Comfort_plan
#     OR Comfort_plan_flex is 0 (out of comfort) for an occupied period.
#   - When simulation_control$indexes_local$i_flex is NULL, it defaults to 1 (first row).
#   - When simulation_control$flexibility$flexibility_event_length is NULL,
#     it falls back to parameters$control$flexibility_event_length_max.
#   - The flexibility revenue term does not distinguish a "commitment
#     window" vs "execution/stabilisation window": Elec_flex_plan is
#     aggregated per market interval over the whole period_chunk and
#     valued at that interval's own effective up/down flexibility
#     price, which already values any post-event rebound at its own
#     interval's price instead of forcing every revenue component onto
#     the flex event's own price.
# -------------------------------------------------------------
# functions/scripts called
#   compute_marginal_energy_cost() - marginal cash flow, base-energy term
#   compute_marginal_distribution_cost() - marginal distribution cost
#     (base-energy term only)
#   compute_marginal_flex_revenue() - marginal cash flow, explicit
#     flexibility term (flexibility/operationflex modes only)
# -------------------------------------------------------------
reward_function <- function(period_chunk, parameters,
                            simulation_control = NULL,
                            marginal_context = NULL) {

  # 0. marginal_context is mandatory: no no-context fallback (see header)
  if (is.null(marginal_context)) {
    stop("reward_function: marginal_context is required. The no-context ",
         "fallback (valuing the full candidate commitment without a ",
         "marginal baseline) was removed because it could silently mask ",
         "a missing or broken marginal-cost chain upstream - make sure ",
         "resolve_marginal_context() is called and its result is passed ",
         "through.")
  }

  # 1. Get Alpha_Service_Min from reward_parameters
  if (!is.null(parameters$reward$Alpha_Service_Min)) {
    Alpha_Service_Min <- parameters$reward$Alpha_Service_Min
  } else {
    stop("Alpha_Service_Min was not found")
  }

  # 2. Extract i_flex and flexibility_event_length from simulation_control
  if (!is.null(simulation_control) &&
      !is.null(simulation_control$indexes_local$i_flex)) {
    i_flex <- simulation_control$indexes_local$i_flex
  } else {
    i_flex <- 1L
  }

  if (!is.null(simulation_control) &&
      !is.null(simulation_control$flexibility$flexibility_event_length)) {
    flexibility_event_length <- simulation_control$flexibility$flexibility_event_length
  } else {
    flexibility_event_length <- NULL
  }

  # 3. Calculate delta_t (minutes) for each row; first row gets 0.
  # period_chunk$time must be POSIXct. as.numeric() is applied before
  # diff(), not after: diff() on a POSIXct vector returns a difftime
  # with an automatically chosen unit (seconds, minutes, hours or days,
  # picked from the series' own spacing), so as.numeric(diff(...))
  # would silently pick up whatever unit R chose instead of always
  # being seconds. Converting to numeric first fixes the unit to
  # seconds before diff() ever runs, so the /60 below always yields
  # minutes regardless of Main_df's resolution.
  delta_t <- c(0, diff(as.numeric(period_chunk$time)) / 60)

  # 4. Compute electricity cost (marginal)
  # -------------------------------------------------------------
  # The whole horizon's base-energy commitment is aggregated per market
  # interval and valued at its marginal (differential) cost relative to
  # marginal_context's baseline, at the current market's prices. The
  # resulting scalar is concentrated on the last row so that
  # sum(period_chunk$Reward) still yields the correct total.
  # -------------------------------------------------------------
  Elec_Cost_total <- compute_marginal_energy_cost(
    E_candidate             = period_chunk$Elec_total_plan,
    MarketUTC_candidate     = period_chunk$MarketUTC,
    market_utc              = marginal_context$market_utc,
    E_orig_by_market        = marginal_context$E_orig_base_by_market,
    P_import_buy_by_market  = marginal_context$P_import_buy_by_market,
    P_import_sell_by_market = marginal_context$P_import_sell_by_market,
    P_export_buy_by_market  = marginal_context$P_export_buy_by_market,
    P_export_sell_by_market = marginal_context$P_export_sell_by_market
  )
  period_chunk$Elec_Cost_plan <- 0
  period_chunk$Elec_Cost_plan[nrow(period_chunk)] <- Elec_Cost_total
  rm(Elec_Cost_total)

  # Marginal distribution cost (base-energy term only, never for
  # flexibility - see 01_Agent_Comments/20260722c_Plan_Costes_Distribucion_Recompensa.md).
  Elec_Cost_distribution_total <- compute_marginal_distribution_cost(
    E_candidate                 = period_chunk$Elec_total_plan,
    MarketUTC_candidate         = period_chunk$MarketUTC,
    market_utc                  = marginal_context$market_utc,
    E_orig_by_market            = marginal_context$E_orig_base_by_market,
    distribution_rate_by_market = marginal_context$distribution_rate_by_market
  )
  period_chunk$Elec_Cost_distribution_plan <- 0
  period_chunk$Elec_Cost_distribution_plan[nrow(period_chunk)] <- Elec_Cost_distribution_total
  rm(Elec_Cost_distribution_total)

  # 5. Mode-specific reward calculation
  optimization_aim <- parameters$control$optimization_aim

  if (optimization_aim == "energy" ||
      ((optimization_aim == "flexibility" || optimization_aim == "operationflex") &&
       (is.null(i_flex) ||
        i_flex == 0 ||
        is.null(flexibility_event_length)
        ||
        flexibility_event_length == 0
        )
       )
      ) {
    # In energy mode, comfort penalty is based on Comfort_plan
    Performance_plan <- ifelse(period_chunk$Occupancy == 1 & period_chunk$Comfort_plan == 0, -1, 0) * delta_t

    # Every term already carries its own sign (comfort: neutral/positive
    # in comfort, negative out of it; economic terms: positive income,
    # negative expense), so Reward is a plain sum.
    Reward <- Alpha_Service_Min * Performance_plan + period_chunk$Elec_Cost_plan +
              period_chunk$Elec_Cost_distribution_plan

  } else if (optimization_aim == "flexibility"  ||
             optimization_aim =="operationflex") {

    period_chunk$Elec_flex_plan <- period_chunk$Elec_total_plan - period_chunk$Elec_total_plan_flex

    # In flexibility mode, penalty applies if EITHER plan OR plan_flex is out of comfort
    Performance_flex <- ifelse(period_chunk$Occupancy == 1 &
                                 (period_chunk$Comfort_plan == 0 | period_chunk$Comfort_plan_flex == 0),
                               -1, 0) * delta_t

    # Marginal explicit-flexibility revenue: Elec_flex_plan aggregated
    # per market interval, valued at that interval's own effective
    # down/up flexibility prices (value_flex_operation(), via
    # compute_marginal_flex_revenue() - not compute_marginal_energy_cost():
    # see that function's header for why explicit flexibility cannot be
    # valued as an import/export position), relative to the pre-existing
    # baseline.
    Elec_flex_revenue_total <- compute_marginal_flex_revenue(
      E_candidate                = period_chunk$Elec_flex_plan,
      MarketUTC_candidate        = period_chunk$MarketUTC,
      market_utc                 = marginal_context$market_utc,
      E_orig_by_market           = marginal_context$E_orig_expflex_by_market,
      price_down_sell_by_market  = marginal_context$p_down_sell_by_market,
      price_down_buy_by_market   = marginal_context$p_down_buy_by_market,
      price_up_sell_by_market    = marginal_context$p_up_sell_by_market,
      price_up_buy_by_market     = marginal_context$p_up_buy_by_market
    )
    period_chunk$Elec_flex_revenue_plan <- 0
    period_chunk$Elec_flex_revenue_plan[nrow(period_chunk)] <- Elec_flex_revenue_total
    rm(Elec_flex_revenue_total)

    # Every term already carries its own sign - see the energy-mode
    # branch above.
    Reward <- Alpha_Service_Min * Performance_flex +
              period_chunk$Elec_Cost_plan +
              period_chunk$Elec_Cost_distribution_plan +
              period_chunk$Elec_flex_revenue_plan

  } else {
    stop("Invalid optimization_aim: '", optimization_aim, "'. Must be 'energy' or 'flexibility'.")
  }

  # 6. Store per-row reward in period_chunk and return the data frame
  period_chunk$Reward <- Reward
  return(period_chunk)
}
