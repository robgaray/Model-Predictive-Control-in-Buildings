# -------------------------------------------------------------
# Function: variable_registry_columns.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Reads a declarative variable registry, Simulation_Variables_<name>.txt,
# and returns the columns it declares, in the order of the registry.
# There is one registry for the system
# (00_System/Simulation_Variables_System.txt), whose columns the
# market table of the call holds, and one for each type of model of
# an asset (for a building,
# 01_Building/Simulation_Variables_Building.txt), whose columns the
# table of each asset of that type holds.
# It is the one place where a variable of a registry is turned into
# its columns:
#   - scenario == "yes": three columns, <variable>_plan,
#     <variable>_plan_flex_down and <variable>_plan_flex_up. The
#     last two are the two flexibility itineraries: downward (load
#     reduction) and upward (load increase).
#   - scenario == "no": one column, <variable>, with no suffix.
# Everything that needs the columns of a registry reads them from
# here, so the registry is the only file that declares them.
# -------------------------------------------------------------
# Inputs
#   registry_path : Character. Path to a Simulation_Variables_<name>.txt
#                   file, tab-separated, with the columns:
#                     - variable
#                     - type
#                     - initial_value
#                     - scenario
# -------------------------------------------------------------
# Outputs
#   Data frame, one row per column the registry declares, in
#   registry order, with the columns:
#     - column        : Character. The name of the column.
#     - variable      : Character. The variable of the registry.
#     - initial_value : Numeric. The initial value of the variable.
#     - scenario      : Character. "yes" when the variable is expanded
#                       into the three itineraries, "no" otherwise.
# -------------------------------------------------------------
# Code outline
# 1. Read the variable registry and check its columns
# 2. Check every scenario flag is yes or no
# 3. Expand every variable into its columns
# -------------------------------------------------------------
# Usage instructions
#   columns <- variable_registry_columns(paths$building_variables_file)
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If the registry file is missing any required column, stop(). The
#     required columns are those listed under Inputs.
#   - If scenario contains a value other than "yes"/"no", stop().
# -------------------------------------------------------------

variable_registry_columns <- function(registry_path) {

  # -------------------------------------------------------------
  # 1. Read the variable registry and check its columns
  # -------------------------------------------------------------
  {
    registry_name <- basename(registry_path)
    registry      <- read.delim(registry_path, comment.char = "#",
                                stringsAsFactors = FALSE)

    required_cols <- c("variable", "type", "initial_value", "scenario")
    missing_cols  <- setdiff(required_cols, names(registry))
    if (length(missing_cols) > 0) {
      stop(registry_name, " is missing required columns: ",
           paste(missing_cols, collapse = ", "))
    }

    rm(list = c("required_cols", "missing_cols"))
  }

  # -------------------------------------------------------------
  # 2. Check every scenario flag is yes or no
  # -------------------------------------------------------------
  {
    invalid_scenario <- setdiff(unique(trimws(registry$scenario)),
                                c("yes", "no"))
    if (length(invalid_scenario) > 0) {
      stop(registry_name, " has invalid scenario value(s): ",
           paste(invalid_scenario, collapse = ", "),
           ". Must be 'yes' or 'no'.")
    }

    rm(list = c("invalid_scenario", "registry_name"))
  }

  # -------------------------------------------------------------
  # 3. Expand every variable into its columns
  # -------------------------------------------------------------
  {
    itinerary_suffixes <- c("_plan", "_plan_flex_down", "_plan_flex_up")

    columns <- lapply(seq_len(nrow(registry)), function(CONT_001) {
      variable     <- trimws(registry$variable[CONT_001])
      scenario     <- trimws(registry$scenario[CONT_001])
      column_names <- if (scenario == "yes") {
        paste0(variable, itinerary_suffixes)
      } else {
        variable
      }
      data.frame(
        column        = column_names,
        variable      = variable,
        initial_value = as.numeric(registry$initial_value[CONT_001]),
        scenario      = scenario,
        stringsAsFactors = FALSE
      )
    })
    columns <- do.call(rbind, columns)

    rm(list = c("registry", "itinerary_suffixes"))
  }

  return(columns)
}
