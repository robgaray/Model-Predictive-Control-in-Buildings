# -------------------------------------------------------------
# Function: expand_to_15min.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Expands a two-column data frame (time, value_col) to 15-minute
# resolution.  When source data is hourly, the same value is
# repeated for all four 15-minute slots within each hour
# (no interpolation).  When source data is already at
# 15-minute resolution, it is returned unchanged.
# -------------------------------------------------------------
# INPUT:
#   df        : Data frame. Must contain at least two columns:
#               a time column (POSIXct) identified by time_col,
#               and a value column identified by value_col.
#   value_col : Character. Name of the column with the values
#               to expand.
#   time_col  : Character. Name of the POSIXct time column.
#               Defaults to "time".
#
# OUTPUT:
#   Data frame with columns time (15-min POSIXct grid) and the
#   expanded value column.  Rows are sorted ascending by time.
#   If df has zero rows, df is returned unchanged.
# -------------------------------------------------------------
# FUNCTIONS USED (from this repository):
#   (none)
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If df has zero rows, it is returned immediately.
#   - The 15-min grid spans from floor_date(min(time), "hour")
#     to floor_date(max(time), "hour") + 45 minutes, so that
#     the last hour is fully represented.
#   - Matching is performed on floored (to-the-hour) timestamps;
#     any sub-hourly variation in source timestamps is discarded.
# -------------------------------------------------------------
expand_to_15min <- function(df, value_col, time_col = "time") {
  if (nrow(df) == 0) return(df)

  t_start <- floor_date(min(df[[time_col]]), unit = "hour")
  t_end   <- floor_date(max(df[[time_col]]), unit = "hour") + 45 * 60

  grid_15 <- data.frame(time = seq(t_start, t_end, by = "15 min"))
  grid_15$time_hour <- floor_date(grid_15$time, unit = "hour")

  df_join           <- df[, c(time_col, value_col)]
  names(df_join)[names(df_join) == time_col] <- "time_hour"
  df_join$time_hour <- floor_date(df_join$time_hour, unit = "hour")

  result <- merge(grid_15, df_join, by = "time_hour", all.x = TRUE)
  result$time_hour <- NULL
  result[order(result$time), ]
}
