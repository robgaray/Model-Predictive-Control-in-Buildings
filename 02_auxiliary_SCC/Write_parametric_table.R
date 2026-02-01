# -------------------------------------------------------------
# Script: Write_parametric_table.R
# Script to create a full-factorial grid of parameter combinations.
# with the following constraints: control horizon <= optimization_horizon
# Developed by Roberto Garay Martinez & ChatGPT
# -------------------------------------------------------------

# Load libraries
library(tidyverse)

# Define parameter levels
population_size         <- seq(20,40,10)
iteration_number        <- seq(20,40,10)
run_number              <- seq(3,5,1)
optimization_horizon    <- seq(12,24,6)
control_horizon  		<- seq(12,24,6)
month                   <- c(0)
period                  <- c(0)
control_type            <- c(1,2)
forecast_type           <- c(1,2)

# Build full factorial using tidyr::crossing (creates all combinations)
parametric_simulation_grid <- crossing(
  population_size         = population_size,
  iteration_number        = iteration_number,
  run_number              = run_number,
  optimization_horizon    = optimization_horizon,
  control_horizon  		  = control_horizon,
  month                   = month,
  period				  = period,
  control_type			  = control_type,
  forecast_type			  = forecast_type
) %>%
  # Apply constraint: control_horizon must be <= optimization_horizon
  filter(control_horizon <= optimization_horizon) %>%
  # Optionally arrange rows for a stable ordering
  arrange(population_size, iteration_number, run_number,
          optimization_horizon, control_horizon, month, period,
		  control_type, forecast_type)

# Quick info: number of combinations
cat("Number of rows (valid combinations):", nrow(parametric_simulation_grid), "\n")

# Show first few rows
print(head(parametric_simulation_grid, 12))

# Save to disk
write.csv2(parametric_simulation_grid,
           file = "Optim_parameters.csv",
           row.names = FALSE)

