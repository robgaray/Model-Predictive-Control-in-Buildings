# -------------------------------------------------------------
# Function: load_market_config_table.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Reads a market configuration table (scheduling or piloting) and:
#   - validates that it has the required columns and at least one
#     market row
#   - drops the units row, the first row under the header, with
#     drop_unit_row(), which stops when that row holds data
#   - returns the resulting data frame
# -------------------------------------------------------------
# One market per slot
# Every row of the table describes a market that clears once a day, at
# an offset of (begin - closure) hours from midnight. Two rows whose
# bid times fall inside the same market-resolution slot would be two
# markets of the same role clearing at the same moment, which the rest
# of the pipeline cannot represent: build_market_timeline() writes each
# market's timeline onto the Main_df row of its bid time, so the second
# one silently overwrites the first, and prepare_economic_analysis() keeps a
# single row per (slot, market type), so their flows would be merged
# and the identity of one of them lost. This is rejected here, at read
# time, rather than left to surface as a wrong number later.
# The check is per file, so it enforces exactly "no two Scheduling
# markets in one slot" and "no two Piloting markets in one slot"; a
# Scheduling and a Piloting market sharing a slot is legitimate and is
# resolved by the attribution rule in prepare_economic_analysis().
# -------------------------------------------------------------
# Inputs
# path      : Character. Path to the market config CSV file.
# file_name : Character. Base name of the file, used in error
#             messages (e.g. "04_Market_config_scheduling.csv").
# market_resolution : Numeric scalar. Market slot length in minutes
#             (parameters$market$market_resolution), used to resolve
#             each market's bid time into a slot for the one-market-
#             per-slot check.
# -------------------------------------------------------------
# Outputs
# Data frame. The market configuration table, without its units row,
# and these columns plus any others present in the file:
#   - Market
#   - closure
#   - begin
#   - end
#   - end_optimization
#   - aim
# -------------------------------------------------------------
# Code outline
# 1. Read the CSV file
# 2. Validate non-empty content and required columns
# 3. Drop the units row
# 4. Validate at least one market row remains
# 5. Validate column types and ranges (numeric closure/begin/end/
#    end_optimization, valid aim codes)
# 6. Validate that no two markets share a market-resolution slot
# -------------------------------------------------------------
# Usage instructions
# market_config_df <-
# load_market_config_table(paths$market_config_scheduling_file,
# "04_Market_config_scheduling.csv", parameters$market$market_resolution)
# -------------------------------------------------------------

load_market_config_table <- function(path, file_name, market_resolution) {

  market_config_df <- read.csv(
    path,
    comment.char     = "#",
    stringsAsFactors = FALSE
  )

  if (nrow(market_config_df) == 0) {
    stop(file_name, " is empty")
  }

  required_market_cols <- c("Market", "closure", "begin", "end", "end_optimization", "aim")
  missing_market_cols  <- setdiff(required_market_cols, names(market_config_df))
  if (length(missing_market_cols) > 0) {
    stop(file_name, " is missing required columns: ",
         paste(missing_market_cols, collapse = ", "))
  }

  # drop_unit_row is called to remove the units row, the first row
  # under the header, after checking it is not a market.
  market_config_df <- drop_unit_row(
    table             = market_config_df,
    file_name         = file_name,
    number_columns    = c("closure", "begin", "end", "end_optimization"),
    reference_columns = character(0),
    reference_values  = character(0)
  )

  if (nrow(market_config_df) == 0) {
    stop(file_name, " does not contain market rows after removing unit/header rows")
  }

  rm(list = c("required_market_cols", "missing_market_cols"))

  # 5. Validate column types and ranges
  # -------------------------------------------------------------
  {
    # The units row makes read.csv() type these
    # columns as character (mixed with non-numeric text); the validated
    # numeric values are written back so downstream consumers that don't
    # wrap every access in as.numeric() still get real numeric columns.
    numeric_market_cols <- c("closure", "begin", "end", "end_optimization")
    for (CONT_001 in numeric_market_cols) {
      col_values <- suppressWarnings(as.numeric(market_config_df[[CONT_001]]))
      if (anyNA(col_values)) {
        stop(file_name, ": column '", CONT_001, "' contains non-numeric or missing values")
      }
      if (any(col_values < 0)) {
        stop(file_name, ": column '", CONT_001, "' contains negative values")
      }
      market_config_df[[CONT_001]] <- col_values
    }
    rm(list = c("numeric_market_cols", "CONT_001", "col_values"))

    for (CONT_002 in seq_len(nrow(market_config_df))) {
      # map_optimization_aim is called on every row to confirm the raw
      # 'aim' code is one of the accepted market aim values; it stops
      # execution here (before the table is returned) if any row holds
      # an invalid code.
      map_optimization_aim(
        aim_raw     = market_config_df$aim[CONT_002],
        column_name = paste0(file_name, "$aim"),
        row_index   = CONT_002
      )
    }
    rm(list = "CONT_002")
  }

  # 6. Validate that no two markets share a market-resolution slot
  # -------------------------------------------------------------
  # Each market clears at (begin - closure) hours from midnight, the
  # same offset every day, so two markets collide on every day of the
  # simulation or on none. The offset can be negative (the market
  # clears the day before its delivery period starts); floor division
  # keeps the slot index correct in that case too.
  # -------------------------------------------------------------
  {
    if (is.null(market_resolution) ||
        length(market_resolution) != 1 ||
        !is.finite(as.numeric(market_resolution)) ||
        as.numeric(market_resolution) <= 0) {
      stop(file_name, ": a positive market_resolution (minutes) is required to ",
           "check that no two markets share a slot")
    }

    bid_offset_min <- (market_config_df$begin - market_config_df$closure) * 60
    bid_slot       <- floor(bid_offset_min / as.numeric(market_resolution))

    duplicated_slots <- unique(bid_slot[duplicated(bid_slot)])
    if (length(duplicated_slots) > 0) {
      collisions <- vapply(
        duplicated_slots,
        function(slot_index) {
          paste0(
            "slot starting at ", slot_index * as.numeric(market_resolution),
            " min from midnight: ",
            paste(market_config_df$Market[bid_slot == slot_index], collapse = ", ")
          )
        },
        character(1)
      )
      stop(file_name, ": more than one market clears in the same market slot. ",
           "Each market of a given role must clear in a slot of its own, ",
           "because only one can be recorded per slot. Offending slots - ",
           paste(collisions, collapse = "; "))
    }

    rm(list = intersect(c("bid_offset_min", "bid_slot", "duplicated_slots",
                          "collisions"),
                        ls()))
  }

  return(market_config_df)
}
