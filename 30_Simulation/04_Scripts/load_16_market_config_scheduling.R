# -------------------------------------------------------------
# Script: load_16_market_config_scheduling.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK5
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads the scheduling market configuration table from
# 16_Market_config_scheduling.csv, validates required columns
# and non-empty content, and stores the data frame in
# parameters$market_config_scheduling.
# Sourced from load_all_parameters.R.
# -------------------------------------------------------------

{
  market_config_scheduling_df <- read.csv(
    paths$market_config_scheduling_file,
    comment.char     = "#",
    stringsAsFactors = FALSE
  )

  if (nrow(market_config_scheduling_df) == 0) {
    stop("16_Market_config_scheduling.csv is empty")
  }

  required_market_cols <- c("Market", "closure", "begin", "end", "end_optimization", "aim")
  missing_market_cols  <- setdiff(required_market_cols, names(market_config_scheduling_df))
  if (length(missing_market_cols) > 0) {
    stop("16_Market_config_scheduling.csv is missing required columns: ",
         paste(missing_market_cols, collapse = ", "))
  }

  first_market_value <- trimws(tolower(as.character(market_config_scheduling_df$Market[1])))
  if (identical(first_market_value, "texto")) {
    market_config_scheduling_df <- market_config_scheduling_df[-1, , drop = FALSE]
  }

  if (nrow(market_config_scheduling_df) == 0) {
    stop("16_Market_config_scheduling.csv does not contain market rows after removing unit/header rows")
  }

  parameters$market_config_scheduling <- market_config_scheduling_df

  rm(market_config_scheduling_df, required_market_cols, missing_market_cols, first_market_value)

  cat("Market config scheduling loaded\n")
}
