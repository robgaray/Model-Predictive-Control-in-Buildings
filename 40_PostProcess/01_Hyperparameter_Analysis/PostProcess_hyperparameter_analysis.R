# -------------------------------------------------------------
# Script: PostProcess_hyperparameter_analysis.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This script post-processes the Sinthetized_df_computed_...
# output files produced by parametric supercomputer runs
# (Main_SCC.R).
# It reads all Sinthetized_df_computed_* files from 01_Input,
# supporting both RDS and CSV formats. When both formats exist
# for the same configuration, the RDS file is preferred.
# It overrides each row's parameter columns with the values
# encoded in the filename suffix, merges all rows into a single
# global dataframe, and then performs an iterative
# hyperparameter sensitivity analysis.
#
# Interactive workflow:
#   Step 1  - Parameter selection: for each varying parameter,
#             the user decides whether to include it in the
#             sensitivity analysis. For excluded parameters,
#             the user is shown min/max/mean and asked to define
#             a range; only rows within that range are used.
#   Step 2  - Boxplot settings: the user defines five percentile
#             thresholds (lower whisker, lower box, upper box,
#             upper whisker) and selects mean or median as the
#             central statistic. The user also chooses whether
#             to show outliers. These settings are asked once
#             and reused for all plots.
#   Step 3  - Iterative analysis (up to 3 passes, or until
#             fewer than 10 configurations remain):
#             Before each pass (from pass 2), the user may
#             choose to redefine the parameter selection and
#             the ranges for excluded parameters.
#     3.1   Reward boxplots (X: selected parameters; Y: reward);
#           filters configurations where reward > 75th percentile.
#     3.2   Process-time boxplots (same X variables;
#           Y: process_time); filters where process_time < 50th
#           percentile.
#     3.3   Frequency bar charts for individual and combined
#           hyperparameter groups.
#
# All plots use Y-axis limits fixed to the 0 value and the
# global min/max values of the full original dataset, so that
# plots across iterations are directly comparable.
# All boxplot X axes show all parameter values present in the
# original dataset to maintain a consistent scale.
# Plots are rendered in black and white using base R graphics.
# -------------------------------------------------------------
# Inputs
#   Sinthetized_df_computed_*.rds / *.csv files in 01_Input/
#   Each filename encodes 17 parameters as a numeric suffix.
#   User interactive responses for parameter selection,
#   range definition, and boxplot settings.
# -------------------------------------------------------------
# Outputs
#   global_df.csv / global_df.rds
#   selected_configurations.csv / .rds
#   reward_vs_<var>_iter<N>.jpg
#   process_time_vs_<var>_iter<N>.jpg
#   freq_<group>_iter<N>.jpg
# -------------------------------------------------------------
# Code outline
#   0. Paths and helper function sources
#   1. Read and merge all Sinthetized_df_computed files
#      Progress is printed to console after each file is read.
#   2. Save global dataframe
#   2b. Define local helper: ask_param_selection()
#       Exact match used when r_min == r_max for excluded params.
#   2c. Identify varying parameters
#   2d. Initial parameter selection (ask Y/N + ranges)
#   2e. Ask boxplot threshold settings (once)
#   2f. Ask whether to use adaptive Y axis for boxplots
#   2g. Compute global axis limits from full dataset
#   3. Iterative hyperparameter sensitivity analysis
#      3.0 (iter > 1) Offer to redefine parameter selection
#      3.1 Reward boxplots + filter (> P75)
#          X axis adapts to current data (no empty groups).
#          Y axis adaptive per iteration if adaptive_y_ is TRUE.
#      3.2 Process-time boxplots + filter (< P50)
#          X axis adapts to current data (no empty groups).
#          Y axis adaptive per iteration if adaptive_y_ is TRUE.
#      3.3 Frequency bar charts
#          Y axis computed from current data per chart.
#   4. Save selected configurations
# -------------------------------------------------------------
# Usage instructions
#   Run from the repository root:
#     Rscript 40_PostProcess/01_Hyperparameter_Analysis/
#             PostProcess_hyperparameter_analysis.R
#   Or source from an interactive R session with the repo root
#   as the working directory.
# -------------------------------------------------------------
# Where this function/script is used
#   Standalone script, run by the user after parametric SCC
#   simulations are complete.
# -------------------------------------------------------------
# functions/scripts called
#   plot_and_save.R            (from 03_Functions/)
#   compute_boxplot_stats.R    (from 03_Functions/)
#   load_hyperparameter_data.R (from 03_Functions/)
# -------------------------------------------------------------

# -------------------------------------------------------------
# 0. Paths and helper function sources
# Path resolution: works both from repo root and from the
# script's own directory.
# -------------------------------------------------------------
{
  if (dir.exists("40_PostProcess/01_Hyperparameter_Analysis")) {
    base_dir <- "40_PostProcess/01_Hyperparameter_Analysis"
  } else if (dir.exists("01_Input")) {
    base_dir <- "."
  } else {
    stop(
      "Cannot locate 40_PostProcess/01_Hyperparameter_Analysis. ",
      "Run this script from the repository root or from ",
      "40_PostProcess/01_Hyperparameter_Analysis/."
    )
  }

  input_dir  <- file.path(base_dir, "01_Input")
  func_dir   <- file.path(base_dir, "03_Functions")
  output_dir <- file.path(base_dir, "90_Output")

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  cat("Input directory: ", input_dir,  "\n")
  cat("Output directory:", output_dir, "\n")

  source(file.path(func_dir, "plot_and_save.R"))
  source(file.path(func_dir, "compute_boxplot_stats.R"))
  source(file.path(func_dir, "load_hyperparameter_data.R"))
}

# All candidate parameters for the sensitivity analysis
all_candidate_vars <- c(
  "population_size",
  "iteration_number",
  "run_number",
  "pcrossover",
  "pmutation",
  "control_optimization_horizon",
  "control_implementation_horizon",
  "control_optimization_anticipation",
  "control_type",
  "optimization_aim",
  "flexibility_event_length_max",
  "flexibility_recover_timespan",
  "thermal_stabilization_timespan",
  "minimum_flexibility",
  "flexibility_splits",
  "Alpha_Service_Min",
  "month_subset"
)

# -------------------------------------------------------------
# 1. Read and merge all Sinthetized_df_computed files
#    Uses load_hyperparameter_data() from 03_Functions.
#    Progress is printed to console after each file is read.
# -------------------------------------------------------------
{
  progress_fn_ <- function(current, total, elapsed_sec) {
    rate_      <- if (elapsed_sec > 0) current / elapsed_sec else NA_real_
    remaining_ <- if (!is.na(rate_) && rate_ > 0 && current < total) {
      (total - current) / rate_
    } else {
      NA_real_
    }
    cat(sprintf(
      "  Loading: %d / %d files. Elapsed: %.1f s.%s\n",
      current, total, elapsed_sec,
      if (!is.na(remaining_)) {
        sprintf(" Est. remaining: %.1f s.", remaining_)
      } else {
        ""
      }))
  }
  global_df <- load_hyperparameter_data(input_dir, progress_fn = progress_fn_)
  rm(progress_fn_)

  cat("Global dataframe:", nrow(global_df), "rows,",
      ncol(global_df), "columns.\n")
  cat("Columns:", paste(names(global_df), collapse = ", "), "\n")
}

# -------------------------------------------------------------
# 2. Save global dataframe (before any filtering)
# -------------------------------------------------------------
{
  write.csv(global_df,
            file.path(output_dir, "global_df.csv"),
            row.names = FALSE)
  saveRDS(global_df,
          file.path(output_dir, "global_df.rds"))
  cat("Global dataframe saved to", output_dir, "\n")
}

# -------------------------------------------------------------
# 2b. Define local helper: ask_param_selection()
# Asks the user which varying parameters to include in the
# sensitivity analysis. For excluded parameters, shows the
# min, max and mean values in input_df, then asks the user for
# a min-max range; only rows within that range are kept.
# Can be called repeatedly (once initially, then optionally
# at the start of each iteration).
# Returns a list with:
#   expl_vars   : character vector of selected parameters
#   filtered_df : input_df filtered by non-selected ranges
# -------------------------------------------------------------
{
  ask_param_selection <- function(input_df, candidate_vars) {

    varying_here <- character(0)
    for (v_ in candidate_vars) {
      if (v_ %in% names(input_df) &&
          length(unique(input_df[[v_]])) > 1) {
        varying_here <- c(varying_here, v_)
      }
    }

    if (length(varying_here) == 0) {
      cat("No varying parameters found in current dataset.\n")
      return(list(expl_vars   = character(0),
                  filtered_df = input_df))
    }

    cat("\nThe following parameters vary in the current dataset.\n")
    cat("Select which ones to include in the analysis (Y/N):\n\n")

    selected_vars <- character(0)
    filtered_df   <- input_df

    for (v_ in varying_here) {
      unique_vals_ <- sort(unique(input_df[[v_]]))
      cat(sprintf("  %s [%d unique values: %s]\n",
                  v_,
                  length(unique_vals_),
                  paste(head(unique_vals_, 5), collapse = ", ")))

      repeat {
        response_ <- readline(
          prompt = sprintf("  Include '%s'? (Y/N): ", v_))
        response_ <- toupper(trimws(response_))
        if (response_ %in% c("Y", "N")) break
        cat("  Please enter Y or N.\n")
      }

      if (response_ == "Y") {
        selected_vars <- c(selected_vars, v_)
      } else {

        v_min_  <- min(input_df[[v_]],  na.rm = TRUE)
        v_max_  <- max(input_df[[v_]],  na.rm = TRUE)
        v_mean_ <- mean(input_df[[v_]], na.rm = TRUE)
        cat(sprintf(
          "  '%s' stats: min = %.4g, max = %.4g, mean = %.4g\n",
          v_, v_min_, v_max_, v_mean_))

        r_min_ <- NA_real_
        repeat {
          s_ <- readline(prompt = sprintf(
            "  Range min for '%s' (Enter for %.4g): ",
            v_, v_min_))
          s_ <- trimws(s_)
          r_min_ <- if (nzchar(s_)) {
            suppressWarnings(as.numeric(s_))
          } else {
            v_min_
          }
          if (!is.na(r_min_)) break
          cat("  Please enter a valid number.\n")
        }

        r_max_ <- NA_real_
        repeat {
          s_ <- readline(prompt = sprintf(
            "  Range max for '%s' (Enter for %.4g): ",
            v_, v_max_))
          s_ <- trimws(s_)
          r_max_ <- if (nzchar(s_)) {
            suppressWarnings(as.numeric(s_))
          } else {
            v_max_
          }
          if (!is.na(r_max_) && r_max_ >= r_min_) break
          cat("  Please enter a valid number >= min.\n")
        }

        before_n_ <- nrow(filtered_df)
        if (r_min_ == r_max_) {
          filtered_df <- filtered_df[
            !is.na(filtered_df[[v_]]) &
              filtered_df[[v_]] == r_min_, ]
          cat(sprintf(
            "  Filtered to [= %.4g]: %d -> %d rows.\n",
            r_min_, before_n_, nrow(filtered_df)))
        } else {
          filtered_df <- filtered_df[
            !is.na(filtered_df[[v_]]) &
              filtered_df[[v_]] >= r_min_ &
              filtered_df[[v_]] <= r_max_, ]
          cat(sprintf(
            "  Filtered to [%.4g, %.4g]: %d -> %d rows.\n",
            r_min_, r_max_, before_n_, nrow(filtered_df)))
        }

        rm(v_min_, v_max_, v_mean_, r_min_, r_max_,
           before_n_, s_)
      }

      rm(unique_vals_, response_, v_)
    }
    rm(varying_here)

    if (length(selected_vars) == 0) {
      cat("No parameters selected. Keeping all varying parameters.\n")
      selected_vars <- candidate_vars[
        candidate_vars %in% names(input_df) &
          vapply(candidate_vars,
                 function(v) length(unique(input_df[[v]])) > 1,
                 logical(1))]
      if (length(selected_vars) == 0) selected_vars <- candidate_vars[1]
    }

    cat("\nSelected parameters: ",
        paste(selected_vars, collapse = ", "), "\n")
    cat("Rows after parameter range filtering:",
        nrow(filtered_df), "\n\n")

    list(expl_vars   = selected_vars,
         filtered_df = filtered_df)
  }
}

# -------------------------------------------------------------
# 2c. Identify parameters that vary in the global dataset
# -------------------------------------------------------------
{
  varying_vars <- character(0)
  for (CONT_001 in all_candidate_vars) {
    if (CONT_001 %in% names(global_df) &&
        length(unique(global_df[[CONT_001]])) > 1) {
      varying_vars <- c(varying_vars, CONT_001)
    }
  }
  rm(CONT_001)

  cat("\nParameters that vary across configurations:\n")
  cat("  ", paste(varying_vars, collapse = ", "), "\n")
}

# -------------------------------------------------------------
# 2d. Initial parameter selection
# User selects which parameters to include and defines ranges
# for excluded parameters to filter the working dataset.
# -------------------------------------------------------------
{
  cat("\n--- Initial Parameter Selection ---\n")
  selection_result <- ask_param_selection(global_df, varying_vars)
  expl_vars        <- selection_result$expl_vars
  current_df       <- selection_result$filtered_df
  rm(selection_result)
}

# -------------------------------------------------------------
# 2e. Ask boxplot threshold settings (asked once for all plots)
# The user defines five percentile thresholds and chooses
# mean/median as the central statistic and whether to show
# outliers. All plots in all iterations use these settings.
# -------------------------------------------------------------
{
  cat("\n--- Boxplot Settings (asked once for all plots) ---\n")

  ask_pct_ <- function(label_, default_) {
    repeat {
      s_ <- readline(prompt = sprintf(
        "  %s (0-100, Enter for %g): ", label_, default_))
      s_ <- trimws(s_)
      v_ <- if (nzchar(s_)) suppressWarnings(as.numeric(s_)) else default_
      if (!is.na(v_) && v_ >= 0 && v_ <= 100) return(v_)
      cat("  Please enter a number between 0 and 100.\n")
    }
  }

  bxp_lower_pct_     <- ask_pct_("Lower whisker percentile", 5)
  bxp_lower_box_pct_ <- ask_pct_("Lower box edge percentile", 25)

  repeat {
    s_ <- readline(
      "  Center statistic (mean/median, Enter for median): ")
    s_ <- tolower(trimws(s_))
    if (s_ == "" || s_ == "median") {
      bxp_center_type_ <- "median"
      break
    }
    if (s_ == "mean") {
      bxp_center_type_ <- "mean"
      break
    }
    cat("  Please enter 'mean' or 'median'.\n")
  }

  bxp_upper_box_pct_ <- ask_pct_("Upper box edge percentile", 75)
  bxp_upper_pct_     <- ask_pct_("Upper whisker percentile", 95)

  repeat {
    s_ <- readline("  Show outliers? (Y/N, Enter for Y): ")
    s_ <- toupper(trimws(s_))
    if (s_ == "" || s_ == "Y") {
      bxp_show_outliers_ <- TRUE
      break
    }
    if (s_ == "N") {
      bxp_show_outliers_ <- FALSE
      break
    }
    cat("  Please enter Y or N.\n")
  }
  rm(s_)

  bxp_params <- list(
    lower_pct      = bxp_lower_pct_,
    lower_box_pct  = bxp_lower_box_pct_,
    center_type    = bxp_center_type_,
    upper_box_pct  = bxp_upper_box_pct_,
    upper_pct      = bxp_upper_pct_,
    show_outliers  = bxp_show_outliers_
  )
  rm(bxp_lower_pct_, bxp_lower_box_pct_, bxp_center_type_,
     bxp_upper_box_pct_, bxp_upper_pct_, bxp_show_outliers_,
     ask_pct_)

  cat(sprintf(
    "\nBoxplot: whiskers=[%g%%, %g%%], box=[%g%%, %g%%],",
    bxp_params$lower_pct,     bxp_params$upper_pct,
    bxp_params$lower_box_pct, bxp_params$upper_box_pct))
  cat(sprintf(" center=%s, outliers=%s\n",
              bxp_params$center_type,
              if (bxp_params$show_outliers) "yes" else "no"))
}

# -------------------------------------------------------------
# 2f. Ask whether to use adaptive Y axis for boxplots
# When adaptive, each iteration scales the Y axis to the data
# range of the current subset (still including 0). When not
# adaptive, all iterations use the global dataset Y limits for
# direct comparability.
# -------------------------------------------------------------
{
  cat("\n--- Boxplot Y Axis Scaling ---\n")
  repeat {
    s_ <- readline(
      "  Adaptive Y axis per iteration? (Y/N, Enter for N): ")
    s_ <- toupper(trimws(s_))
    if (s_ == "" || s_ == "N") {
      adaptive_y_ <- FALSE
      break
    }
    if (s_ == "Y") {
      adaptive_y_ <- TRUE
      break
    }
    cat("  Please enter Y or N.\n")
  }
  rm(s_)
  cat(sprintf("  Adaptive Y axis: %s\n",
              if (adaptive_y_) "yes" else "no"))
}

# -------------------------------------------------------------
# 2g. Compute global axis limits from the full original dataset
# These limits are applied to all plots so that axes are
# consistent across iterations and subsets of the data.
# Both Y axes include 0 and the global data min/max.
# Global groups per variable define the X axis groups for all
# boxplots, ensuring a consistent X scale across iterations.
# -------------------------------------------------------------
{
  rew_ymin_       <- min(c(0, global_df$reward), na.rm = TRUE)
  rew_ymax_       <- max(global_df$reward,        na.rm = TRUE)
  global_rew_ylim <- c(rew_ymin_ * ifelse(rew_ymin_ < 0, 1.15, 1),
                       rew_ymax_ * ifelse(rew_ymax_ > 0, 1.15, 1))
  rm(rew_ymin_, rew_ymax_)

  pt_ymin_        <- min(c(0, global_df$process_time), na.rm = TRUE)
  pt_ymax_        <- max(global_df$process_time,        na.rm = TRUE)
  global_pt_ylim  <- c(pt_ymin_ * ifelse(pt_ymin_ < 0, 1.15, 1),
                       pt_ymax_ * ifelse(pt_ymax_ > 0, 1.15, 1))
  rm(pt_ymin_, pt_ymax_)

  global_groups <- list()
  for (CONT_001 in all_candidate_vars) {
    if (CONT_001 %in% names(global_df)) {
      global_groups[[CONT_001]] <- sort(unique(global_df[[CONT_001]]))
    }
  }
  rm(CONT_001)
}

# -------------------------------------------------------------
# 3. Iterative hyperparameter sensitivity analysis
# Up to 3 passes, stopping early if fewer than 10
# configurations remain. Before each pass after the first,
# the user may choose to redefine which parameters are analysed
# and the ranges for non-selected parameters.
# -------------------------------------------------------------

n_iter_max <- 3

for (CONT_002 in seq_len(n_iter_max)) {

  cat("\n=== Iteration", CONT_002, "===\n")
  cat("Configurations:", nrow(current_df), "\n")

  if (CONT_002 > 1 && nrow(current_df) < 10) {
    cat("Fewer than 10 configurations remain. Stopping.\n")
    break
  }

  # ------------------------------------------------------------
  # 3.0. (iterations > 1) Offer to redefine parameter selection
  # If the user chooses yes, ask_param_selection() is called
  # again on the current (already filtered) dataset.
  # ------------------------------------------------------------
  if (CONT_002 > 1) {

    repeat {
      s_redef_ <- readline(prompt = sprintf(
        "  Different parameter selection for iteration %d? (Y/N): ",
        CONT_002))
      s_redef_ <- toupper(trimws(s_redef_))
      if (s_redef_ %in% c("Y", "N")) break
      cat("  Please enter Y or N.\n")
    }

    if (s_redef_ == "Y") {
      cat("\n--- Parameter Selection for Iteration",
          CONT_002, "---\n")
      redef_result_ <- ask_param_selection(current_df, varying_vars)
      expl_vars     <- redef_result_$expl_vars
      current_df    <- redef_result_$filtered_df
      rm(redef_result_)
    }
    rm(s_redef_)
  }

  # Build frequency groups from current expl_vars.
  # Individual groups for each selected variable, plus combined
  # groups for all pairs and triples (up to 3 variables).
  freq_groups <- list()

  for (CONT_003 in expl_vars) {
    freq_groups[[CONT_003]] <- CONT_003
  }
  rm(CONT_003)

  if (length(expl_vars) >= 2) {
    for (CONT_004 in 1:(length(expl_vars) - 1)) {
      for (CONT_005 in (CONT_004 + 1):length(expl_vars)) {
        combo_name_ <- paste(expl_vars[CONT_004],
                             expl_vars[CONT_005],
                             sep = "_x_")
        freq_groups[[combo_name_]] <- c(expl_vars[CONT_004],
                                        expl_vars[CONT_005])
      }
    }
    rm(CONT_004, CONT_005, combo_name_)
  }

  if (length(expl_vars) >= 3) {
    for (CONT_004 in 1:(length(expl_vars) - 2)) {
      for (CONT_005 in (CONT_004 + 1):(length(expl_vars) - 1)) {
        for (CONT_006 in (CONT_005 + 1):length(expl_vars)) {
          combo_name_ <- paste(expl_vars[CONT_004],
                               expl_vars[CONT_005],
                               expl_vars[CONT_006],
                               sep = "_x_")
          freq_groups[[combo_name_]] <- c(expl_vars[CONT_004],
                                          expl_vars[CONT_005],
                                          expl_vars[CONT_006])
        }
      }
    }
    rm(CONT_004, CONT_005, CONT_006, combo_name_)
  }

  # ------------------------------------------------------------------
  # 3.1. Reward boxplots + filter (reward > P75)
  # For each selected parameter (X axis groups), reward values
  # are grouped by unique parameter value and drawn as a boxplot
  # using the user-defined percentile thresholds. The X axis shows
  # only values present in the current subset. The Y axis is either
  # global (for comparability) or adaptive to the current subset.
  # After plotting, configurations with reward <= P75 are removed.
  # ------------------------------------------------------------------
  reward_p75 <- quantile(current_df$reward, 0.75, na.rm = TRUE)
  cat("Reward P75:", reward_p75, "\n")

  for (CONT_003 in expl_vars) {

    groups_    <- sort(unique(current_df[[CONT_003]]))
    n_grp_     <- length(groups_)
    stats_mat_ <- matrix(NA_real_, nrow = 5, ncol = n_grp_)
    n_vec_     <- integer(n_grp_)
    out_vals_  <- numeric(0)
    out_grps_  <- integer(0)

    for (CONT_007 in seq_len(n_grp_)) {
      g_   <- groups_[CONT_007]
      y_g_ <- current_df$reward[
        !is.na(current_df[[CONT_003]]) &
          current_df[[CONT_003]] == g_]
      s_   <- compute_boxplot_stats(
        y_vals        = y_g_,
        lower_pct     = bxp_params$lower_pct,
        lower_box_pct = bxp_params$lower_box_pct,
        center_type   = bxp_params$center_type,
        upper_box_pct = bxp_params$upper_box_pct,
        upper_pct     = bxp_params$upper_pct)
      stats_mat_[, CONT_007] <- s_$stats
      n_vec_[CONT_007]        <- s_$n
      if (bxp_params$show_outliers && length(s_$out) > 0) {
        out_vals_ <- c(out_vals_, s_$out)
        out_grps_ <- c(out_grps_, rep(CONT_007, length(s_$out)))
      }
      rm(g_, y_g_, s_)
    }
    rm(CONT_007)

    bxp_data_ <- list(
      stats = stats_mat_,
      n     = n_vec_,
      out   = out_vals_,
      group = out_grps_,
      names = as.character(groups_)
    )

    ttl_   <- paste0("Hyperparameter sensitivity analysis (",
                     CONT_003, "). Iteration ", CONT_002, ".")
    rp75_  <- reward_p75
    if (adaptive_y_) {
      rew_iter_ymin_ <- min(c(0, current_df$reward), na.rm = TRUE)
      rew_iter_ymax_ <- max(current_df$reward,        na.rm = TRUE)
      yl_ <- c(rew_iter_ymin_ * ifelse(rew_iter_ymin_ < 0, 1.15, 1),
               rew_iter_ymax_ * ifelse(rew_iter_ymax_ > 0, 1.15, 1))
      rm(rew_iter_ymin_, rew_iter_ymax_)
    } else {
      yl_    <- global_rew_ylim
    }
    fpath_ <- file.path(
      output_dir,
      paste0("reward_vs_", CONT_003, "_iter", CONT_002, ".jpg"))

    draw_reward_ <- local({
      bd_        <- bxp_data_
      yl__       <- yl_
      ttl__      <- ttl_
      xvar__     <- CONT_003
      rp75__     <- rp75_
      show_out__ <- bxp_params$show_outliers
      function() {
        bxp(bd_,
            ylim     = yl__,
            xlab     = xvar__,
            ylab     = "reward",
            main     = ttl__,
            outline  = show_out__,
            col      = "white",
            border   = "black",
            las      = 2,
            cex.axis = 0.9,
            cex.lab  = 1.1,
            cex.main = 1.1
            )
        abline(h = 0,      lty = 3, col = "grey60")
        abline(h = rp75__, lty = 2, col = "black")
        legend("topright",
               legend = paste0("P75 = ", round(rp75__, 3)),
               lty    = 2,
               bty    = "n",
               cex    = 0.9)
      }
    })

    plot_and_save(draw_reward_, fpath_)
    cat("Saved:", basename(fpath_), "\n")

    rm(groups_, n_grp_, stats_mat_, n_vec_, out_vals_, out_grps_,
       bxp_data_, ttl_, rp75_, yl_, fpath_, draw_reward_)
  }
  rm(CONT_003)

  current_df <- current_df[
    !is.na(current_df$reward) &
      current_df$reward > reward_p75, ]
  cat("After reward filter (> P75):", nrow(current_df),
      "configurations remain.\n")
  rm(reward_p75)

  if (nrow(current_df) < 10) {
    cat("Fewer than 10 configurations after reward filter.",
        "Stopping.\n")
    break
  }

  # ------------------------------------------------------------------
  # 3.2. Process-time boxplots + filter (process_time < P50)
  # Same approach as 3.1 but for process_time. The X axis shows only
  # values present in the current subset. The Y axis is either global
  # or adaptive. After plotting, configs >= P50 are removed.
  # ------------------------------------------------------------------
  process_p50 <- quantile(current_df$process_time, 0.50,
                           na.rm = TRUE)
  cat("Process time P50:", process_p50, "\n")

  for (CONT_003 in expl_vars) {

    groups_    <- sort(unique(current_df[[CONT_003]]))
    n_grp_     <- length(groups_)
    stats_mat_ <- matrix(NA_real_, nrow = 5, ncol = n_grp_)
    n_vec_     <- integer(n_grp_)
    out_vals_  <- numeric(0)
    out_grps_  <- integer(0)

    for (CONT_007 in seq_len(n_grp_)) {
      g_   <- groups_[CONT_007]
      y_g_ <- current_df$process_time[
        !is.na(current_df[[CONT_003]]) &
          current_df[[CONT_003]] == g_]
      s_   <- compute_boxplot_stats(
        y_vals        = y_g_,
        lower_pct     = bxp_params$lower_pct,
        lower_box_pct = bxp_params$lower_box_pct,
        center_type   = bxp_params$center_type,
        upper_box_pct = bxp_params$upper_box_pct,
        upper_pct     = bxp_params$upper_pct)
      stats_mat_[, CONT_007] <- s_$stats
      n_vec_[CONT_007]        <- s_$n
      if (bxp_params$show_outliers && length(s_$out) > 0) {
        out_vals_ <- c(out_vals_, s_$out)
        out_grps_ <- c(out_grps_, rep(CONT_007, length(s_$out)))
      }
      rm(g_, y_g_, s_)
    }
    rm(CONT_007)

    bxp_data_ <- list(
      stats = stats_mat_,
      n     = n_vec_,
      out   = out_vals_,
      group = out_grps_,
      names = as.character(groups_)
    )

    ttl_   <- paste0("Hyperparameter sensitivity analysis (",
                     CONT_003, "). Iteration ", CONT_002, ".")
    pp50_  <- process_p50
    if (adaptive_y_) {
      pt_iter_ymin_ <- min(c(0, current_df$process_time), na.rm = TRUE)
      pt_iter_ymax_ <- max(current_df$process_time,        na.rm = TRUE)
      yl_ <- c(pt_iter_ymin_ * ifelse(pt_iter_ymin_ < 0, 1.15, 1),
               pt_iter_ymax_ * ifelse(pt_iter_ymax_ > 0, 1.15, 1))
      rm(pt_iter_ymin_, pt_iter_ymax_)
    } else {
      yl_    <- global_pt_ylim
    }
    fpath_ <- file.path(
      output_dir,
      paste0("process_time_vs_", CONT_003,
             "_iter", CONT_002, ".jpg"))

    draw_process_ <- local({
      bd_        <- bxp_data_
      yl__       <- yl_
      ttl__      <- ttl_
      xvar__     <- CONT_003
      pp50__     <- pp50_
      show_out__ <- bxp_params$show_outliers
      function() {
        bxp(bd_,
            ylim     = yl__,
            xlab     = xvar__,
            ylab     = "process_time",
            main     = ttl__,
            outline  = show_out__,
            col      = "white",
            border   = "black",
            las      = 2,
            cex.axis = 0.9,
            cex.lab  = 1.1,
            cex.main = 1.1
            )
        abline(h = 0,      lty = 3, col = "grey60")
        abline(h = pp50__, lty = 2, col = "black")
        legend("topright",
               legend = paste0("P50 = ", round(pp50__, 3)),
               lty    = 2,
               bty    = "n",
               cex    = 0.9)
      }
    })

    plot_and_save(draw_process_, fpath_)
    cat("Saved:", basename(fpath_), "\n")

    rm(groups_, n_grp_, stats_mat_, n_vec_, out_vals_, out_grps_,
       bxp_data_, ttl_, pp50_, yl_, fpath_, draw_process_)
  }
  rm(CONT_003)

  current_df <- current_df[
    !is.na(current_df$process_time) &
      current_df$process_time < process_p50, ]
  cat("After process_time filter (< P50):", nrow(current_df),
      "configurations remain.\n")
  rm(process_p50)

  if (nrow(current_df) < 10) {
    cat("Fewer than 10 configurations after process_time filter.",
        "Stopping.\n")
    break
  }

  # ------------------------------------------------------------------
  # 3.3. Frequency bar charts
  # Shows how many surviving configurations have each combination
  # of hyperparameter values. Y axis is computed from the current
  # subset per chart.
  # ------------------------------------------------------------------
  for (CONT_003 in names(freq_groups)) {

    vars_ <- freq_groups[[CONT_003]]

    if (length(vars_) == 1) {
      freq_tbl_ <- table(current_df[[vars_]])
      lbls_     <- names(freq_tbl_)
      yvals_    <- as.integer(freq_tbl_)
    } else {
      combo_    <- do.call(
        paste,
        c(lapply(vars_, function(v) current_df[[v]]),
          list(sep = "_")))
      freq_tbl_ <- table(combo_)
      lbls_     <- names(freq_tbl_)
      yvals_    <- as.integer(freq_tbl_)
      rm(combo_)
    }

    yl_freq_  <- c(0, max(as.integer(yvals_), 1L) * 1.1)
    xlab_str_ <- if (length(vars_) == 1) vars_ else
      paste(vars_, collapse = " x ")
    ttl_      <- paste0("Hyperparameter sensitivity analysis (",
                        CONT_003, "). Iteration ", CONT_002, ".")
    fpath_    <- file.path(
      output_dir,
      paste0("freq_", CONT_003, "_iter", CONT_002, ".jpg"))

    draw_freq_ <- local({
      yl__    <- yl_freq_
      lbls__  <- lbls_
      yvals__ <- yvals_
      xlab__  <- xlab_str_
      ttl__   <- ttl_
      function() {
        old_mar_ <- par(mar = c(8, 4, 4, 2))
        on.exit(par(old_mar_), add = TRUE)
        barplot(yvals__,
                names.arg = lbls__,
                xlab      = "",
                ylab      = "Frequency",
                main      = ttl__,
                col       = "black",
                ylim      = yl__,
                las       = 2,
                cex.axis  = 0.9,
                cex.lab   = 1.1,
                cex.main  = 1.1
                )
        mtext(xlab__, side = 1, line = 6, cex = 1.0)
      }
    })

    plot_and_save(draw_freq_, fpath_, width = 900)
    cat("Saved:", basename(fpath_), "\n")

    rm(vars_, freq_tbl_, lbls_, yvals_, yl_freq_,
       xlab_str_, ttl_, fpath_, draw_freq_)
  }
  rm(CONT_003)
  rm(freq_groups)

}
rm(CONT_002)
rm(adaptive_y_, bxp_params, global_groups, global_rew_ylim, global_pt_ylim)
rm(n_iter_max, varying_vars, all_candidate_vars)
rm(ask_param_selection, expl_vars)

# -------------------------------------------------------------
# 4. Save selected configurations
# -------------------------------------------------------------
{
  write.csv(current_df,
            file.path(output_dir, "selected_configurations.csv"),
            row.names = FALSE)
  saveRDS(current_df,
          file.path(output_dir, "selected_configurations.rds"))

  cat("\nAnalysis complete.\n")
  cat("Selected configurations:", nrow(current_df), "\n")
  cat("All outputs saved to:", output_dir, "\n")
}
