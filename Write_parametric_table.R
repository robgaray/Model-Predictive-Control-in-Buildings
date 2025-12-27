# --------------------------------------------------------------
# Create a full-factorial grid of parameter combinations
# with the constraint: optimization_frequency <= optimization_horizon
# --------------------------------------------------------------

# Load tidyverse for convenience (crossing + dplyr)
library(tidyverse)

# Define parameter levels
population_size         <- seq(10,50,10)
iteration_number        <- seq(10,50,10)
run_number              <- c(1, 2, 5, 10)
optimization_horizon    <- seq(6,24,6)
optimization_frequency  <- seq(6,24,6)
month                   <- c(0)

# Build full factorial using tidyr::crossing (creates all combinations)
parametric_simulation_grid <- crossing(
  population_size         = population_size,
  iteration_number        = iteration_number,
  run_number              = run_number,
  optimization_horizon    = optimization_horizon,
  optimization_frequency  = optimization_frequency,
  month                   = month
) %>%
  # Apply constraint: optimization_frequency must be <= optimization_horizon
  filter(optimization_frequency <= optimization_horizon) %>%
  # Optionally arrange rows for a stable ordering
  arrange(population_size, iteration_number, run_number,
          optimization_horizon, optimization_frequency, month)

# Quick info: number of combinations
cat("Number of rows (valid combinations):", nrow(parametric_simulation_grid), "\n")

# Show first few rows
print(head(parametric_simulation_grid, 12))

# Optional: save to disk (uncomment if needed)
write.csv2(parametric_simulation_grid,
           file = "Optim_parameters.csv",
           row.names = FALSE)

