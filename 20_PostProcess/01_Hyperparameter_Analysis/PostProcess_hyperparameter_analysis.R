# -------------------------------------------------------------
# Script: PostProcess_hyperparameter_analysis.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
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
# Before starting the analysis, the user is prompted (Y/N) for
# each parameter to decide whether to include it in the
# sensitivity analysis.
#
# The analysis iterates up to 3 times (or until fewer than 10
# configurations remain) over:
#   1.1  Reward scatter plots (X: selected parameters;
#        Y: reward); filters configurations where
#        reward > 75th percentile.
#   1.2  Process-time scatter plots (same X variables;
#        Y: process_time); filters configurations where
#        process_time < 50th percentile.
#   1.3  Frequency bar charts for individual and combined
#        hyperparameter groups.
#
# Axis limits and tick-mark spacing are fixed from iteration 1
# and reused in subsequent iterations to allow direct visual
# comparison. All plots are rendered in black and white.
# -------------------------------------------------------------
# Inputs
#   Sinthetized_df_computed_*.rds / *.csv files in 01_Input/
#   Each filename encodes 17 parameters as a numeric suffix.
#   User interactive Y/N responses for parameter selection.
# -------------------------------------------------------------
# Outputs
#   global_df.csv / global_df.rds
#   selected_configurations.csv / .rds
#   reward_vs_<var>_iter<N>.jpg
#   process_time_vs_<var>_iter<N>.jpg
#   freq_<group>_iter<N>.jpg
# -------------------------------------------------------------
# Code outline
#   0. Paths
#   1. Read and merge all Sinthetized_df_computed files
#      (supports RDS and CSV; prefers RDS when both exist)
#   2. Save global dataframe
#   2b. Interactive parameter selection for sensitivity analysis
#   3. Iterative hyperparameter sensitivity analysis
#      3.1 Reward scatter plots + filter (> P75)
#      3.2 Process-time scatter plots + filter (< P50)
#      3.3 Frequency bar charts
#   4. Save selected configurations
# -------------------------------------------------------------
# Usage instructions
#   Run from the repository root:
#     Rscript 20_PostProcess/01_Hyperparameter_Analysis/PostProcess_hyperparameter_analysis.R
#   Or source from an interactive R session with the repo root
#   as the working directory.
# -------------------------------------------------------------
# Where this function/script is used
#   Standalone script, run by the user after parametric SCC
#   simulations are complete.
# -------------------------------------------------------------
# functions/scripts called
#   plot_and_save.R (from 03_Functions/)
# -------------------------------------------------------------

# ----------------------------------------------------------------
# 0. Paths
# ----------------------------------------------------------------
if (dir.exists("20_PostProcess/01_Hyperparameter_Analysis")) {
  base_dir <- "20_PostProcess/01_Hyperparameter_Analysis"
} else if (dir.exists("01_Input")) {
  base_dir <- "."
} else {
  stop("Cannot locate 20_PostProcess/01_Hyperparameter_Analysis directory. ",
       "Run this script from the repository root or from ",
       "20_PostProcess/01_Hyperparameter_Analysis/.")
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
source(file.path(func_dir, "plot_and_save.R"))

# ----------------------------------------------------------------
# 1. Read and merge all Sinthetized_df_computed files
#    Supports both RDS and CSV formats.
#    When both formats exist for the same suffix, RDS is preferred.
# ----------------------------------------------------------------

# Parameter names encoded in the filename suffix (in positional order)
# These match the order used by data_outputs_SCC.R when building the
# suffix from scc_run_params.
suffix_cols <- c(
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
  "Alpha_confort",
  "month_subset"
)

# Find all RDS and CSV files
rds_files <- list.files(input_dir,
                        pattern    = "^Sinthetized_df_computed_.*\\.rds$",
                        full.names = TRUE)
csv_files <- list.files(input_dir,
                        pattern    = "^Sinthetized_df_computed_.*\\.csv$",
                        full.names = TRUE)

# Extract suffixes from filenames to identify unique configurations
rds_suffixes <- sub("^Sinthetized_df_computed_", "",
                    tools::file_path_sans_ext(basename(rds_files)))
csv_suffixes <- sub("^Sinthetized_df_computed_", "",
                    tools::file_path_sans_ext(basename(csv_files)))

# Build a mapping: suffix -> file path (RDS preferred over CSV)
all_suffixes <- unique(c(rds_suffixes, csv_suffixes))

if (length(all_suffixes) == 0) {
  stop("No Sinthetized_df_computed_*.rds or *.csv files found in: ",
       input_dir)
}

# For each suffix, prefer the RDS file if it exists
file_map <- character(length(all_suffixes))
names(file_map) <- all_suffixes

for (CONT_001 in seq_along(all_suffixes)) {
  sfx <- all_suffixes[CONT_001]
  rds_idx <- match(sfx, rds_suffixes)
  csv_idx <- match(sfx, csv_suffixes)
  if (!is.na(rds_idx)) {
    file_map[CONT_001] <- rds_files[rds_idx]
  } else {
    file_map[CONT_001] <- csv_files[csv_idx]
  }
}
rm(CONT_001, rds_files, csv_files, rds_suffixes, csv_suffixes, all_suffixes)

cat("Found", length(file_map), "unique Sinthetized_df_computed files.\n")

n_rds <- sum(grepl("\\.rds$", file_map))
n_csv <- sum(grepl("\\.csv$", file_map))
cat("  RDS files:", n_rds, "\n")
cat("  CSV files:", n_csv, "\n")
rm(n_rds, n_csv)

row_list <- lapply(file_map, function(f) {

  df <- tryCatch({
    if (grepl("\\.rds$", f)) {
      readRDS(f)
    } else {
      read.csv(f, stringsAsFactors = FALSE)
    }
  }, error = function(e) {
    warning("Cannot read file, skipping: ", basename(f), " - ", e$message)
    return(NULL)
  })

  if (is.null(df)) return(NULL)

  fname <- tools::file_path_sans_ext(basename(f))

  # Parse the numeric suffix: remove prefix "Sinthetized_df_computed_"
  suffix_str <- sub("^Sinthetized_df_computed_", "", fname)
  parts      <- suppressWarnings(as.numeric(strsplit(suffix_str, "_")[[1]]))

  if (length(parts) != length(suffix_cols) || any(is.na(parts))) {
    warning("Unexpected filename format, skipping: ", basename(f))
    return(NULL)
  }

  # Override the parameter columns with the values from the filename
  for (CONT_002 in seq_along(suffix_cols)) {
    df[[suffix_cols[CONT_002]]] <- parts[CONT_002]
  }

  df
})

row_list  <- Filter(Negate(is.null), row_list)

if (length(row_list) == 0) {
  stop("No valid Sinthetized_df_computed files could be read.")
}

global_df <- do.call(rbind, row_list)
rownames(global_df) <- NULL

# remove cases with reward == 0 as it seems to be an error
# from the MPC simulation process
global_df <- global_df[!is.na(global_df$reward) &
                         global_df$reward != 0, ]

cat("Global dataframe: ", nrow(global_df), "rows,",
    ncol(global_df), "columns.\n")
cat("Columns:", paste(names(global_df), collapse = ", "), "\n")
rm(row_list, file_map)


# ----------------------------------------------------------------
# 2. Save global dataframe (before any filtering)
# ----------------------------------------------------------------
write.csv(global_df,
          file.path(output_dir, "global_df.csv"),
          row.names = FALSE)
saveRDS(global_df,
        file.path(output_dir, "global_df.rds"))
cat("Global dataframe saved to", output_dir, "\n")

# ----------------------------------------------------------------
# 2b. Interactive parameter selection for sensitivity analysis
# Prompts the user (Y/N) for each candidate parameter to decide
# which ones to include in the scatter plots and frequency
# bar charts.
# ----------------------------------------------------------------

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
  "Alpha_confort",
  "month_subset"
)

# Only offer parameters that actually vary in the data
varying_vars <- character(0)
for (CONT_003 in all_candidate_vars) {
  if (CONT_003 %in% names(global_df)) {
    unique_vals <- unique(global_df[[CONT_003]])
    if (length(unique_vals) > 1) {
      varying_vars <- c(varying_vars, CONT_003)
    }
  }
}
rm(CONT_003)

cat("\n--- Parameter Selection for Sensitivity Analysis ---\n")
cat("The following parameters vary across configurations.\n")
cat("Select which ones to include in the analysis (Y/N):\n\n")

expl_vars <- character(0)

for (CONT_004 in varying_vars) {
  unique_vals <- sort(unique(global_df[[CONT_004]]))
  cat(sprintf("  %s [%d unique values: %s]\n",
              CONT_004,
              length(unique_vals),
              paste(head(unique_vals, 5), collapse = ", ")))

  repeat {
    response <- readline(prompt = sprintf("  Include '%s'? (Y/N): ",
                                          CONT_004))
    response <- toupper(trimws(response))
    if (response %in% c("Y", "N")) break
    cat("  Please enter Y or N.\n")
  }

  if (response == "Y") {
    expl_vars <- c(expl_vars, CONT_004)
  }
}
rm(CONT_004, varying_vars, all_candidate_vars)

if (length(expl_vars) == 0) {
  cat("\nNo parameters selected. Using default set: ",
      "population_size, iteration_number, run_number.\n")
  expl_vars <- c("population_size", "iteration_number", "run_number")
}

cat("\nSelected parameters for sensitivity analysis:\n")
cat("  ", paste(expl_vars, collapse = ", "), "\n\n")

# ----------------------------------------------------------------
# 3. Iterative hyperparameter sensitivity analysis
# ----------------------------------------------------------------

# Build frequency groups dynamically from the selected variables
# Individual groups for each selected variable, plus combined
# groups for pairs and triples (up to 3 variables max).
freq_groups <- list()

for (CONT_005 in expl_vars) {
  freq_groups[[CONT_005]] <- CONT_005
}

if (length(expl_vars) >= 2) {
  for (CONT_006 in 1:(length(expl_vars) - 1)) {
    for (CONT_007 in (CONT_006 + 1):length(expl_vars)) {
      combo_name <- paste(expl_vars[CONT_006], expl_vars[CONT_007],
                          sep = "_x_")
      freq_groups[[combo_name]] <- c(expl_vars[CONT_006],
                                     expl_vars[CONT_007])
    }
  }
}

if (length(expl_vars) >= 3) {
  for (CONT_008 in 1:(length(expl_vars) - 2)) {
    for (CONT_009 in (CONT_008 + 1):(length(expl_vars) - 1)) {
      for (CONT_010 in (CONT_009 + 1):length(expl_vars)) {
        combo_name <- paste(expl_vars[CONT_008],
                            expl_vars[CONT_009],
                            expl_vars[CONT_010],
                            sep = "_x_")
        freq_groups[[combo_name]] <- c(expl_vars[CONT_008],
                                       expl_vars[CONT_009],
                                       expl_vars[CONT_010])
      }
    }
  }
}

# Axis limits fixed from the first iteration and reused thereafter
reward_lims  <- list()  # per x-variable: list(xlim=..., ylim=...)
process_lims <- list()  # per x-variable
freq_ylims   <- list()  # per freq-group name

current_df <- global_df
n_iter_max <- 3

for (CONT_002 in seq_len(n_iter_max)) {

  cat("\n=== Iteration", CONT_002, "===\n")
  cat("Configurations:", nrow(current_df), "\n")

  # Stop before starting a new cycle if fewer than 10 configurations remain
  if (CONT_002 > 1 && nrow(current_df) < 10) {
    cat("Fewer than 10 configurations remain. Stopping.\n")
    break
  }

  # ------------------------------------------------------------------
  # 1.1  Reward scatter plots + filter (reward > P75)
  # ------------------------------------------------------------------
  reward_p75 <- quantile(current_df$reward, 0.75, na.rm = TRUE)
  cat("Reward P75:", reward_p75, "\n")

  for (CONT_003 in expl_vars) {

    # Store axis limits from the first iteration
    if (CONT_002 == 1) {
      xmax <- max(current_df[[CONT_003]], na.rm = TRUE)
      ymin <- min(c(0, current_df$reward), na.rm = TRUE)
      ymax <- max(current_df$reward, na.rm = TRUE)
      reward_lims[[CONT_003]] <- list(
        xlim = c(0, xmax * 1.15),
        ylim = c(ymin * ifelse(ymin < 0, 1.15, 1),
                 ymax * ifelse(ymax > 0, 1.15, 1))
      )
    }

    xl    <- reward_lims[[CONT_003]]$xlim
    yl    <- reward_lims[[CONT_003]]$ylim
    x_cur <- current_df[[CONT_003]]
    y_cur <- current_df$reward
    rp75  <- reward_p75
    ttl   <- paste0("Hyperparameter sensitivity analysis (", CONT_003,
                    "). Iteration ", CONT_002, ".")
    fpath <- file.path(output_dir,
                       paste0("reward_vs_", CONT_003, "_iter", CONT_002, ".jpg"))

    draw_reward <- local({
      xl_    <- xl;  yl_    <- yl
      x_cur_ <- x_cur;  y_cur_ <- y_cur
      rp75_  <- rp75;   ttl_   <- ttl;   xvar_  <- CONT_003
      function() {
        plot(x_cur_, y_cur_,
             xlab = xvar_, ylab = "reward",
             main = ttl_,
             xlim = xl_, ylim = yl_,
             col  = "black", pch = 16)
        abline(h = rp75_, lty = 2)
        legend("topright",
               legend = paste0("P75 = ", round(rp75_, 3)),
               lty = 2, bty = "n")
      }
    })

    plot_and_save(draw_reward, fpath)
    cat("Saved:", basename(fpath), "\n")
  }

  # Filter: keep only configurations with reward > P75
  current_df <- current_df[!is.na(current_df$reward) &
                              current_df$reward > reward_p75, ]
  cat("After reward filter (> P75):", nrow(current_df),
      "configurations remain.\n")

  if (nrow(current_df) < 10) {
    cat("Fewer than 10 configurations remain after reward filter. Stopping.\n")
    break
  }

  # ------------------------------------------------------------------
  # 1.2  Process-time scatter plots + filter (process_time < P50)
  # ------------------------------------------------------------------
  process_p50 <- quantile(current_df$process_time, 0.50, na.rm = TRUE)
  cat("Process time P50:", process_p50, "\n")

  for (CONT_004 in expl_vars) {

    if (CONT_002 == 1) {
      xmax <- max(current_df[[CONT_004]], na.rm = TRUE)
      ymin <- min(c(0, current_df$process_time), na.rm = TRUE)
      ymax <- max(current_df$process_time, na.rm = TRUE)
      process_lims[[CONT_004]] <- list(
        xlim = c(0, xmax * 1.15),
        ylim = c(ymin * ifelse(ymin < 0, 1.15, 1),
                 ymax * ifelse(ymax > 0, 1.15, 1))
      )
    }

    xl    <- process_lims[[CONT_004]]$xlim
    yl    <- process_lims[[CONT_004]]$ylim
    x_cur <- current_df[[CONT_004]]
    y_cur <- current_df$process_time
    pp50  <- process_p50
    ttl   <- paste0("Hyperparameter sensitivity analysis (", CONT_004,
                    "). Iteration ", CONT_002, ".")
    fpath <- file.path(output_dir,
                       paste0("process_time_vs_", CONT_004, "_iter", CONT_002, ".jpg"))

    draw_process <- local({
      xl_    <- xl;  yl_    <- yl
      x_cur_ <- x_cur;  y_cur_ <- y_cur
      pp50_  <- pp50;   ttl_   <- ttl;   xvar_  <- CONT_004
      function() {
        plot(x_cur_, y_cur_,
             xlab = xvar_, ylab = "process_time",
             main = ttl_,
             xlim = xl_, ylim = yl_,
             col  = "black", pch = 16)
        abline(h = pp50_, lty = 2)
        legend("topright",
               legend = paste0("P50 = ", round(pp50_, 3)),
               lty = 2, bty = "n")
      }
    })

    plot_and_save(draw_process, fpath)
    cat("Saved:", basename(fpath), "\n")
  }

  # Filter: keep only configurations with process_time < P50
  current_df <- current_df[!is.na(current_df$process_time) &
                              current_df$process_time < process_p50, ]
  cat("After process_time filter (< P50):", nrow(current_df),
      "configurations remain.\n")

  if (nrow(current_df) < 10) {
    cat("Fewer than 10 configurations remain after process_time filter.",
        "Stopping.\n")
    break
  }

  # ------------------------------------------------------------------
  # 1.3  Frequency bar charts
  # ------------------------------------------------------------------
  for (CONT_005 in names(freq_groups)) {

    vars <- freq_groups[[CONT_005]]

    if (length(vars) == 1) {
      freq_tbl <- table(current_df[[vars]])
      lbls     <- names(freq_tbl)
      yvals    <- as.integer(freq_tbl)
    } else {
      combo    <- do.call(paste,
                          c(lapply(vars, function(v) current_df[[v]]),
                            list(sep = "_")))
      freq_tbl <- table(combo)
      lbls     <- names(freq_tbl)
      yvals    <- as.integer(freq_tbl)
    }

    if (CONT_002 == 1) {
      freq_ylims[[CONT_005]] <- c(0, max(yvals, 1L) * 1.25)
    }

    yl_freq  <- freq_ylims[[CONT_005]]
    xlab_str <- if (length(vars) == 1) vars else paste(vars, collapse = " x ")
    ttl      <- paste0("Hyperparameter sensitivity analysis (", CONT_005,
                       "). Iteration ", CONT_002, ".")
    fpath    <- file.path(output_dir,
                          paste0("freq_", CONT_005, "_iter", CONT_002, ".jpg"))

    draw_freq <- local({
      yl_    <- yl_freq;  lbls_  <- lbls;  yvals_ <- yvals
      xlab_  <- xlab_str; ttl_   <- ttl
      function() {
        old_mar <- par(mar = c(8, 4, 4, 2))
        on.exit(par(old_mar), add = TRUE)
        barplot(yvals_,
                names.arg = lbls_,
                xlab      = "",
                ylab      = "Frequency",
                main      = ttl_,
                col       = "black",
                ylim      = yl_,
                las       = 2)
        mtext(xlab_, side = 1, line = 6)
      }
    })

    plot_and_save(draw_freq, fpath, width = 900)
    cat("Saved:", basename(fpath), "\n")
  }
}

# ----------------------------------------------------------------
# 4. Save selected configurations
# ----------------------------------------------------------------
write.csv(current_df,
          file.path(output_dir, "selected_configurations.csv"),
          row.names = FALSE)
saveRDS(current_df,
        file.path(output_dir, "selected_configurations.rds"))

cat("\nAnalysis complete.\n")
cat("Selected configurations:", nrow(current_df), "\n")
cat("All outputs saved to:", output_dir, "\n")
