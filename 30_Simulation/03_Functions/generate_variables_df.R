# -------------------------------------------------------------
# Function: generate_variables_df.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds a synthetic dataframe from a declarative variable registry
# (Simulation_Variables_<name>.txt), on the given time grid:
#   - from the registry of the system, System_variables_df, which
#     assemble_main_df.R joins into Main_df;
#   - from the registry of the type of model of an asset (for a
#     building, variables_df), the table of each asset of
#     that type, assets[[asset_id]]$df.
# It is not loaded from a data file, it is generated fresh on every
# run, with every column initialized to its registry initial_value (0
# today) - the simulation itself fills these columns in as it runs
# (period_calculation(), reward_function(), etc.).
# Each variable is expanded into its columns by
# variable_registry_columns(): four columns (<variable>_exec,
# <variable>_plan, <variable>_plan_flex_down,
# <variable>_plan_flex_up) when scenario == "yes", and a single
# column, <variable>, when scenario == "no".
# -------------------------------------------------------------
# Inputs
#   registry_path : Character. Path to a Simulation_Variables_<name>.txt
#                  file, tab-separated, with the columns:
#                    - variable
#                    - type
#                    - initial_value
#                    - scenario
#   time          : POSIXct vector. The master 5' time grid of Main_df.
# -------------------------------------------------------------
# Outputs
#   Data frame, with the columns:
#     - time
#     - per registry row, in registry order: one column when
#       scenario == "no", four when scenario == "yes"
# -------------------------------------------------------------
# Code outline
# 1. Read the columns of the registry (variable_registry_columns())
# 2. Build one column per entry, at its initial value, over the
#    time vector
# -------------------------------------------------------------
# Usage instructions
#   df <- generate_variables_df(registry_path, time)
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - The registry is checked by variable_registry_columns(), which
#     stops on a missing column or an invalid scenario flag.
#   - Ti and Te are not special-cased here: their row-1 initial_value is
#     overwritten later by Ti_0/Te_0 of the model of the building in
#     simulate() (Model initialization block); this function only
#     applies the generic registry initial_value.
# -------------------------------------------------------------

generate_variables_df <- function(registry_path, time) {

  # -------------------------------------------------------------
  # 1. Read the columns of the registry
  # -------------------------------------------------------------
  {
    # variable_registry_columns is called to read and check the
    # registry and to expand every variable into its columns, so
    # that the columns are declared in one place only.
    columns <- variable_registry_columns(registry_path)
  }

  # -------------------------------------------------------------
  # 2. Build one column per entry, at its initial value
  # -------------------------------------------------------------
  {
    n            <- length(time)
    variables_df <- data.frame(time = time)

    for (CONT_001 in seq_len(nrow(columns))) {
      variables_df[[columns$column[CONT_001]]] <-
        rep(columns$initial_value[CONT_001], n)
    }
    rm(list = c("CONT_001", "columns", "n"))
  }

  return(variables_df)
}
