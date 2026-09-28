# -------------------------------------------------------------
# Function: generate_system_df.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds System_df from the declarative variable registry
# (Simulation_Variables_Building.txt), on the given time grid. This is
# a synthetic dataframe: it is not loaded from a data file, it is
# generated fresh on every run, with every column initialized to its
# registry initial_value (0 today) - the simulation itself fills these
# columns in as it runs (period_calculation(), reward_function(), etc.).
# Variables with scenario == "yes" are expanded into 4 columns
# (<variable>_exec, <variable>_plan, <variable>_plan_flex_down,
# <variable>_plan_flex_up); variables
# with scenario == "no" are kept as a single column, <variable>. See
# 01_Agent_Comments/20260722b_Plan_Señales_por_Procedencia.md, Part C.
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
# 1. Read the variable registry and check its columns.
# 2. Check every scenario flag is yes or no.
# 3. Build one column per variable, at its initial value, over the
#    time vector.
# -------------------------------------------------------------
# Usage instructions
#   df <- generate_system_df(registry_path, time)
# -------------------------------------------------------------
# Where this function/script is used
# Called by assemble_main_df.R to build System_df on the master time
# grid, from the Simulation_Variables_Building.txt registry, before it
# is merged into Main_df.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If the registry file is missing any required column, stop(). The
#     required columns are those listed under Inputs.
#   - If scenario contains a value other than "yes"/"no", stop().
#   - Ti and Te are not special-cased here: their row-1 initial_value is
#     overwritten later by parameters$model$Ti_0/Te_0 in 14_simulation.R
#     (see Part G of the plan document above); this function only
#     applies the generic registry initial_value.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

generate_system_df <- function(registry_path, time) {

  registry <- read.delim(registry_path, comment.char = "#", stringsAsFactors = FALSE)

  required_cols <- c("variable", "type", "initial_value", "scenario")
  missing_cols  <- setdiff(required_cols, names(registry))
  if (length(missing_cols) > 0) {
    stop("Simulation_Variables_Building.txt is missing required columns: ",
         paste(missing_cols, collapse = ", "))
  }

  invalid_scenario <- setdiff(unique(trimws(registry$scenario)), c("yes", "no"))
  if (length(invalid_scenario) > 0) {
    stop("Simulation_Variables_Building.txt has invalid scenario value(s): ",
         paste(invalid_scenario, collapse = ", "), ". Must be 'yes' or 'no'.")
  }

  n <- length(time)
  System_df <- data.frame(time = time)

  for (CONT_001 in seq_len(nrow(registry))) {
    variable      <- trimws(registry$variable[CONT_001])
    initial_value <- as.numeric(registry$initial_value[CONT_001])
    scenario      <- trimws(registry$scenario[CONT_001])

    if (scenario == "yes") {
      System_df[[paste0(variable, "_exec")]]           <- rep(initial_value, n)
      System_df[[paste0(variable, "_plan")]]            <- rep(initial_value, n)
      System_df[[paste0(variable, "_plan_flex_down")]]  <- rep(initial_value, n)
      System_df[[paste0(variable, "_plan_flex_up")]]    <- rep(initial_value, n)
    } else {
      System_df[[variable]] <- rep(initial_value, n)
    }
  }
  rm(CONT_001)

  return(System_df)
}
