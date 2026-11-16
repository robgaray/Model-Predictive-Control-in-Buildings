# -------------------------------------------------------------
# Function: validate_market_coverage.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Checks that every market interval of the simulation is covered by
# a market: the time step of every row of Main_df, except the first,
# has to fall in the control period (from Period_Begin to
# Period_End) of at least one Scheduling or Piloting market. A row
# holds the energy of the time step that ends at it, so a market
# covers the rows after Period_Begin up to the row at Period_End. A
# row that no market covers has no operation decided by anyone, so
# the market configuration is an input data error, and the run stops
# before the simulation.
# The first row is the initial condition of the simulation: it is
# never simulated, so it needs no market.
# -------------------------------------------------------------
# Inputs
#   Main_df : Data frame. Must carry the time column (POSIXct) and,
#             for each of the prefixes Sched and Pilot, the columns
#             <prefix>_Market_Name, <prefix>_Market_Period_Begin and
#             <prefix>_Market_Period_End, as written by
#             build_market_timeline().
# -------------------------------------------------------------
# Outputs
#   Invisible TRUE when every row is covered. Otherwise the run
#   stops with an error that names the uncovered stretches.
# -------------------------------------------------------------
# Code outline
# 1. Rows covered by each market
# 2. Verdict
# -------------------------------------------------------------
# Usage instructions
# validate_market_coverage(Main_df)
# -------------------------------------------------------------
validate_market_coverage <- function(Main_df) {

  # -------------------------------------------------------------
  # 1. Rows covered by each market
  # A market covers the rows whose time step lies in its control
  # period, which are the rows its decision is applied to: those
  # after Period_Begin, up to and including the row at Period_End.
  # -------------------------------------------------------------
  {
    time_num <- as.numeric(Main_df$time)
    covered  <- logical(nrow(Main_df))
    covered[1] <- TRUE

    for (CONT_001 in c("Sched", "Pilot")) {
      name_col  <- paste0(CONT_001, "_Market_Name")
      begin_col <- paste0(CONT_001, "_Market_Period_Begin")
      end_col   <- paste0(CONT_001, "_Market_Period_End")
      missing   <- setdiff(c(name_col, begin_col, end_col), names(Main_df))
      if (length(missing) > 0) {
        stop("validate_market_coverage: Main_df is missing the columns ",
             paste(missing, collapse = ", "))
      }

      # is_market_active is called to find the rows where a market
      # of this role clears.
      active <- which(vapply(Main_df[[name_col]], is_market_active, logical(1)))
      begin  <- as.numeric(as.POSIXct(Main_df[[begin_col]][active],
                                      format = "%Y-%m-%d %H:%M:%S", tz = "UTC"))
      end    <- as.numeric(as.POSIXct(Main_df[[end_col]][active],
                                      format = "%Y-%m-%d %H:%M:%S", tz = "UTC"))
      for (CONT_002 in seq_along(active)) {
        covered[time_num > begin[CONT_002] & time_num <= end[CONT_002]] <- TRUE
      }
    }
    rm(list = c("CONT_001", "name_col", "begin_col", "end_col", "missing",
                "active", "begin", "end"))
  }

  # -------------------------------------------------------------
  # 2. Verdict
  # The uncovered rows are reported as stretches of consecutive
  # rows, so that the message points at the hours of the day that
  # the market configuration leaves out.
  # -------------------------------------------------------------
  {
    if (!all(covered)) {
      uncovered <- which(!covered)
      starts    <- uncovered[c(TRUE, diff(uncovered) > 1)]
      ends      <- uncovered[c(diff(uncovered) > 1, TRUE)]
      stretches <- paste0(format(Main_df$time[starts], "%Y-%m-%d %H:%M"), " to ",
                          format(Main_df$time[ends],   "%Y-%m-%d %H:%M"))
      stop("Input data validation error: ", length(uncovered), " rows of the ",
           "simulation are not covered by any market, in ", length(starts),
           " stretches. The first ones are: ",
           paste(head(stretches, 5), collapse = "; "), ". Every market interval ",
           "has to fall in the control period of a Scheduling or a Piloting ",
           "market: check 03_Market_config.csv, 04_Market_config_scheduling.csv ",
           "and 05_Market_config_piloting.csv.")
    }
  }

  rm(list = c("time_num", "covered"))

  return(invisible(TRUE))
}
