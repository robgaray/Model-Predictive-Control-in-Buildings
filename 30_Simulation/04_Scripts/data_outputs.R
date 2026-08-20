# -------------------------------------------------------------
# Script: data_outputs.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This script exports the simulation results to CSV and RDS files.
# It is sourced from Main.R.
# -------------------------------------------------------------
# Sinthetized_df
# One row per simulation, reconstructable in full from its own
# columns: every money column follows the repository's sign
# convention (income positive, expense negative - see
# 00_Agent_Input/20260818_comentarios_observaciones_anteriores.md), so
# Elec_cost + Elec_revenue + Flex_plan_revenue + Distr_cost is the
# energy-and-flexibility economic result of the year, before comfort.
# The market-decision (Scheduling/Piloting) and execution-deviation
# money flows are not split apart into their own columns here - the
# per-market, per-slot breakdown is economic_analysis$market/economic_analysis$slot,
# exported separately below.
#   Comfort            = sum(Comfort_exec) - occupied timesteps in comfort.
#   Elec_total_in       = sum(pmax(Elec_total_exec, 0)) - energy imported.
#   Elec_total_out      = sum(pmax(-Elec_total_exec, 0)) - energy exported.
#   Flex_plan_down      = sum(pmax(Elec_flex_plan, 0)) - down-flexibility
#                         committed (the only leg currently offered - see
#                         value_flex_operation()'s header).
#   Flex_plan_up        = sum(pmax(-Elec_flex_plan, 0)) - up-flexibility
#                         committed (always 0 today).
#   Flex_exec_down/up   = the same two legs, restricted to timesteps
#                         where flexibility was actually executed (never
#                         true today - flexibility execution is not
#                         simulated, so both are always 0; see
#                         economic_analysis_finalize.R's identical logic).
#   Elec_cost           = -sum(economic_analysis$slot$Cost_energy_bought) - net
#                         spent buying energy, across Scheduling,
#                         Piloting and Execution, with every resale
#                         subtracted as the avoided cost it is.
#   Elec_revenue        = sum(economic_analysis$slot$Revenue_energy_sold) - net
#                         received selling energy, with every rebuy
#                         subtracted as the avoided revenue it is.
#                         A simulation that never exports therefore
#                         reports Elec_revenue = 0, instead of
#                         counting its resales as income - see
#                         accumulate_market_operation()'s header and
#                         00_Agent_Input/20260820_Correcciones.md.
#   Flex_plan_revenue    = sum(economic_analysis$slot$Revenue_flex_commitments) -
#                         net cash flow of flexibility commitments
#                         (sold minus bought back), across Scheduling
#                         and Piloting.
#   Flex_exec_revenue    = sum(economic_analysis$market$Flex_executed_cash_flow) on
#                         Execution rows - always 0 today, for the same
#                         reason as Flex_exec_down/up.
#   Distr_cost          = sum(economic_analysis$slot$Distribution_cost) - already
#                         negative (see implement_control_step.R).
#   Reward              = sum(Reward) - the GA's own optimization target.
#   Process_time        = execution_time$t_process (seconds).
# parameters$optimization is kept as the leading columns, unchanged from
# earlier versions of this table, so that parametric-simulation batches
# can still be compared by hyperparameter.
# -------------------------------------------------------------
# Inputs
# Main_df : Data frame. Simulation results.
# parameters : List. Contains optimization sub-list.
# execution_time : List. Timing information.
# economic_analysis : List of 2 data frames (market, slot), as completed by
#            economic_analysis_finalize.R.
# paths : List. Must include paths$output_path (path to the output directory).
# -------------------------------------------------------------
# Outputs
# (none) - writes CSV and RDS files to output_path.
# -------------------------------------------------------------
# Code outline
# 1. Create output directory if needed
# 2. Export Main_df to CSV and RDS
# 3. Build and export synthesized summary data frame
# 4. Export the two economic analysis tables
# -------------------------------------------------------------
# Usage
# source(file.path("30_Simulation", "04_Scripts", "data_outputs.R"))
# -------------------------------------------------------------
# Where this script is used
# Sourced by Main.R as the final step.
# -------------------------------------------------------------
# functions/scripts called
# (none)
# -------------------------------------------------------------

{
  if (!dir.exists(paths$output_path)) {
    dir.create(paths$output_path, recursive = TRUE)
  }
	
  # Main_df
  {
    write.csv(Main_df,
              file.path(paths$output_path, "Main_df_computed.csv"),
              row.names = FALSE)
    write_rds(Main_df,
              file.path(paths$output_path, "Main_df_computed.rds"))
  }

  # Sinthetized
  {
    # A flexibility activation is considered booked on a row when the
    # execution phase wrote either of the two signals reserved for it -
    # same definition as economic_analysis_finalize.R's flex_activated. Neither
    # is written today, so Flex_exec_down/up are always 0.
    flex_activated <- as.numeric(
      Main_df$Elec_flex_execution_revenue_h  != 0 |
      Main_df$Elec_flex_deviations_net_cost_h != 0
    )

    Sinthetized_df <- data.frame(
      as.data.frame(parameters$optimization),
      Comfort          = sum(Main_df$Comfort_exec),
      Elec_total_in    = sum(pmax(Main_df$Elec_total_exec, 0)),
      Elec_total_out   = sum(pmax(-Main_df$Elec_total_exec, 0)),
      Flex_plan_up     = sum(pmax(-Main_df$Elec_flex_plan, 0)),
      Flex_plan_down   = sum(pmax(Main_df$Elec_flex_plan, 0)),
      Flex_exec_up     = sum(pmax(-Main_df$Elec_flex_plan, 0) * flex_activated),
      Flex_exec_down   = sum(pmax(Main_df$Elec_flex_plan, 0) * flex_activated),
      Elec_cost        = -sum(economic_analysis$slot$Cost_energy_bought),
      Elec_revenue     = sum(economic_analysis$slot$Revenue_energy_sold),
      Flex_plan_revenue = sum(economic_analysis$slot$Revenue_flex_commitments),
      Flex_exec_revenue = sum(economic_analysis$market$Flex_executed_cash_flow, na.rm = TRUE),
      Distr_cost       = sum(economic_analysis$slot$Distribution_cost),
      Reward           = sum(Main_df$Reward),
      Process_time     = execution_time$t_process
    )
    rm(flex_activated)

    write.csv(Sinthetized_df,
              file.path(paths$output_path, "Sinthetized_df_computed.csv"),
              row.names = FALSE)
    write_rds(Sinthetized_df,
              file.path(paths$output_path, "Sinthetized_df_computed.rds"))
    rm(Sinthetized_df)
  }

  # Economic analysis
  {
    write.csv(economic_analysis$market,
              file.path(paths$output_path, "Economic_analysis_market_computed.csv"),
              row.names = FALSE)
    write_rds(economic_analysis$market,
              file.path(paths$output_path, "Economic_analysis_market_computed.rds"))

    write.csv(economic_analysis$slot,
              file.path(paths$output_path, "Economic_analysis_slot_computed.csv"),
              row.names = FALSE)
    write_rds(economic_analysis$slot,
              file.path(paths$output_path, "Economic_analysis_slot_computed.rds"))
  }
}
