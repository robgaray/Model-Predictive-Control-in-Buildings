# -------------------------------------------------------------
# Script: PostProcess_flexibility_analysis.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This script post-processes the Main_df_computed_**** output
# files produced by Main.R or Main_SCC.R.
# It reads all Main_df_computed_*.rds files from 01_Input,
# computes the flexibilized energy signal (E_flex), and
# generates:
#
#   Per day (for each calendar day in the dataset):
#     Graph 1 -- Temperature (Text, Ti_plan, Ti_plan_flex)
#                and Occupancy
#     Graph 2 -- Electrical energy (Elec_total_plan,
#                Elec_total_plan_flex) and prices
#                (Elec_unit_cost_buy,
#                Flex_unit_cost_down_com,
#                Flex_unit_cost_down_exec)
#
#   Overall summary (one chart per input file):
#     Graph 3 -- Frequency bar chart: fraction of timesteps
#                per hour of day in which E_flex > 0
#     Graph 4 -- Scatterplot: daily aggregate of
#                Elec_total_plan (X) vs daily aggregate of
#                E_flex (Y)
#
# Calculation:
#   E_flex = Elec_total_plan - Elec_total_plan_flex
#   (positive values only)
# -------------------------------------------------------------
# Colour / line-type conventions (Graphs 1 & 2):
#   Graph 1 -- basic colour palette:
#     Text            : "black"   lty = 1
#     Ti_plan         : "red"     lty = 1
#     Ti_plan_flex    : "green"   lty = 2
#     Comfort bounds  : "blue"    lty = 3
#     Occupancy       : "black"   lty = 1 (right axis)
#   Graph 2 -- basic colour palette:
#     Elec_total_plan      : "black"   lty = 1
#     Elec_total_plan_flex : "red"     lty = 1
#     Elec_unit_cost_buy       : "green"  lty = 1 (right)
#     Flex_unit_cost_down_com  : "blue"   lty = 2 (right)
#     Flex_unit_cost_down_exec : "gray40" lty = 3 (right)
# -------------------------------------------------------------
# Inputs
#   Main_df_computed_*.rds files in 01_Input/
#   reward_parameters.csv (for comfort bounds)
# -------------------------------------------------------------
# Outputs
#   <file>_postprocessed.csv / .rds
#   <file>_Graph1_<date>.jpg
#   <file>_Graph2_<date>.jpg
#   <file>_Graph3_data.csv / .rds
#   <file>_Graph3_Eflex_frequency.jpg
#   <file>_Graph4_data.csv / .rds
#   <file>_Graph4_Eflex_scatterplot.jpg
# -------------------------------------------------------------
# Code outline
#   0. Paths and function loading
#   0.1 Load comfort bounds
#   1. Find input RDS files
#   2. Main loop: process each RDS file
#      2.1 Graphs 1 & 2 per calendar day
#      2.2 Graph 3 - E_flex frequency by hour
#      2.3 Graph 4 - Daily E_flex vs Elec_total_plan
# -------------------------------------------------------------
# Usage instructions
#   Run from the repository root:
#     Rscript 20_PostProcess/02_Flexibility_Analysis/PostProcess_flexibility_analysis.R
#   Or source from an interactive R session with the repo root
#   as the working directory.
# -------------------------------------------------------------
# Where this function/script is used
#   Standalone script, run by the user after simulations.
# -------------------------------------------------------------
# functions/scripts called
#   safe_ylim.R, safe_ylim_global.R, plot_and_save.R
#   (from 03_Functions/)
# -------------------------------------------------------------

# ----------------------------------------------------------------
# 0. Paths
# ----------------------------------------------------------------
if (dir.exists("20_PostProcess/02_Flexibility_Analysis")) {
  base_dir <- "20_PostProcess/02_Flexibility_Analysis"
} else if (dir.exists("01_Input")) {
  base_dir <- "."
} else {
  stop("Cannot locate 20_PostProcess/02_Flexibility_Analysis directory. ",
       "Run this script from the repository root or from ",
       "20_PostProcess/02_Flexibility_Analysis/.")
}

input_dir  <- file.path(base_dir, "01_Input")
func_dir   <- file.path(base_dir, "03_Functions")
output_dir <- file.path(base_dir, "90_Output")

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

cat("Input directory: ", input_dir,  "\n")
cat("Output directory:", output_dir, "\n")

# ---- Source functions ----
source(file.path(func_dir, "safe_ylim.R"))
source(file.path(func_dir, "safe_ylim_global.R"))
source(file.path(func_dir, "plot_and_save.R"))

# ----------------------------------------------------------------
# 0.1 Load comfort bounds from reward_parameters
# ----------------------------------------------------------------
reward_params_file <- file.path("01_Simulation", "02_Config", "reward_parameters.csv")
if (file.exists(reward_params_file)) {
  rp_df        <- read.csv(reward_params_file, comment.char = "#", strip.white = TRUE,
                           stringsAsFactors = FALSE)
  confort_low  <- as.numeric(rp_df$value[rp_df$parameter == "confort_low"])
  confort_high <- as.numeric(rp_df$value[rp_df$parameter == "confort_high"])
  if (length(confort_low)  == 0 || is.na(confort_low))  confort_low  <- 21
  if (length(confort_high) == 0 || is.na(confort_high)) confort_high <- 26
  cat("Comfort bounds loaded: confort_low =", confort_low,
      ", confort_high =", confort_high, "\n")
} else {
  confort_low  <- 21
  confort_high <- 26
  cat("reward_parameters.csv not found; using defaults:",
      "confort_low =", confort_low, ", confort_high =", confort_high, "\n")
}
rm(reward_params_file)

# ----------------------------------------------------------------
# 1. Find input RDS files
# ----------------------------------------------------------------
rds_files <- list.files(input_dir,
                        pattern    = "\\.rds$",
                        full.names = TRUE,
                        ignore.case = TRUE)

if (length(rds_files) == 0) {
  stop("No RDS files found in: ", input_dir)
}

cat("Found", length(rds_files), "RDS file(s) to process.\n\n")

# ----------------------------------------------------------------
# 2. Main loop: process each RDS file
# ----------------------------------------------------------------
for (CONT_001 in rds_files) {
  
  file_base <- tools::file_path_sans_ext(basename(CONT_001))
  cat("=== Processing:", file_base, "===\n")
  
  # -- Read data ---------------------------------------------------------------
  df <- readRDS(CONT_001)
  
  if (!inherits(df$time, "POSIXct")) {
    df$time <- as.POSIXct(df$time)
  }
  
  # -- Calculation 1: Flexibilized Energy --------------------------------------
  # E_flex = Elec_total_plan - Elec_total_plan_flex  (keep positive values only)
  E_flex_raw <- df$Elec_total_plan - df$Elec_total_plan_flex
  df$E_flex  <- pmax(E_flex_raw, 0)
  
  n_pos <- sum(df$E_flex > 0, na.rm = TRUE)
  cat("  E_flex: ", n_pos, "positive values out of", nrow(df), "rows.\n")
  
  # -- Save postprocessed dataframe --------------------------------------------
  df_out_base <- file.path(output_dir, paste0(file_base, "_postprocessed"))
  write.csv(df, paste0(df_out_base, ".csv"), row.names = FALSE)
  saveRDS(df,   paste0(df_out_base, ".rds"))
  cat("  Saved postprocessed dataframe.\n")
  
  # -- Derived time columns ----------------------------------------------------
  df$date     <- as.Date(df$time)
  df$hour_num <- as.numeric(format(df$time, "%H")) +
    as.numeric(format(df$time, "%M")) / 60
  df$hour_int <- as.integer(format(df$time, "%H"))
  
  unique_dates <- sort(unique(df$date))
  cat("  Dataset spans", length(unique_dates), "days.\n")
  
  # -- Graph 2 Y2: global price scale (entire series, includes 0) --------------
  # Computed once per file so every daily plot uses the same Y2 axis.
  y2_lim_global <- safe_ylim_global(df$Elec_unit_cost_buy,
                                    df$Flex_unit_cost_down_com,
                                    df$Flex_unit_cost_down_exec)
  cat("  Graph 2 Y2 global range: [",
      round(y2_lim_global[1], 4), ",", round(y2_lim_global[2], 4), "]\n")
  
  # ============================================================
  # Graphs 1 & 2 -- per calendar day
  # ============================================================
  cat("  Generating per-day plots")
  
  for (CONT_002 in seq_along(unique_dates)) {
    
    d_date  <- unique_dates[CONT_002]
    day_str <- format(d_date, "%Y-%m-%d")
    df_day  <- df[df$date == d_date, ]
    x       <- df_day$hour_num
    
    # Progress indicator every 30 days
    if (CONT_002 %% 30 == 1) cat(".")
    
    # ----------------------------------------------------------
    # Graph 1: Temperature (Y1) + Occupancy (Y2)
    # Colour palette: blue tones; all axis text in black.
    # ----------------------------------------------------------
    draw_g1 <- local({
      x_            <- x
      df_day_       <- df_day
      day_str_      <- day_str
      confort_low_  <- confort_low
      confort_high_ <- confort_high
      function() {
        y1_lim <- c(0, 40)
        # Binary (0/1) occupancy: add padding below and above for visual clarity
        y2_lim <- c(-0.15, 1.4)
        
        old_par <- par(mar = c(5, 4, 4, 5) + 0.1)
        on.exit(par(old_par), add = TRUE)
        
        # Left axis: temperatures -- basic colour palette
        plot(x_,
             df_day_$Text,
             type = "l",
             col = "black",
             lwd = 2,
             xlim = c(0, 24),
             xaxt = "n",
             ylim = y1_lim,
             xlab = "Hour of Day",
             ylab = "Temperature (\u00b0C)",
             col.lab  = "black",
             col.axis = "black",
             main = paste("Temperature and Occupancy -", day_str_)
             )
        axis(1, at = seq(0, 24, by = 2), col.axis = "black")
        lines(x_, df_day_$Ti_plan,      col = "red",   lwd = 2)
        lines(x_, df_day_$Ti_plan_flex, col = "green", lwd = 2, lty = 2)
        # Comfort bound lines
        abline(h = confort_low_,  lty = 3, col = "blue", lwd = 1.5)
        abline(h = confort_high_, lty = 3, col = "blue", lwd = 1.5)
        legend("topleft",
               bty = "n",
               legend = c("Text", "Ti_plan", "Ti_plan_flex",
                          "Comfort bounds"),
               col    = c("black", "red", "green", "blue"),
               lwd    = c(2, 2, 2, 1.5),
               lty    = c(1, 1, 2, 3)
               )
        
        # Right axis: Occupancy -- black; axis text in black
        par(new = TRUE)
        plot(x_,
             df_day_$Occupancy,
             type = "s",
             col = "black",
             lwd = 1,
             lty = 1,
             axes = FALSE,
             xlab = "",
             ylab = "",
             xlim = c(0, 24),
             ylim = y2_lim
             )
        axis(4, at = c(0, 1), labels = c("0", "1"),
             col.axis = "black")
        mtext("Occupancy", side = 4, line = 3, col = "black")
        legend("topright",
               bty = "n",
               legend = "Occupancy",
               col = "black",
               lwd = 1,
               lty = 1
               )
      }
    })
    
    jpg1 <- file.path(output_dir,
                      sprintf("%s_Graph1_%s.jpg", file_base, day_str))
    plot_and_save(draw_g1, jpg1)
    
    # ----------------------------------------------------------
    # Graph 2: Electrical energy (Y1) + Prices (Y2)
    # Colour palette: blue tones; Y2 uses global scale (full series,
    # includes 0); all axis text in black.
    # ----------------------------------------------------------
    draw_g2 <- local({
      x_       <- x
      df_day_  <- df_day
      day_str_ <- day_str
      y2_lim_  <- y2_lim_global   # fixed global scale for prices axis
      function() {
        y1_lim <- safe_ylim(df_day_$Elec_total_plan,
                            df_day_$Elec_total_plan_flex)
        
        old_par <- par(mar = c(5, 4, 4, 6) + 0.1)
        on.exit(par(old_par), add = TRUE)
        
        # Left axis: energy -- basic colour palette
        plot(x_,
             df_day_$Elec_total_plan,
             type = "l",
             col = "black",
             lwd = 2,
             xlim = c(0, 24),
             xaxt = "n",
             ylim = y1_lim,
             xlab = "Hour of Day",
             ylab = "Electrical Energy (kW)",
             col.lab  = "black",
             col.axis = "black",
             main = paste("Energy and Prices -", day_str_)
             )
        axis(1, at = seq(0, 24, by = 2), col.axis = "black")
        lines(x_, df_day_$Elec_total_plan_flex,
              col = "red", lwd = 2, lty = 1)
        legend("topleft",
               bty = "n",
               legend = c("Elec_total_plan", "Elec_total_plan_flex"),
               col    = c("black", "red"),
               lwd    = 2,
               lty    = c(1, 1)
               )
        
        # Right axis: prices -- basic colour palette;
        # global Y2 scale
        par(new = TRUE)
        plot(x_,
             df_day_$Elec_unit_cost_buy,
             type = "l",
             col = "green",
             lwd = 2,
             axes = FALSE,
             xlab = "",
             ylab = "",
             xlim = c(0, 24),
             ylim = y2_lim_
             )
        lines(x_, df_day_$Flex_unit_cost_down_com,
              col = "blue", lwd = 2, lty = 2)
        lines(x_, df_day_$Flex_unit_cost_down_exec,
              col = "gray40", lwd = 2, lty = 3)
        # All axis text and label in black
        axis(4, col.axis = "black")
        # line = 4 (vs. 3 in Graph 1) because numeric
        # price tick labels are wider and need extra
        # space between the axis and the label.
        mtext("Price (EUR/MWh)", side = 4, line = 4,
              col = "black")
        legend("topright",
               bty = "n",
               legend = c("Elec_unit_cost_buy",
                          "Flex_unit_cost_down_com",
                          "Flex_unit_cost_down_exec"),
               col    = c("green", "blue", "gray40"),
               lwd    = 2,
               lty    = c(1, 2, 3)
               )
      }
    })
    
    jpg2 <- file.path(output_dir,
                      sprintf("%s_Graph2_%s.jpg", file_base, day_str))
    plot_and_save(draw_g2, jpg2)
  }
  
  cat(" done (", 2 * length(unique_dates), "plots).\n", sep = "")
  
  # ============================================================
  # Graph 3 -- E_flex frequency by hour of day (overall)
  # ============================================================
  
  # For each integer hour (0-23): fraction of timesteps where E_flex > 0
  freq_by_hour <- tapply(df$E_flex > 0, df$hour_int, mean, na.rm = TRUE)
  all_hours    <- 0:23
  freq_vals    <- as.numeric(freq_by_hour[as.character(all_hours)])
  freq_vals[is.na(freq_vals)] <- 0
  
  graph3_data <- data.frame(hour                  = all_hours,
                            fraction_Eflex_positive = freq_vals)
  
  # Save Graph 3 data
  g3_base <- file.path(output_dir, paste0(file_base, "_Graph3_data"))
  write.csv(graph3_data, paste0(g3_base, ".csv"), row.names = FALSE)
  saveRDS(graph3_data,   paste0(g3_base, ".rds"))
  
  draw_g3 <- local({
    graph3_data_ <- graph3_data
    file_base_   <- file_base
    function() {
      old_par <- par(mar = c(5, 4, 4, 2) + 0.1)
      on.exit(par(old_par), add = TRUE)
      bp <- barplot(graph3_data_$fraction_Eflex_positive,
                    names.arg = graph3_data_$hour,
                    col       = "black",
                    border    = "white",
                    ylim      = c(0, 1),
                    xlab      = "Hour of Day",
                    ylab      = "Fraction of Observations (E_flex > 0)",
                    main      = paste("E_flex Frequency by Hour of Day -",
                                      file_base_)
                    )
      abline(h = seq(0.2, 1, by = 0.2), lty = 2, col = "gray70")
    }
  })
  
  jpg3 <- file.path(output_dir,
                    paste0(file_base, "_Graph3_Eflex_frequency.jpg"))
  plot_and_save(draw_g3, jpg3)
  cat("  Generated Graph 3 (E_flex frequency by hour).\n")
  
  # ============================================================
  # Graph 4 -- Scatterplot: daily Elec_total_plan vs daily E_flex
  # ============================================================
  
  daily_agg <- aggregate(cbind(Elec_total_plan, E_flex) ~ date,
                         data = df, FUN = sum, na.rm = TRUE)
  names(daily_agg) <- c("date", "Daily_Elec_total_plan", "Daily_E_flex")
  
  # Save Graph 4 data
  g4_base <- file.path(output_dir, paste0(file_base, "_Graph4_data"))
  write.csv(daily_agg, paste0(g4_base, ".csv"), row.names = FALSE)
  saveRDS(daily_agg,   paste0(g4_base, ".rds"))
  
  draw_g4 <- local({
    daily_agg_ <- daily_agg
    file_base_ <- file_base
    function() {
      old_par <- par(mar = c(5, 4, 4, 2) + 0.1)
      on.exit(par(old_par), add = TRUE)
      plot(daily_agg_$Daily_Elec_total_plan,
           daily_agg_$Daily_E_flex,
           pch  = 19,
           col  = "black",
           xlab = "Daily Elec_total_plan (kWh)",
           ylab = "Daily E_flex (kWh)",
           main = paste("Daily E_flex vs. Daily Elec_total_plan -",
                        file_base_)
           )
      # Add linear trend if there is variance in X
      if (var(daily_agg_$Daily_Elec_total_plan, na.rm = TRUE) > 0) {
        fit <- lm(Daily_E_flex ~ Daily_Elec_total_plan, data = daily_agg_)
        abline(fit, col = "red", lty = 2, lwd = 2)
        legend("topleft", bty = "n",
               legend = "Linear trend", col = "red", lty = 2, lwd = 2)
      }
    }
  })
  
  jpg4 <- file.path(output_dir,
                    paste0(file_base, "_Graph4_Eflex_scatterplot.jpg"))
  plot_and_save(draw_g4, jpg4)
  cat("  Generated Graph 4 (daily E_flex vs Elec_total_plan).\n")
  
  cat("=== Completed:", file_base, "===\n\n")
}

cat("All files processed successfully.\n")
cat("Outputs saved to:", output_dir, "\n")