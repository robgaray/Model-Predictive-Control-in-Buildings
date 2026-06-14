# -------------------------------------------------------------
# Script: inspection_step.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Inspection helper for simulation.R. When sourced inside the
# simulation loop, it dumps Main_df to a named object and
# generates a diagnostic two-panel plot.
# -------------------------------------------------------------
# Inputs (expected in calling environment)
#   Main_df          : Data frame. Current simulation state.
#   inspection_step  : Integer. Current simulation step.
#   inspection_proc  : Character. "scheduling", "piloting", or "execution".
#   inspection_phase : Character. "begin" or "end".
#   inspection_range : Integer vector. Steps to inspect.
# -------------------------------------------------------------
# Outputs
#   Assigns Main_df snapshot to environment with standardized name.
#   Produces a two-panel diagnostic plot.
# -------------------------------------------------------------
# Code outline
#   1. Check if current step is in inspection range
#   2. Dump Main_df to named object
#   3. Generate two-panel plot
# -------------------------------------------------------------
# Usage instructions
#   Set inspection_step, inspection_proc, inspection_phase, then:
#   source(file.path("30_Simulation", "04_Scripts", "inspection_step.R"))
# -------------------------------------------------------------
# Where this script is used
#   Sourced by simulation.R at six inspection points per loop iteration.
# -------------------------------------------------------------
# functions/scripts called
#   (none - base R graphics only)
# -------------------------------------------------------------

# 1. Check if current step is in inspection range
if (inspection_step %in% inspection_range) {

  # 2. Dump Main_df snapshot
  {
    snapshot_name <- paste0(
      "Main_df_", inspection_step, "_", inspection_proc, "_", inspection_phase
    )
    assign(snapshot_name, Main_df, envir = .GlobalEnv)
  }

  # 3. Generate two-panel diagnostic plot
  {
    # Determine axis ranges from full Main_df (for consistency across subsets)
    y_temp_range <- c(0, 50)
    y_occ_range  <- c(0, max(1, max(Main_df$Occupancy, na.rm = TRUE)))

    q_heat_all   <- c(Main_df$Q_heat, Main_df$Q_heat_plan)
    q_cool_all   <- c(Main_df$Q_cool, Main_df$Q_cool_plan)
    q_all        <- c(q_heat_all, q_cool_all)
    x_range <-c(Main_df$time[inspection_range[1]], Main_df$time[inspection_range[length(inspection_range)]])
    y_q_range    <- c(min(0, min(q_all, na.rm = TRUE)), max(0.01, max(q_all, na.rm = TRUE)))

    y_price_range <- c(0, max(0.01, max(Main_df$Elec_unit_cost_buy, na.rm = TRUE)))

    rm(q_heat_all, q_cool_all, q_all)

    par(mfrow = c(2, 1), mar = c(4, 4, 3, 4), cex.main = 1.2, cex.lab = 1.0, cex.axis = 0.9)

    # --- Upper panel: Temperatures and Occupancy ---
    {
      plot(
        Main_df$time[inspection_range], Main_df$Ti[inspection_range],
        type = "l", col = "black", lwd = 1,
        xlab = "Time", ylab = "Temperature (C)",
        ylim = y_temp_range,
        xlim = x_range,
        main = paste0("Step ", inspection_step, " | ", inspection_proc, " | ", inspection_phase)
      )
      lines(Main_df$time, Main_df$Ti_plan,  col = "red",   lwd = 1)
      lines(Main_df$time, Main_df$STP_heat, col = "green", lwd = 1)
      lines(Main_df$time, Main_df$STP_cool, col = "blue",  lwd = 1)

      legend(
        "topleft",
        legend = c("Ti", "Ti_plan", "STP_heat", "STP_cool"),
        col    = c("black", "red", "green", "blue"),
        lwd    = 1, cex = 0.8, bg = "white"
      )

      par(new = TRUE)
      plot(
        Main_df$time[inspection_range], Main_df$Occupancy[inspection_range],
        type = "l", col = "grey50", lty = 2, lwd = 1,
        axes = FALSE, xlab = "", ylab = "",
        ylim = y_occ_range,
        xlim = x_range
      )
      axis(side = 4)
      mtext("Occupancy", side = 4, line = 2.5, cex = 0.8)
      legend(
        "topright",
        legend = c("Occupancy"),
        col    = c("grey50"),
        lty    = 2, lwd = 1, cex = 0.8, bg = "white"
      )
    }

    # --- Lower panel: Energy and Price ---
    {
      plot(
        Main_df$time[inspection_range], Main_df$Q_heat[inspection_range],
        type = "l", col = "black", lwd = 1,
        xlab = "Time", ylab = "Energy (kWh)",
        ylim = y_q_range,
        xlim = x_range,
        main = ""
      )
      lines(Main_df$time, Main_df$Q_heat_plan, col = "red",   lwd = 1)
      lines(Main_df$time, Main_df$Q_cool,      col = "green", lwd = 1)
      lines(Main_df$time, Main_df$Q_cool_plan, col = "blue",  lwd = 1)

      legend(
        "topleft",
        legend = c("Q_heat", "Q_heat_plan", "Q_cool", "Q_cool_plan"),
        col    = c("black", "red", "green", "blue"),
        lwd    = 1, cex = 0.8, bg = "white"
      )

      par(new = TRUE)
      plot(
        Main_df$time[inspection_range], Main_df$Elec_unit_cost_buy[inspection_range],
        type = "l", col = "grey50", lty = 2, lwd = 1,
        axes = FALSE, xlab = "", ylab = "",
        ylim = y_price_range,
        xlim = x_range
      )
      axis(side = 4)
      mtext("Elec_unit_cost_buy", side = 4, line = 2.5, cex = 0.8)
      legend(
        "topright",
        legend = c("Elec_unit_cost_buy"),
        col    = c("grey50"),
        lty    = 2, lwd = 1, cex = 0.8, bg = "white"
      )
    }

    par(mfrow = c(1, 1))
    rm(snapshot_name, y_temp_range, y_occ_range, y_q_range, y_price_range)
  }
}
