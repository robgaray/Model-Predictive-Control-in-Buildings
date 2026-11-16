# -------------------------------------------------------------
# Function: validate_asset_df.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Performs the structural and content validation of the table of an
# asset, assets[[asset_id]]$df, before it is prepared and used in the
# simulation loop. The table of an asset is generated from the
# variable registry of its type of model (for a building,
# Building_variables_df), one row per row of Main_df, and it is
# checked against the columns of its type. It checks:
#   1. That the table is a data frame with one row per row of Main_df.
#   2. That all required columns are present.
#   3. That its time column is the time column of Main_df, row by row.
#   4. That all non-time required columns are numeric.
#   5. That Occupancy and Scheduling are integer 0/1 flags, and that
#      the activation columns Act_heat_exec and Act_cool_exec hold
#      only 0, 1 or 2, for the flag columns that the type of the
#      asset holds.
# -------------------------------------------------------------
# Inputs
#   asset_df      : Data frame. The table of the asset.
#   time          : POSIXct vector. The time column of Main_df.
#   required_cols : Character vector. The columns the assembled table
#                   of an asset of its type must hold: those of stage
#                   assembly and of the table of the type in
#                   02_Needed_cols.csv, time included, as
#                   load_needed_columns() returns them for the type.
#   asset_id      : Character scalar. The id of the asset, for the
#                   messages.
# -------------------------------------------------------------
# Outputs
#   Invisibly returns TRUE if all checks pass.
# -------------------------------------------------------------
# Code outline
# 1. Check the data frame and its rows
# 2. Check the required columns
# 3. Check the time column against Main_df
# 4. Validate numeric columns
# 5. Validate binary flag columns
# -------------------------------------------------------------
# Usage instructions
# validate_asset_df(assets$Building_001$df, Main_df$time,
#                   parameters$asset_cols_assembly$Building,
#                   "Building_001")
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - Every check that fails stops the run with stop(), naming the
#     asset.
# -------------------------------------------------------------

validate_asset_df <- function(asset_df,
                              time,
                              required_cols,
                              asset_id
                              ) {

  # -------------------------------------------------------------
  # 1. Check the data frame and its rows
  # -------------------------------------------------------------
  {
    if (!is.data.frame(asset_df)) {
      stop("The table of ", asset_id, " is not a data.frame")
    }
    if (nrow(asset_df) != length(time)) {
      stop("The table of ", asset_id, " has ", nrow(asset_df),
           " rows, and Main_df ", length(time))
    }
  }

  # -------------------------------------------------------------
  # 2. Check the required columns
  # -------------------------------------------------------------
  {
    missing_cols <- setdiff(required_cols, names(asset_df))
    if (length(missing_cols) > 0) {
      stop("The table of ", asset_id, " is missing required columns:\n",
           paste(missing_cols, collapse = ", "))
    }
    rm(list = "missing_cols")
  }

  # -------------------------------------------------------------
  # 3. Check the time column against Main_df
  # The table of an asset has the rows of Main_df, in the same order:
  # time is the key that joins them.
  # -------------------------------------------------------------
  {
    if (!identical(as.numeric(asset_df$time), as.numeric(time))) {
      stop("The time column of the table of ", asset_id,
           " is not the time column of Main_df")
    }
  }

  # -------------------------------------------------------------
  # 4. Validate numeric columns
  # -------------------------------------------------------------
  {
    numeric_cols <- setdiff(required_cols, "time")
    non_numeric  <- numeric_cols[!vapply(asset_df[numeric_cols],
                                         is.numeric, logical(1))]
    if (length(non_numeric) > 0) {
      stop("The following columns of the table of ", asset_id,
           " must be numeric:\n", paste(non_numeric, collapse = ", "))
    }
    rm(list = c("numeric_cols", "non_numeric"))
  }

  # -------------------------------------------------------------
  # 5. Validate binary flag columns
  # Occupancy and Scheduling are integer flags; the activation of the
  # heating and the cooling in the executed itinerary are 0, 1 or 2. A
  # flag is checked only when the type of the asset holds it, so a
  # type with no such columns skips the checks.
  # -------------------------------------------------------------
  {
    for (CONT_001 in intersect(c("Occupancy", "Scheduling"),
                               required_cols)) {
      if (!is.integer(asset_df[[CONT_001]])) {
        stop("Column ", CONT_001, " of the table of ", asset_id,
             " must be of type integer")
      }
    }
    for (CONT_002 in intersect(c("Occupancy", "Scheduling"),
                               required_cols)) {
      values <- unique(na.omit(asset_df[[CONT_002]]))
      if (!all(values %in% c(0, 1))) {
        stop("Column ", CONT_002, " of the table of ", asset_id,
             " contains values other than 0/1")
      }
    }
    # An activation is 0 (off), 1 (on by the thermostat) or 2 (heat
    # imposed from outside the thermostat).
    for (CONT_003 in intersect(c("Act_heat_exec", "Act_cool_exec"),
                               required_cols)) {
      values <- unique(na.omit(asset_df[[CONT_003]]))
      if (!all(values %in% c(0, 1, 2))) {
        stop("Column ", CONT_003, " of the table of ", asset_id,
             " contains values other than 0/1/2")
      }
    }
    rm(list = intersect(c("CONT_001", "CONT_002", "CONT_003", "values"),
                        ls()))
  }

  invisible(TRUE)
}
