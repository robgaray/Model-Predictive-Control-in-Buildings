# -------------------------------------------------------------
# Function: load_asset_registry_safe.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads the asset registry without ever stopping the app. The units
# row is removed (a row whose values are the units of the catalogue)
# and every row is validated: each value against its rule of the
# parameter catalogue, the id against its format, the type against
# the prefix of the id, and the id against the ids already read. An
# invalid row is dropped and a message is collected for it. When no
# valid row is left, the rows of the default registry are used and
# flagged as defaults. It reads validation_config, which the app
# reads again each time its page is opened or reloaded.
# -------------------------------------------------------------
# Inputs
#   filename         : Character. Path of the registry file, relative
#                      to config_path.
#   default_filename : Character. Path of its Default_ file, relative
#                      to config_path.
# -------------------------------------------------------------
# Outputs
#   Named list with the elements:
#     - df, with the columns asset_id and asset_type, one row per
#       asset, in the order of the file
#     - defaulted_rows: Integer vector. The rows taken from the
#       default registry, which are all of them or none
#     - messages: Character vector. One message per dropped row or
#       per problem found
# -------------------------------------------------------------
# Code outline
# 1. Read the registry and drop its units row.
# 2. Validate each row.
# 3. Use the default registry when no valid row is left.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   load_asset_registry_safe(filename, default_filename)
# -------------------------------------------------------------

load_asset_registry_safe <- function(filename, default_filename) {

  messages     <- character(0)
  registry_key <- basename(filename)
  columns      <- c("asset_id", "asset_type")

  # -------------------------------------------------------------
  # 1. Read the registry and drop its units row
  # read_registry reads a registry file and returns its rows without
  # the units row, or NULL when it cannot be read.
  # -------------------------------------------------------------
  {
    read_registry <- function(path) {
      table <- tryCatch(
        suppressWarnings(read.csv(
          file.path(config_path, path),
          comment.char     = "#",
          stringsAsFactors = FALSE,
          strip.white      = TRUE,
          colClasses       = "character"
        )),
        error = function(e) NULL
      )
      if (is.null(table) || !all(columns %in% names(table))) {
        return(NULL)
      }
      table <- table[, columns, drop = FALSE]
      rules <- validation_config$rules
      units <- vapply(
        columns,
        function(column) {
          rules$unit[rules$file == registry_key & rules$parameter == column][1]
        },
        character(1)
      )
      if (nrow(table) > 0 && !anyNA(units) &&
          all(unlist(table[1, ]) == units)) {
        table <- table[-1, , drop = FALSE]
      }
      rownames(table) <- NULL
      table
    }

    registry <- read_registry(filename)
    if (is.null(registry)) {
      messages <- c(messages, sprintf(
        "Could not read '%s' (missing, empty file, or invalid columns).",
        filename
      ))
    }
  }

  # -------------------------------------------------------------
  # 2. Validate each row
  # A row is kept when its two values are valid, its id is a type, an
  # underscore and three digits, its type is the prefix of its id and
  # its id has not appeared before.
  # -------------------------------------------------------------
  {
    keep <- logical(0)
    if (!is.null(registry)) {
      keep <- rep(FALSE, nrow(registry))
      for (CONT_401 in seq_len(nrow(registry))) {
        row_id   <- registry$asset_id[CONT_401]
        row_type <- registry$asset_type[CONT_401]

        # check_param_valid is called for each value to check it
        # against its rule of the catalogue, as the simulation does.
        values_ok <- check_param_valid(
          value             = row_id,
          file_name         = registry_key,
          param_name        = "asset_id",
          validation_config = validation_config
        ) && check_param_valid(
          value             = row_type,
          file_name         = registry_key,
          param_name        = "asset_type",
          validation_config = validation_config
        )
        format_ok <- values_ok &&
          grepl("^[A-Za-z]+_[0-9]{3}$", row_id) &&
          sub("_[0-9]+$", "", row_id) == row_type
        repeated  <- row_id %in% registry$asset_id[keep]

        if (format_ok && !repeated) {
          keep[CONT_401] <- TRUE
        } else {
          messages <- c(messages, sprintf(
            "%s: the row %d (asset_id '%s', asset_type '%s') is %s. It is dropped.",
            filename, CONT_401, row_id, row_type,
            if (repeated) "a repeated id" else "invalid"
          ))
        }
        rm(row_id, row_type, values_ok, format_ok, repeated)
      }
      registry <- registry[keep, , drop = FALSE]
      rownames(registry) <- NULL
      rm(CONT_401)
    }
  }

  # -------------------------------------------------------------
  # 3. Use the default registry when no valid row is left
  # -------------------------------------------------------------
  {
    defaulted_rows <- integer(0)
    if (is.null(registry) || nrow(registry) == 0) {
      defaults <- read_registry(default_filename)
      if (is.null(defaults) || nrow(defaults) == 0) {
        stop("Neither the asset registry nor its defaults could be read: '",
             filename, "' is missing or invalid.")
      }
      messages <- c(messages, sprintf(
        "'%s' holds no valid asset. Using the default registry.",
        filename
      ))
      registry       <- defaults
      defaulted_rows <- seq_len(nrow(registry))
      rm(defaults)
    }
    rm(read_registry, keep)
  }

  return(list(df = registry, defaulted_rows = defaulted_rows,
              messages = messages))
}
