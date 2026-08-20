# -------------------------------------------------------------
# Script: assemble_main_df.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Replaces the previous "Main_df <- readRDS(paths$main_file)" step.
# Loads the 2 real input dataframes (Meteo_df, Energy_Prices_df) and
# generates the 3 synthetic dataframes (System_df, Flexibility_actions_df,
# Meteo_transformations_df) on a common 5' master grid, then assembles
# them into a single Main_df - exactly the interface the rest of the
# codebase expects. See
# 01_Agent_Comments/20260722b_Plan_Señales_por_Procedencia.md for the
# full rationale (Partes A-G).
# -------------------------------------------------------------
# Inputs
#   paths : List. Must contain meteo_file, meteo_validation_file,
#           energy_prices_file, energy_prices_validation_file,
#           system_variables_file (set by initialization.R).
# -------------------------------------------------------------
# Outputs
#   Main_df : Data frame. time (POSIXct, 5' grid) + Meteo_df's columns
#             (interpolated) + Energy_Prices_df's columns (step-held) +
#             System_df + Flexibility_actions_df + Meteo_transformations_df
#             (all generated directly on the 5' grid).
# -------------------------------------------------------------
# Code outline
# 1. Load and validate Meteo_df, Energy_Prices_df
# 2. Determine the common time range (start strict, end trimmed with
#    warning) and build the 5' master grid
# 3. Interpolate Meteo_df onto the master grid
# 4. Step-hold Energy_Prices_df onto the master grid
# 5. Generate System_df, Flexibility_actions_df, Meteo_transformations_df
# 6. Assemble Main_df
# -------------------------------------------------------------
# Usage
# source(file.path("30_Simulation", "04_Scripts", "assemble_main_df.R"))
# -------------------------------------------------------------
# Where this script is used
# Sourced by load_all_parameters.R, replacing the previous
# "Main_df <- readRDS(paths$main_file)" step.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If Meteo_df$time and Energy_Prices_df$time do not start at
#     exactly the same instant, stop() (no permissive fallback for the
#     start of the series).
#   - If one series ends later than the other, the longer one is
#     trimmed to the shorter one's end, and warning() reports how many
#     rows were discarded and from which file.
# -------------------------------------------------------------
# functions/scripts called
#   load_meteo_df.R, load_energy_prices_df.R (04_Scripts)
#   generate_system_df(), generate_flexibility_actions_df(),
#   generate_meteo_transformations_df() (03_Functions)
# -------------------------------------------------------------

main_resolution_sec <- 300

# -----------------------------------------------------------
# 1. Load and validate the 2 real input dataframes
# -----------------------------------------------------------
# load_meteo_df.R is sourced to read and validate the meteorological
# input file into Meteo_df, on its own native time grid.
source(file.path("30_Simulation", "04_Scripts", "load_meteo_df.R"))
# load_energy_prices_df.R is sourced to read and validate the energy
# price input file into Energy_Prices_df, on its own native time grid.
source(file.path("30_Simulation", "04_Scripts", "load_energy_prices_df.R"))

# -----------------------------------------------------------
# 2. Common time range: start strict, end trimmed with warning
# -----------------------------------------------------------
{
  meteo_start <- min(Meteo_df$time)
  energy_start <- min(Energy_Prices_df$time)
  if (meteo_start != energy_start) {
    stop("Meteo_df and Energy_Prices_df must start at exactly the same ",
         "instant. Meteo_df starts at ", format(meteo_start),
         ", Energy_Prices_df starts at ", format(energy_start), ".")
  }

  meteo_end  <- max(Meteo_df$time)
  energy_end <- max(Energy_Prices_df$time)
  common_end <- min(meteo_end, energy_end)

  if (meteo_end != common_end) {
    n_dropped <- sum(Meteo_df$time > common_end)
    warning("Meteo_df extends beyond Energy_Prices_df's end (",
            format(energy_end), "). Trimming ", n_dropped,
            " row(s) from Meteo_df at the end.")
    Meteo_df <- Meteo_df[Meteo_df$time <= common_end, ]
  }

  if (energy_end != common_end) {
    n_dropped <- sum(Energy_Prices_df$time > common_end)
    warning("Energy_Prices_df extends beyond Meteo_df's end (",
            format(meteo_end), "). Trimming ", n_dropped,
            " row(s) from Energy_Prices_df at the end.")
    Energy_Prices_df <- Energy_Prices_df[Energy_Prices_df$time <= common_end, ]
  }

  master_grid <- seq(from = meteo_start, to = common_end, by = main_resolution_sec)

  rm(meteo_start, energy_start, meteo_end, energy_end, common_end)
}

# -----------------------------------------------------------
# 3. Interpolate Meteo_df onto the master grid (linear, rule = 2)
# -----------------------------------------------------------
{
  master_grid_num <- as.numeric(master_grid)
  meteo_time_num  <- as.numeric(Meteo_df$time)

  Meteo_interp <- data.frame(time = master_grid)
  for (CONT_001 in setdiff(names(Meteo_df), "time")) {
    Meteo_interp[[CONT_001]] <- approx(
      x      = meteo_time_num,
      y      = Meteo_df[[CONT_001]],
      xout   = master_grid_num,
      method = "linear",
      rule   = 2
    )$y
  }
  rm(CONT_001, meteo_time_num)
}

# -----------------------------------------------------------
# 4. Step-hold Energy_Prices_df onto the master grid (last observed value)
# -----------------------------------------------------------
{
  energy_time_num <- as.numeric(Energy_Prices_df$time)
  hold_idx        <- findInterval(master_grid_num, energy_time_num)

  if (any(hold_idx < 1)) {
    stop("assemble_main_df.R: master grid contains timestamps earlier than ",
         "Energy_Prices_df's first row - no prior value to hold.")
  }

  Energy_interp <- data.frame(time = master_grid)
  for (CONT_002 in setdiff(names(Energy_Prices_df), "time")) {
    Energy_interp[[CONT_002]] <- Energy_Prices_df[[CONT_002]][hold_idx]
  }
  rm(CONT_002, energy_time_num, hold_idx, master_grid_num)
}

# -----------------------------------------------------------
# 5. Generate the 3 synthetic dataframes on the master grid
# -----------------------------------------------------------
{
  # generate_system_df is called to synthesize the System_df variables
  # directly on the 5' master grid, from the system_variables_file
  # definitions.
  System_df <- generate_system_df(paths$system_variables_file, master_grid)
  # generate_flexibility_actions_df is called to synthesize the
  # Flexibility_actions_df placeholder columns on the same master grid.
  Flexibility_actions_df <- generate_flexibility_actions_df(master_grid)
  # generate_meteo_transformations_df is called to synthesize the
  # Meteo_transformations_df derived-weather columns on the same master grid.
  Meteo_transformations_df <- generate_meteo_transformations_df(master_grid)
}

# -----------------------------------------------------------
# 6. Assemble Main_df
# -----------------------------------------------------------
{
  Main_df <- cbind(
    Meteo_interp,
    Energy_interp[, setdiff(names(Energy_interp), "time"), drop = FALSE],
    System_df[, setdiff(names(System_df), "time"), drop = FALSE],
    Flexibility_actions_df[, setdiff(names(Flexibility_actions_df), "time"), drop = FALSE],
    Meteo_transformations_df[, setdiff(names(Meteo_transformations_df), "time"), drop = FALSE]
  )

  cat("Main_df assembled:", nrow(Main_df), "rows,", format(min(Main_df$time)),
      "->", format(max(Main_df$time)), "\n")

  rm(Meteo_interp, Energy_interp, System_df, Flexibility_actions_df,
     Meteo_transformations_df, master_grid, main_resolution_sec,
     Meteo_df, Energy_Prices_df, meteo_step_sec, energy_prices_step_sec)
}
