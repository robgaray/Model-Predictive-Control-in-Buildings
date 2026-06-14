# -------------------------------------------------------------
# Function: load_hyperparameter_data
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Reads all Sinthetized_df_computed_* files (RDS or CSV) from a
# given input directory, merges them into a single global dataframe,
# and overrides the parameter columns in each row with the numeric
# values encoded in the filename suffix.
# When both RDS and CSV files exist for the same configuration
# suffix, the RDS file is preferred.
# Rows with reward == 0 or NA are removed as they indicate
# incomplete or erroneous simulation results.
# -------------------------------------------------------------
# Inputs
#   input_dir   : character. Path to the directory containing the
#                 Sinthetized_df_computed_* files.
#   progress_fn : function or NULL. Optional callback called after
#                 each file is read with arguments
#                 (current, total, elapsed_sec). If NULL, no
#                 progress is reported.
# -------------------------------------------------------------
# Outputs
#   A dataframe (global_df) with all merged rows. Stops with an
#   error if no valid files are found or if the directory does
#   not exist.
# -------------------------------------------------------------
# Code outline
#   1. Validate input directory
#   2. Locate all RDS and CSV files; prefer RDS for duplicates
#   3. Read each file, parse filename suffix, override columns
#      Calls progress_fn(current, total, elapsed_sec) after each
#      file if progress_fn is not NULL.
#   4. Merge all rows into a single dataframe
#   5. Remove rows with reward == 0 or NA
# -------------------------------------------------------------
# Usage instructions
#   global_df <- load_hyperparameter_data(
#     "40_PostProcess/01_Hyperparameter_Analysis/01_Input"
#   )
# -------------------------------------------------------------
# Where this function/script is used
#   PostProcess_hyperparameter_analysis.R
#   GUI_hyperparameter.R
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

load_hyperparameter_data <- function(input_dir, progress_fn = NULL) {

  # Parameter names encoded in the filename suffix (positional order).
  # Must match the order used by data_outputs_SCC.R when building
  # the suffix from scc_run_params.
  # control_type (position 9) is a text column ("modes" or "setpoints").
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
    "Alpha_Service_Min",
    "month_subset"
  )

  # Positions (1-based) of text columns in the suffix.
  # All other positions are treated as numeric.
  suffix_text_positions <- c(9L)   # control_type

  # -------------------------------------------------------------
  # 1. Validate input directory
  # -------------------------------------------------------------
  {
    if (!dir.exists(input_dir)) {
      stop("Input directory not found: ", input_dir)
    }
  }

  # -------------------------------------------------------------
  # 2. Locate all RDS and CSV files; prefer RDS for duplicates
  # -------------------------------------------------------------
  {
    rds_files <- list.files(input_dir,
                            pattern    = "^Sinthetized_df_computed_.*\\.rds$",
                            full.names = TRUE)
    csv_files <- list.files(input_dir,
                            pattern    = "^Sinthetized_df_computed_.*\\.csv$",
                            full.names = TRUE)

    rds_suffixes <- sub("^Sinthetized_df_computed_", "",
                        tools::file_path_sans_ext(basename(rds_files)))
    csv_suffixes <- sub("^Sinthetized_df_computed_", "",
                        tools::file_path_sans_ext(basename(csv_files)))

    all_suffixes <- unique(c(rds_suffixes, csv_suffixes))

    if (length(all_suffixes) == 0) {
      stop("No Sinthetized_df_computed_*.rds or *.csv files found in: ",
           input_dir)
    }

    file_map <- character(length(all_suffixes))
    names(file_map) <- all_suffixes

    for (CONT_001 in seq_along(all_suffixes)) {
      sfx     <- all_suffixes[CONT_001]
      rds_idx <- match(sfx, rds_suffixes)
      csv_idx <- match(sfx, csv_suffixes)
      if (!is.na(rds_idx)) {
        file_map[CONT_001] <- rds_files[rds_idx]
      } else {
        file_map[CONT_001] <- csv_files[csv_idx]
      }
    }
    rm(CONT_001)
    rm(rds_files, csv_files, rds_suffixes, csv_suffixes, all_suffixes)

    n_total <- length(file_map)
    n_rds   <- sum(grepl("\\.rds$", file_map))
    n_csv   <- sum(grepl("\\.csv$", file_map))
    message("Found ", n_total, " unique Sinthetized_df_computed files ",
            "(RDS: ", n_rds, ", CSV: ", n_csv, ").")
    rm(n_total, n_rds, n_csv)
  }

  # -------------------------------------------------------------
  # 3. Read each file, parse filename suffix, override columns
  # Calls progress_fn(current, total, elapsed_sec) after each
  # file if progress_fn is not NULL.
  # -------------------------------------------------------------
  {
    start_time_ <- proc.time()[["elapsed"]]
    n_files_    <- length(file_map)
    row_list    <- vector("list", n_files_)

    for (CONT_002 in seq_along(file_map)) {
      f <- file_map[CONT_002]

      df <- tryCatch({
        if (grepl("\\.rds$", f)) {
          readRDS(f)
        } else {
          read.csv(f, stringsAsFactors = FALSE)
        }
      }, error = function(e) {
        warning("Cannot read file, skipping: ",
                basename(f), " - ", e$message)
        return(NULL)
      })

      if (!is.null(df)) {
        fname      <- tools::file_path_sans_ext(basename(f))
        suffix_str <- sub("^Sinthetized_df_computed_", "", fname)
        parts_raw  <- strsplit(suffix_str, "_")[[1]]

        if (length(parts_raw) != length(suffix_cols)) {
          warning("Unexpected filename format, skipping: ", basename(f))
          df <- NULL
        } else {
          # Convert each part: text positions stay as character,
          # all others are coerced to numeric.
          parts_any <- vector("list", length(parts_raw))
          bad_numeric <- FALSE
          for (CONT_003 in seq_along(parts_raw)) {
            if (CONT_003 %in% suffix_text_positions) {
              parts_any[[CONT_003]] <- parts_raw[CONT_003]
            } else {
              num_val <- suppressWarnings(as.numeric(parts_raw[CONT_003]))
              if (is.na(num_val)) {
                bad_numeric <- TRUE
                break
              }
              parts_any[[CONT_003]] <- num_val
            }
          }
          if (bad_numeric) {
            warning("Unexpected filename format (non-numeric in numeric field), skipping: ",
                    basename(f))
            df <- NULL
          } else {
            for (CONT_003 in seq_along(suffix_cols)) {
              df[[suffix_cols[CONT_003]]] <- parts_any[[CONT_003]]
            }
            rm(CONT_003)
          }
          rm(parts_any, bad_numeric)
        }
      }

      row_list[[CONT_002]] <- df

      if (!is.null(progress_fn)) {
        elapsed_  <- proc.time()[["elapsed"]] - start_time_
        progress_fn(CONT_002, n_files_, elapsed_)
      }
    }
    rm(CONT_002, start_time_, n_files_)
  }

  # -------------------------------------------------------------
  # 4. Merge all rows into a single dataframe
  # -------------------------------------------------------------
  {
    row_list <- Filter(Negate(is.null), row_list)

    if (length(row_list) == 0) {
      stop("No valid Sinthetized_df_computed files could be read.")
    }

    global_df        <- do.call(rbind, row_list)
    rownames(global_df) <- NULL
    rm(row_list, file_map)
  }

  # -------------------------------------------------------------
  # 5. Remove rows with reward == 0 or NA
  # Reward == 0 indicates an incomplete or erroneous simulation.
  # -------------------------------------------------------------
  {
    global_df <- global_df[!is.na(global_df$reward) &
                             global_df$reward != 0, ]

    message("Global dataframe: ", nrow(global_df), " rows, ",
            ncol(global_df), " columns.")
  }

  global_df
}
