# -------------------------------------------------------------
# Script: assemble_main_df.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads the 2 real input dataframes:
#   - Meteo_df
#   - Energy_Prices_df
# and generates the 3 synthetic dataframes:
#   - System_variables_df
#   - Flexibility_actions_df
#   - Meteo_transformations_df
# on a common master grid, then assembles them into a single
# Main_df: what is common to every asset and the balances of the
# system. The columns of each asset are not in Main_df: they are in
# the table of the asset, which load_all_parameters() builds on the
# same grid once the asset registry is loaded.
# -------------------------------------------------------------
# Inputs
#   paths      : List, built by initialize_simulator(). Must contain:
#                  - meteo_file
#                  - meteo_validation_file
#                  - energy_prices_file
#                  - energy_prices_validation_file
#                  - system_variables_file
#   parameters : List. Must contain parameters$computing, already
#                loaded by load_internal_parameters.R, whose
#                main_resolution_sec defines the master grid built
#                here.
# -------------------------------------------------------------
# Outputs
#   Main_df : Data frame on the master grid, with the columns of:
#               - time (POSIXct, master grid)
#               - Meteo_df (interpolated)
#               - Energy_Prices_df (step-held, at the start of each
#                 row's time step)
#               - System_variables_df
#               - Flexibility_actions_df
#               - Meteo_transformations_df
#             The last three are generated directly on the master grid.
#   One DATA line is written to the console, and a WARNING line when
#   the end of a series is trimmed.
# -------------------------------------------------------------
# Code outline
# 1. Load and validate Meteo_df, Energy_Prices_df
# 2. Determine the common time range (start strict, end trimmed with
#    warning) and build the master grid
# 3. Interpolate Meteo_df onto the master grid
# 4. Step-hold Energy_Prices_df onto the master grid, at the start of
#    each row's time step
# 5. Generate System_variables_df, Flexibility_actions_df,
#    Meteo_transformations_df
# 6. Assemble Main_df
# -------------------------------------------------------------
# Usage instructions
#   source(file.path("30_Simulation", "04_Scripts", "assemble_main_df.R"))
#   Not called: sourced by load_all_parameters(), once the
#   configuration is loaded and before Main_df is validated.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If Meteo_df$time and Energy_Prices_df$time do not start at
#     exactly the same instant, stop() (no permissive fallback for the
#     start of the series).
#   - If one series ends later than the other, the longer one is
#     trimmed to the shorter one's end, and a WARNING line of the
#     console reports how many rows were discarded and from which
#     file.
#   - The first row has no time step before it, so it takes the first
#     price of Energy_Prices_df.
# -------------------------------------------------------------

# The resolution of the master grid is the engine's own
# main_resolution_sec, read from 01_computing_parameters.csv into
# parameters$computing by load_internal_parameters.R. It is the
# single definition of the simulation's time step: validate_time_grid()
# and load_03_market_config.R check the input series and the market
# slot against this same value.
main_resolution_sec <- parameters$computing$main_resolution_sec

# -----------------------------------------------------------
# 1. Load and validate the 2 real input dataframes
# -----------------------------------------------------------
# load_meteo_df.R is sourced to read and validate the meteorological
# input file into Meteo_df, on its own native time grid.
source(file.path("30_Simulation", "04_Scripts", "load_meteo_df.R"), local = TRUE)
# load_energy_prices_df.R is sourced to read and validate the energy
# price input file into Energy_Prices_df, on its own native time grid.
source(file.path("30_Simulation", "04_Scripts", "load_energy_prices_df.R"), local = TRUE)

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
    # console_message is called to tell that the end of Meteo_df is
    # trimmed to the end of Energy_Prices_df.
    console_message(
      label = "WARNING",
      text  = paste0("assemble_main_df: Meteo_df extends beyond ",
                     "Energy_Prices_df's end (", console_time(energy_end),
                     "). Trimming ", n_dropped,
                     " row(s) from Meteo_df at the end")
    )
    Meteo_df <- Meteo_df[Meteo_df$time <= common_end, ]
  }

  if (energy_end != common_end) {
    n_dropped <- sum(Energy_Prices_df$time > common_end)
    # console_message is called to tell that the end of
    # Energy_Prices_df is trimmed to the end of Meteo_df.
    console_message(
      label = "WARNING",
      text  = paste0("assemble_main_df: Energy_Prices_df extends beyond ",
                     "Meteo_df's end (", console_time(meteo_end),
                     "). Trimming ", n_dropped,
                     " row(s) from Energy_Prices_df at the end")
    )
    Energy_Prices_df <- Energy_Prices_df[Energy_Prices_df$time <= common_end, ]
  }

  master_grid <- seq(from = meteo_start, to = common_end, by = main_resolution_sec)

  rm(list = c("meteo_start", "energy_start", "meteo_end", "energy_end",
              "common_end"))
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
  rm(list = c("CONT_001", "meteo_time_num"))
}

# -----------------------------------------------------------
# 4. Step-hold Energy_Prices_df onto the master grid (last observed value)
# A row holds the energy of the time step that ends at its instant, so
# it is priced at the start of that step: the last price observed at
# or before the instant one step earlier. Every row of a market
# interval then carries the price of that interval. The first row has
# no time step before it and takes the first price.
# -----------------------------------------------------------
{
  energy_time_num <- as.numeric(Energy_Prices_df$time)
  hold_idx        <- findInterval(master_grid_num - main_resolution_sec,
                                  energy_time_num)
  hold_idx[1]     <- 1L

  if (any(hold_idx < 1)) {
    stop("assemble_main_df.R: master grid contains timestamps earlier than ",
         "Energy_Prices_df's first row - no prior value to hold.")
  }

  Energy_interp <- data.frame(time = master_grid)
  for (CONT_002 in setdiff(names(Energy_Prices_df), "time")) {
    Energy_interp[[CONT_002]] <- Energy_Prices_df[[CONT_002]][hold_idx]
  }
  rm(list = c("CONT_002", "energy_time_num", "hold_idx", "master_grid_num"))
}

# -----------------------------------------------------------
# 5. Generate the 3 synthetic dataframes on the master grid
# -----------------------------------------------------------
{
  # generate_variables_df is called to synthesize the
  # System_variables_df variables directly on the 5' master grid,
  # from the variable registry of the system.
  System_variables_df <- generate_variables_df(paths$system_variables_file, master_grid)
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
    System_variables_df[, setdiff(names(System_variables_df), "time"), drop = FALSE],
    Flexibility_actions_df[, setdiff(names(Flexibility_actions_df), "time"), drop = FALSE],
    Meteo_transformations_df[, setdiff(names(Meteo_transformations_df), "time"), drop = FALSE]
  )

  # console_message is called to write the only line of this script:
  # the rows and span of Main_df and the time step of each input
  # series.
  console_message(
    label = "DATA",
    text  = paste0("Main_df: ", nrow(Main_df), " rows, ",
                   console_time(min(Main_df$time)), " -> ",
                   console_time(max(Main_df$time)), "; Meteo_df step ",
                   meteo_step_sec, " s, Energy_Prices_df step ",
                   energy_prices_step_sec, " s")
  )

  rm(list = c("Meteo_interp", "Energy_interp", "System_variables_df",
              "Flexibility_actions_df", "Meteo_transformations_df",
              "master_grid", "main_resolution_sec", "Meteo_df",
              "Energy_Prices_df", "meteo_step_sec", "energy_prices_step_sec"))
}
