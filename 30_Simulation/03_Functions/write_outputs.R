# -------------------------------------------------------------
# Function: write_outputs.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function exports the simulation results to CSV and RDS files:
# the table of the system, the table of each asset, a summary and
# the economic analysis tables.
# -------------------------------------------------------------
# Main_df_computed
# Main_df as it is: what is common to every asset (time, weather,
# prices and the market timeline) and the columns of the system (the
# net electricity Elec_total_<itinerary>, summed over the assets, the
# commitments and the money flows). One row per timestep. The columns
# are in the order of 02_Needed_cols.csv (the rows whose table is
# system); a column not in that file goes after them.
# -------------------------------------------------------------
# The table of each asset
# One table per asset of the registry, named <asset_id>_df_computed
# (Building_001_df_computed for the building): the table of the asset
# as it is. The column time comes first, then the columns of the
# asset in the order of 02_Needed_cols.csv (the rows whose table is
# the type of model of the asset); a column not in that file goes
# after them. It has one row
# per row of Main_df_computed, in the same order, so both tables join
# by time. Elec_total_<itinerary> in it is the net electricity of the
# asset, and Main_df_computed holds the sum over the assets.
# -------------------------------------------------------------
# Sinthetized_df
# One row per simulation, reconstructable in full from its own
# columns: every money column follows the repository's sign
# convention (income positive, expense negative), so
# Elec_cost + Elec_revenue + Flex_plan_revenue + Distr_cost is the
# energy-and-flexibility economic result of the year, before comfort.
# The market-decision (Scheduling/Piloting) and execution-deviation
# money flows are not split apart into their own columns here - the
# per-market, per-decision and per-slot breakdown is
# economic_analysis$market, economic_analysis$decision and
# economic_analysis$slot, exported separately below.
#   Comfort             = sum(Comfort_exec) over every asset whose
#                         table holds it, 0 when there is none:
#                         timesteps in comfort.
#   Elec_total_in       = sum(pmax(Elec_total_exec, 0)): energy
#                         imported.
#   Elec_total_out      = sum(pmax(-Elec_total_exec, 0)): energy
#                         exported.
#   Flex_plan_down      = sum(Elec_flex_down_plan): down-flexibility
#                         committed.
#   Flex_plan_up        = sum(Elec_flex_up_plan): up-flexibility
#                         committed. Each leg has its own signal, and both
#                         are non-negative by construction, so neither is
#                         read off the sign of the other.
#   Flex_exec_down/up   = the same two legs, restricted to timesteps
#                         where flexibility was actually executed (never
#                         true today: flexibility execution is not
#                         simulated, so both are always 0; see
#                         finalize()'s identical logic).
#   Elec_cost           = -sum(economic_analysis$slot$Cost_energy_bought):
#                         net spent buying energy, across Scheduling,
#                         Piloting and Execution, with every resale
#                         subtracted as the avoided cost it is.
#   Elec_revenue        = sum(economic_analysis$slot$Revenue_energy_sold):
#                         net received selling energy, with every rebuy
#                         subtracted as the avoided revenue it is.
#                         A simulation that never exports therefore
#                         reports Elec_revenue = 0, instead of
#                         counting its resales as income - see
#                         accumulate_market_operation()'s header.
#   Flex_plan_revenue   = sum(economic_analysis$slot$Revenue_flex_commitments):
#                         net cash flow of flexibility commitments
#                         (sold minus bought back), across Scheduling
#                         and Piloting.
#   Flex_exec_revenue   = sum(economic_analysis$market$Flex_executed_cash_flow)
#                         on Execution rows: always 0 today, for the same
#                         reason as Flex_exec_down/up.
#   Distr_cost          = sum(economic_analysis$slot$Distribution_cost):
#                         already negative (see settle_execution.R).
#   Reward              = sum(economic_analysis$decision$Reward): the
#                         GA's own optimization target, totalled over
#                         every decision.
#   Process_time        = execution_time$t_process (seconds).
# The optimization parameters are kept as the leading columns, so that
# parametric-simulation batches can be compared by hyperparameter.
# -------------------------------------------------------------
# Inputs
#   Main_df           : Data table. Simulation results of the system,
#                       with the common columns.
#   assets            : Named list, one entry per asset, each with
#                       df, the table of the asset.
#   system_columns    : Character vector. The order of the columns of
#                       Main_df_computed (parameters$needed_cols).
#   asset_columns     : Named list, one element per type of model,
#                       each a character vector. The order of the
#                       columns of the table of the assets of the type
#                       (parameters$asset_cols).
#   asset_types       : Named character vector. The type of model of
#                       each asset, named by asset_id.
#   economic_analysis : List of 3 data frames (market, decision,
#                       slot), as completed by finalize().
#   execution_time    : List. Timing information of the simulation.
#   optimization      : List. The optimization parameters
#                       (parameters$optimization).
#   output_path       : Character. Path of the output directory,
#                       created when it does not exist.
# -------------------------------------------------------------
# Outputs
#   output_path, returned invisibly. The function writes the tables
#   below to it, each as .csv and .rds:
#     - Main_df_computed
#     - <asset_id>_df_computed, one per asset
#     - Sinthetized_df_computed
#     - Economic_analysis_market_computed
#     - Economic_analysis_decision_computed
#     - Economic_analysis_slot_computed
# -------------------------------------------------------------
# Code outline
# 1. Create output directory if needed
# 2. Check the tables of the assets
# 3. Export Main_df_computed
# 4. Export the table of each asset
# 5. Build and export synthesized summary data frame
# 6. Export the three economic analysis tables
# 7. Return the output path
# -------------------------------------------------------------
# Usage instructions
# write_outputs(
#   Main_df           = Main_df,
#   assets            = assets,
#   system_columns    = parameters$needed_cols,
#   asset_columns     = parameters$asset_cols,
#   asset_types       = asset_types,
#   economic_analysis = economic_analysis,
#   execution_time    = execution_time,
#   optimization      = parameters$optimization,
#   output_path       = paths$output_path
# )
# -------------------------------------------------------------

write_outputs <- function(Main_df,
                          assets,
                          system_columns,
                          asset_columns,
                          asset_types,
                          economic_analysis,
                          execution_time,
                          optimization,
                          output_path
                          ) {

  # -------------------------------------------------------------
  # 1. Create output directory if needed
  # -------------------------------------------------------------
  {
    if (!dir.exists(output_path)) {
      dir.create(output_path, recursive = TRUE)
    }
  }

  # -------------------------------------------------------------
  # 2. Check the tables of the assets
  # The table of each asset has one row per row of Main_df, at the
  # same times, so that both join by time.
  # -------------------------------------------------------------
  {
    for (CONT_001 in names(assets)) {
      asset_df <- assets[[CONT_001]]$df
      if (nrow(asset_df) != nrow(Main_df)) {
        stop("write_outputs: the table of ", CONT_001, " has ",
             nrow(asset_df), " rows and Main_df has ", nrow(Main_df))
      }
      if (!identical(as.numeric(asset_df$time),
                     as.numeric(Main_df$time))) {
        stop("write_outputs: the column time of the table of ",
             CONT_001, " differs from that of Main_df")
      }
      rm(list = "asset_df")
    }
  }

  # -------------------------------------------------------------
  # 3. Export Main_df_computed
  # output_table gives a table with its columns in a given order and
  # the columns not in it after them. Each column is the subset of
  # the column of the table, and the result is a data table, the
  # class of the tables of the simulation.
  # -------------------------------------------------------------
  {
    output_table <- function(table, column_order) {
      ordered <- c(intersect(column_order, names(table)),
                   setdiff(names(table), column_order))
      rows    <- seq_len(nrow(table))
      result  <- lapply(ordered, function(CONT_002) {
        table[[CONT_002]][rows]
      })
      names(result) <- ordered
      result <- structure(result,
                          row.names = .set_row_names(length(rows)),
                          class     = "data.frame")
      setDT(result)
      return(result)
    }

    Main_df_computed <- output_table(
      table        = Main_df,
      column_order = system_columns
    )

    write.csv(
      Main_df_computed,
      file.path(output_path, "Main_df_computed.csv"),
      row.names = FALSE
    )
    write_rds(
      Main_df_computed,
      file.path(output_path, "Main_df_computed.rds")
    )
  }

  # -------------------------------------------------------------
  # 4. Export the table of each asset
  # -------------------------------------------------------------
  {
    for (CONT_003 in names(assets)) {
      # output_table gives the table of the asset with time first and
      # its columns in the order of the columns of its type.
      asset_computed <- output_table(
        table        = assets[[CONT_003]]$df,
        column_order = asset_columns[[asset_types[[CONT_003]]]]
      )

      write.csv(
        asset_computed,
        file.path(output_path, paste0(CONT_003, "_df_computed.csv")),
        row.names = FALSE
      )
      write_rds(
        asset_computed,
        file.path(output_path, paste0(CONT_003, "_df_computed.rds"))
      )
      rm(list = "asset_computed")
    }
  }

  # -------------------------------------------------------------
  # 5. Build and export synthesized summary data frame
  # -------------------------------------------------------------
  {
    # A flexibility activation is considered booked on a row when the
    # execution phase wrote either of the two signals reserved for it,
    # the same definition as the flex_activated of finalize().
    # Neither is written today, so Flex_exec_down/up are always 0.
    flex_activated <- as.numeric(
      Main_df_computed$Elec_flex_execution_revenue_h  != 0 |
      Main_df_computed$Elec_flex_deviations_net_cost_h != 0
    )

    # The comfort of the system is the comfort of the assets whose
    # table holds Comfort_exec, 0 when there is none.
    comfort_assets <- Filter(function(CONT_004) {
      "Comfort_exec" %in% names(CONT_004$df)
    }, assets)

    # system_net_energy gives the executed net electricity of the
    # system, whose imported and exported parts are added up.
    Sinthetized_df <- data.frame(
      as.data.frame(optimization),
      Comfort           = sum(vapply(comfort_assets, function(CONT_005) {
        sum(CONT_005$df$Comfort_exec)
      }, numeric(1))),
      Elec_total_in     = sum(pmax(system_net_energy(Main_df_computed, "exec"), 0)),
      Elec_total_out    = sum(pmax(-system_net_energy(Main_df_computed, "exec"), 0)),
      Flex_plan_up      = sum(Main_df_computed$Elec_flex_up_plan),
      Flex_plan_down    = sum(Main_df_computed$Elec_flex_down_plan),
      Flex_exec_up      = sum(Main_df_computed$Elec_flex_up_plan * flex_activated),
      Flex_exec_down    = sum(Main_df_computed$Elec_flex_down_plan * flex_activated),
      Elec_cost         = -sum(economic_analysis$slot$Cost_energy_bought),
      Elec_revenue      = sum(economic_analysis$slot$Revenue_energy_sold),
      Flex_plan_revenue = sum(economic_analysis$slot$Revenue_flex_commitments),
      Flex_exec_revenue = sum(
        economic_analysis$market$Flex_executed_cash_flow,
        na.rm = TRUE
      ),
      Distr_cost        = sum(economic_analysis$slot$Distribution_cost),
      Reward            = sum(economic_analysis$decision$Reward),
      Process_time      = execution_time$t_process
    )

    write.csv(
      Sinthetized_df,
      file.path(output_path, "Sinthetized_df_computed.csv"),
      row.names = FALSE
    )
    write_rds(
      Sinthetized_df,
      file.path(output_path, "Sinthetized_df_computed.rds")
    )

    rm(list = c("flex_activated", "comfort_assets", "Sinthetized_df",
                "Main_df_computed", "output_table"))
  }

  # -------------------------------------------------------------
  # 6. Export the three economic analysis tables
  # -------------------------------------------------------------
  {
    write.csv(
      economic_analysis$market,
      file.path(output_path, "Economic_analysis_market_computed.csv"),
      row.names = FALSE
    )
    write_rds(
      economic_analysis$market,
      file.path(output_path, "Economic_analysis_market_computed.rds")
    )

    write.csv(
      economic_analysis$decision,
      file.path(output_path, "Economic_analysis_decision_computed.csv"),
      row.names = FALSE
    )
    write_rds(
      economic_analysis$decision,
      file.path(output_path, "Economic_analysis_decision_computed.rds")
    )

    write.csv(
      economic_analysis$slot,
      file.path(output_path, "Economic_analysis_slot_computed.csv"),
      row.names = FALSE
    )
    write_rds(
      economic_analysis$slot,
      file.path(output_path, "Economic_analysis_slot_computed.rds")
    )
  }

  # -------------------------------------------------------------
  # 7. Return the output path
  # -------------------------------------------------------------
  {
    return(invisible(output_path))
  }
}
