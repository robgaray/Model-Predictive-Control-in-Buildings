# -------------------------------------------------------------
# Script: GUI_config.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Shiny interface for editing and saving simulation
# configuration files in 30_Simulation/02_Config.
# The interface reads parameter files and editable tables,
# keeps the reactive state synchronized with user edits,
# and writes all configuration files when the save button
# of any tab is pressed.
# -------------------------------------------------------------
# File paths: the file names of every configuration file are read
# from 30_Simulation/02_Config/05_File_paths.csv (falls back to a
# hard-coded default list if that file is missing/unreadable), so
# this app no longer keeps its own separate copy of that list.
# -------------------------------------------------------------
# Loading safety: every configuration file is loaded through a
# "safe loader" that tolerates a missing file, a missing parameter,
# a duplicated parameter, or an invalid value. Whatever loads and
# validates correctly is kept; anything missing or invalid is
# replaced by the matching entry from a Default_ file in
# 30_Simulation/02_Config/00_Validation/ (default values are never
# hard-coded in this script); a duplicated parameter keeps its first
# value. Every such case is collected as a warning, and the affected
# input/row is rendered in red so the user can see at a glance what
# came from defaults, or was deduplicated, rather than being read
# as-is from the file on disk. All loading/saving notices are shown
# in English.
# -------------------------------------------------------------
# Validation: values are validated against
# 30_Simulation/02_Config/00_Validation/Parameter_config.csv (the
# same rules used by the real simulation pipeline) both when loading
# (to decide what counts as valid) and again right before saving (to
# refuse to write anything if any field is currently invalid).
# -------------------------------------------------------------

library(shiny)
library(shinyjs)
library(DT)

input_path <- "30_Simulation/02_Config"

{
  .script_dir <- tryCatch(
    dirname(normalizePath(sys.frame(1)$ofile)),
    error = function(e) NULL
  )

  if (!is.null(.script_dir) && nzchar(.script_dir)) {
    app_dir <- .script_dir
  } else {
    app_dir <- getwd()
  }

  if (!grepl("01_Configure_Simulation", app_dir, fixed = TRUE)) {
    candidate <- file.path(app_dir, "20_GUI", "01_Configure_Simulation")
    if (dir.exists(candidate)) {
      app_dir <- normalizePath(candidate)
    } else {
      stop(
        "GUI_config.R: cannot locate '20_GUI/01_Configure_Simulation' ",
        "under '", app_dir, "'.  ",
        "Please run this script from the repo root or from the app folder."
      )
    }
  }

  repo_root <- normalizePath(file.path(app_dir, "..", ".."))
  config_path <- normalizePath(
    file.path(repo_root, input_path),
    winslash = "/",
    mustWork = TRUE
  )
}

# Collects every loading warning/notice generated below, shown to the
# user in a banner at the top of the app.
all_load_messages <- character(0)

# -------------------------------------------------------------
# 1. File paths (30_Simulation/02_Config/05_File_paths.csv)
# -------------------------------------------------------------
{
  default_file_names <- list(
    library_file                  = "01_Libraries.txt",
    needed_cols_file              = "02_Needed_cols.csv",
    parameter_validation_file     = "00_Validation/Parameter_config.csv",
    physical_properties_file      = "03_Physical_properties.csv",
    use_patterns_file             = "04_Use_Patterns.csv",
    model_file                    = "11_Model_parameters.csv",
    control_file                  = "12_Control_parameters.csv",
    setpoint_mode_file            = "13_Modes_setpoints.csv",
    optimization_file             = "14_Optimization_parameters.csv",
    market_file                   = "15_Market_config.csv",
    market_config_scheduling_file = "16_Market_config_scheduling.csv",
    market_config_piloting_file   = "17_Market_config_piloting.csv",
    reward_file                   = "18_Reward_parameters.csv",
    forecast_file                 = "19_Forecast_parameters.csv",
    energy_price_file             = "21_Energy_price_parameters.csv",
    flexibility_generation_file   = "22_Flexibility_generation_parameters.csv",
    debug_and_config_file         = "30_Debug_and_config.csv"
  )

  paths_file_name <- "05_File_paths.csv"
  paths_table <- tryCatch(
    suppressWarnings(read.csv(file.path(config_path, paths_file_name), comment.char = "#",
                              stringsAsFactors = FALSE, strip.white = TRUE)),
    error = function(e) NULL
  )

  if (is.null(paths_table) ||
      !all(c("key", "filename") %in% names(paths_table)) ||
      nrow(paths_table) == 0) {
    all_load_messages <- c(all_load_messages, sprintf(
      "Could not read '%s' (missing file or invalid columns). Using the default file paths.",
      paths_file_name
    ))
    paths <- default_file_names
  } else {
    loaded_paths <- setNames(
      as.list(trimws(as.character(paths_table$filename))),
      trimws(as.character(paths_table$key))
    )
    paths <- default_file_names
    for (key in names(default_file_names)) {
      if (!is.null(loaded_paths[[key]]) && nzchar(loaded_paths[[key]])) {
        paths[[key]] <- loaded_paths[[key]]
      } else {
        all_load_messages <- c(all_load_messages, sprintf(
          "'%s' is missing from %s. Using the default path '%s'.",
          key, paths_file_name, default_file_names[[key]]
        ))
      }
    }
  }

  file_names <- list(
    model        = paths$model_file,
    occupancy    = paths$use_patterns_file,
    control      = paths$control_file,
    modes        = paths$setpoint_mode_file,
    optimization = paths$optimization_file,
    market       = paths$market_file,
    sched        = paths$market_config_scheduling_file,
    pilot        = paths$market_config_piloting_file,
    reward       = paths$reward_file,
    forecast     = paths$forecast_file,
    energy_price = paths$energy_price_file,
    flex_generation = paths$flexibility_generation_file,
    debug        = paths$debug_and_config_file
  )

  rm(default_file_names, paths_file_name, paths_table)
}

# -------------------------------------------------------------
# 2. Validation rules (00_Validation/Parameter_config.csv).
# -------------------------------------------------------------
{
  validation_config <- tryCatch(
    suppressWarnings(read.csv(file.path(config_path, paths$parameter_validation_file),
                              comment.char = "#", stringsAsFactors = FALSE)),
    error = function(e) NULL
  )

  required_cols <- c("file_name", "parameter_name", "type", "output", "options")
  if (is.null(validation_config) || !all(required_cols %in% names(validation_config))) {
    all_load_messages <- c(all_load_messages, sprintf(
      "Could not read '%s'. Value validation is limited to basic checks.",
      paths$parameter_validation_file
    ))
    validation_config <- data.frame(
      file_name = character(0), parameter_name = character(0),
      type = character(0), output = character(0), options = character(0),
      stringsAsFactors = FALSE
    )
  }

  rm(required_cols)
}

# -------------------------------------------------------------
# 2.1. Parameter units (90_Structure/Parameter_Units.csv).
# -------------------------------------------------------------
# get_param_unit()/label_with_unit() are called by build_param_editor()
# and build_group_editor() below to append "[unit]" to every parameter
# label, per 00_Base_Criteria.md ("Units in graphic interfaces").
# -------------------------------------------------------------
{
  param_units_table <- tryCatch(
    suppressWarnings(read.csv(file.path(repo_root, "90_Structure", "Parameter_Units.csv"),
                              stringsAsFactors = FALSE)),
    error = function(e) NULL
  )

  get_param_unit <- function(file_key, param_name) {
    if (is.null(param_units_table)) {
      return("")
    }
    match_row <- param_units_table[
      param_units_table$file == file_key & param_units_table$parameter == param_name,
    ]
    if (nrow(match_row) != 1) {
      return("")
    }
    unit <- trimws(match_row$proposed_unit[1])
    if (unit == "-" || !nzchar(unit)) {
      return("")
    }
    unit
  }

  label_with_unit <- function(param_name, file_key) {
    unit <- get_param_unit(file_key, param_name)
    if (nzchar(unit)) {
      paste0(param_name, " [", unit, "]")
    } else {
      param_name
    }
  }
}

# -------------------------------------------------------------
# 3. Default values. These are never hard-coded in this script: they
#    live in 00_Validation/Default_<filename> files, one per
#    configuration file, mirroring its structure exactly, and are
#    read from disk through the same raw readers used for the real
#    files (section 5 below). Whenever a value is missing or invalid
#    in a real file, the matching entry from its Default_ file is
#    used instead.
# -------------------------------------------------------------
default_file_for <- function(filename) {
  file.path("00_Validation", paste0("Default_", basename(filename)))
}

# -------------------------------------------------------------
# 4. Validity checks (used both when loading, to decide what counts
#    as valid, and again right before saving).
# -------------------------------------------------------------
check_param_valid <- function(value, file_name, param_name, validation_config) {
  rules <- validation_config[
    trimws(as.character(validation_config$file_name)) == file_name &
      trimws(as.character(validation_config$parameter_name)) == param_name,
  ]

  value_char <- trimws(as.character(value))
  if (length(value_char) == 0 || is.na(value_char) || !nzchar(value_char)) {
    return(FALSE)
  }

  if (nrow(rules) == 0) {
    return(TRUE)
  }

  type        <- trimws(as.character(rules$type[1]))
  options_str <- trimws(as.character(rules$options[1]))

  if (type %in% c("Integer", "Real")) {
    value_num <- suppressWarnings(as.numeric(value_char))
    if (is.na(value_num)) return(FALSE)
    if (type == "Integer" && abs(value_num - round(value_num)) > 1e-9) return(FALSE)
    if (nzchar(options_str)) {
      range_vals <- suppressWarnings(as.numeric(trimws(strsplit(options_str, ",")[[1]])))
      if (length(range_vals) == 2 && !anyNA(range_vals) &&
          (value_num < range_vals[1] || value_num > range_vals[2])) {
        return(FALSE)
      }
    }
    return(TRUE)
  }

  if (type == "Options") {
    opts <- trimws(strsplit(options_str, ",")[[1]])
    return(value_char %in% opts)
  }

  TRUE
}

validate_param_df_gui <- function(df, file_label, validation_config) {
  errors <- character(0)
  for (CONT_101 in seq_len(nrow(df))) {
    pname <- trimws(as.character(df$parameter[CONT_101]))
    pval  <- trimws(as.character(df$value[CONT_101]))
    if (!check_param_valid(pval, file_label, pname, validation_config)) {
      errors <- c(errors, sprintf(
        "%s: the value of '%s' ('%s') is not valid.", file_label, pname, pval
      ))
    }
  }
  errors
}

modes_row_valid <- function(mode_val, heating_val, cooling_val) {
  !is.na(suppressWarnings(as.numeric(mode_val))) &&
    !is.na(suppressWarnings(as.numeric(heating_val))) &&
    !is.na(suppressWarnings(as.numeric(cooling_val)))
}

validate_modes_df_gui <- function(df) {
  errors <- character(0)
  for (CONT_102 in seq_len(nrow(df))) {
    heating_num <- suppressWarnings(as.numeric(df$heating[CONT_102]))
    cooling_num <- suppressWarnings(as.numeric(df$cooling[CONT_102]))
    if (is.na(heating_num) || is.na(cooling_num)) {
      errors <- c(errors, sprintf(
        "Modes: row %d has non-numeric values (heating='%s', cooling='%s').",
        CONT_102, df$heating[CONT_102], df$cooling[CONT_102]
      ))
    }
  }
  errors
}

market_table_row_valid <- function(closure, begin, end, end_optimization, aim) {
  nums <- suppressWarnings(as.numeric(c(closure, begin, end, end_optimization)))
  if (anyNA(nums) || any(nums < 0)) return(FALSE)
  trimws(as.character(aim)) %in% c("O", "E", "O+F", "E+F")
}

validate_market_table_df_gui <- function(df, file_label) {
  errors <- character(0)
  for (CONT_103 in seq_len(nrow(df))) {
    if (!market_table_row_valid(df$closure[CONT_103], df$begin[CONT_103],
                                df$end[CONT_103], df$end_optimization[CONT_103],
                                df$aim[CONT_103])) {
      errors <- c(errors, sprintf(
        "%s: the row for market '%s' has invalid values.",
        file_label, df$Market[CONT_103]
      ))
    }
  }
  errors
}

day_type_row_valid <- function(row_values) {
  nums <- suppressWarnings(as.numeric(unlist(row_values)))
  !anyNA(nums) && all(nums %in% c(0, 1))
}

validate_occupancy_dfs_gui <- function(day_types_df, month_profiles_df) {
  errors        <- character(0)
  hour_cols     <- paste0("H", sprintf("%02d", 1:24))
  weekday_cols  <- paste0("D", sprintf("%02d", 1:7))

  for (CONT_104 in seq_len(nrow(day_types_df))) {
    if (!day_type_row_valid(day_types_df[CONT_104, hour_cols])) {
      errors <- c(errors, sprintf(
        "Occupancy: hourly profile '%s' contains values other than 0/1.",
        day_types_df$TYPE[CONT_104]
      ))
    }
  }

  valid_types <- trimws(as.character(day_types_df$TYPE))
  for (CONT_105 in seq_len(nrow(month_profiles_df))) {
    refs <- trimws(as.character(unlist(month_profiles_df[CONT_105, weekday_cols])))
    if (!all(refs %in% valid_types)) {
      errors <- c(errors, sprintf(
        "Occupancy: month '%s' references a nonexistent hourly profile.",
        month_profiles_df$MONTH[CONT_105]
      ))
    }
  }

  errors
}

# -------------------------------------------------------------
# 5. Raw CSV readers (no error handling / no defaulting - used only
#    inside the safe loaders below, which add both).
# -------------------------------------------------------------
read_param_file <- function(filename) {
  read.csv(
    file.path(config_path, filename),
    comment.char     = "#",
    stringsAsFactors = FALSE,
    strip.white      = TRUE
  )
}

read_table_file <- function(filename) {
  df <- read.csv(
    file.path(config_path, filename),
    comment.char     = "#",
    stringsAsFactors = FALSE,
    strip.white      = TRUE
  )
  label_col <- intersect(c("Market", "mode"), names(df))[1]
  if (nrow(df) > 0 && !is.na(label_col)) {
    first_label_value <- tolower(trimws(as.character(df[[label_col]][1])))
    if (identical(first_label_value, "text")) {
      df <- df[-1, , drop = FALSE]
    }
  }
  df
}

read_use_patterns_file <- function(filename) {
  full_path <- file.path(config_path, filename)
  raw_lines <- readLines(full_path, warn = FALSE)
  raw_lines <- raw_lines[
    !grepl("^\\s*#", raw_lines) & nzchar(trimws(raw_lines))
  ]

  type_header_idx <- which(grepl("^\\s*TYPE\\s*,",
                                 raw_lines,
                                 ignore.case = TRUE))[1]
  month_header_idx <- which(grepl("^\\s*MONTH\\s*,",
                                  raw_lines,
                                  ignore.case = TRUE))[1]

  if (is.na(type_header_idx) || is.na(month_header_idx)) {
    stop("04_Use_Patterns.csv must contain TYPE and MONTH table headers")
  }

  type_lines  <- raw_lines[type_header_idx:(month_header_idx - 1)]
  month_lines <- raw_lines[month_header_idx:length(raw_lines)]

  day_types <- read.csv(
    text             = paste(type_lines, collapse = "\n"),
    stringsAsFactors = FALSE,
    strip.white      = TRUE
  )
  month_profiles <- read.csv(
    text             = paste(month_lines, collapse = "\n"),
    stringsAsFactors = FALSE,
    strip.white      = TRUE
  )

  if (nrow(day_types) > 0 &&
      tolower(trimws(as.character(day_types$TYPE[1]))) == "text") {
    day_types <- day_types[-1, , drop = FALSE]
  }
  if (nrow(month_profiles) > 0 &&
      tolower(trimws(as.character(month_profiles$MONTH[1]))) == "text") {
    month_profiles <- month_profiles[-1, , drop = FALSE]
  }

  list(day_types = day_types, month_profiles = month_profiles)
}

# -------------------------------------------------------------
# 6. Safe loaders: read a file, validate what's there, keep whatever
#    is valid, flag duplicated parameters, and replace whatever is
#    missing/invalid with the matching Default_ file entry
#    (collecting a human-readable message for every substitution).
#    If the Default_ file itself cannot be read, no built-in R
#    fallback is used: the raw file contents are loaded as-is and a
#    loud warning explains that no reconciliation was possible.
# -------------------------------------------------------------
load_default_param_list <- function(default_filename) {
  df <- tryCatch(suppressWarnings(read_param_file(default_filename)), error = function(e) NULL)
  if (is.null(df) || !all(c("parameter", "value") %in% names(df)) || nrow(df) == 0) {
    return(NULL)
  }
  setNames(trimws(as.character(df$value)), trimws(as.character(df$parameter)))
}

load_param_file_safe <- function(filename, file_label, default_filename, validation_config) {
  messages <- character(0)
  df <- tryCatch(suppressWarnings(read_param_file(filename)), error = function(e) NULL)
  file_ok <- !is.null(df) && all(c("parameter", "value") %in% names(df))

  if (!file_ok) {
    messages <- c(messages, sprintf(
      "Could not read '%s' (missing file or invalid format).",
      filename
    ))
    df <- data.frame(parameter = character(0), value = character(0),
                     stringsAsFactors = FALSE)
  }

  # ---- Duplicate parameter detection: keep the first occurrence ----
  duplicated_params <- character(0)
  if (nrow(df) > 0) {
    param_col <- trimws(as.character(df$parameter))
    dup_names <- unique(param_col[duplicated(param_col)])
    for (pname in dup_names) {
      duplicated_params <- c(duplicated_params, pname)
      first_val <- trimws(as.character(df$value[param_col == pname]))[1]
      messages <- c(messages, sprintf(
        "%s: parameter '%s' is duplicated in the file. Using its first value ('%s').",
        filename, pname, first_val
      ))
    }
  }

  defaults <- load_default_param_list(default_filename)

  if (is.null(defaults)) {
    messages <- c(messages, sprintf(
      "Default values file '%s' could not be read, so missing or invalid values in '%s' cannot be reconciled. Loading the file contents as-is.",
      default_filename, filename
    ))
    return(list(df = df, defaulted = character(0), duplicated = duplicated_params,
                messages = messages))
  }

  param_names   <- names(defaults)
  final_values  <- character(length(param_names))
  defaulted     <- character(0)

  for (CONT_201 in seq_along(param_names)) {
    pname    <- param_names[CONT_201]
    existing <- df$value[trimws(as.character(df$parameter)) == pname]
    use_default <- TRUE

    if (length(existing) >= 1) {
      candidate <- trimws(as.character(existing[1]))
      if (check_param_valid(candidate, file_label, pname, validation_config)) {
        final_values[CONT_201] <- candidate
        use_default <- FALSE
      }
    }

    if (use_default) {
      final_values[CONT_201] <- defaults[[pname]]
      defaulted <- c(defaulted, pname)
      if (length(existing) == 0) {
        messages <- c(messages, sprintf(
          "%s: parameter '%s' is missing. Using its default value (%s).",
          filename, pname, defaults[[pname]]
        ))
      } else {
        messages <- c(messages, sprintf(
          "%s: parameter '%s' has an invalid value ('%s'). Using its default value (%s).",
          filename, pname, existing[1], defaults[[pname]]
        ))
      }
    }
  }

  list(
    df = data.frame(parameter = param_names, value = final_values,
                    stringsAsFactors = FALSE),
    defaulted = defaulted,
    duplicated = duplicated_params,
    messages  = messages
  )
}

load_modes_file_safe <- function(filename, default_filename) {
  messages <- character(0)
  df <- tryCatch(suppressWarnings(read_table_file(filename)), error = function(e) NULL)

  defaults_df <- tryCatch(suppressWarnings(read_table_file(default_filename)), error = function(e) NULL)
  defaults_ok <- !is.null(defaults_df) &&
    all(c("mode", "heating", "cooling") %in% names(defaults_df)) &&
    nrow(defaults_df) > 0
  if (!defaults_ok) {
    messages <- c(messages, sprintf(
      "Default modes file '%s' could not be read; no defaults are available for '%s'.",
      default_filename, filename
    ))
  }

  file_ok <- !is.null(df) && all(c("mode", "heating", "cooling") %in% names(df)) && nrow(df) > 0
  if (!file_ok) {
    messages <- c(messages, sprintf(
      "Could not read '%s' (missing, empty file, or invalid columns).%s",
      filename,
      if (defaults_ok) " Loading the default modes instead." else ""
    ))
    if (defaults_ok) {
      return(list(df = defaults_df, defaulted_rows = seq_len(nrow(defaults_df)),
                  messages = messages))
    }
    return(list(
      df = data.frame(mode = character(0), heating = character(0),
                      cooling = character(0), stringsAsFactors = FALSE),
      defaulted_rows = integer(0), messages = messages
    ))
  }

  if (!defaults_ok) {
    return(list(df = df, defaulted_rows = integer(0), messages = messages))
  }

  n_rows <- max(nrow(df), nrow(defaults_df))
  result <- data.frame(
    mode = character(n_rows), heating = character(n_rows),
    cooling = character(n_rows), stringsAsFactors = FALSE
  )
  defaulted_rows <- integer(0)

  for (CONT_202 in seq_len(n_rows)) {
    has_loaded  <- CONT_202 <= nrow(df)
    has_default <- CONT_202 <= nrow(defaults_df)

    if (has_loaded && modes_row_valid(df$mode[CONT_202], df$heating[CONT_202],
                                       df$cooling[CONT_202])) {
      result$mode[CONT_202]    <- as.character(df$mode[CONT_202])
      result$heating[CONT_202] <- as.character(df$heating[CONT_202])
      result$cooling[CONT_202] <- as.character(df$cooling[CONT_202])
    } else if (has_default) {
      result$mode[CONT_202]    <- as.character(defaults_df$mode[CONT_202])
      result$heating[CONT_202] <- as.character(defaults_df$heating[CONT_202])
      result$cooling[CONT_202] <- as.character(defaults_df$cooling[CONT_202])
      defaulted_rows <- c(defaulted_rows, CONT_202)
      messages <- c(messages, sprintf(
        "%s: row %d is missing or invalid. Using its default mode (heating=%s, cooling=%s).",
        filename, CONT_202, defaults_df$heating[CONT_202], defaults_df$cooling[CONT_202]
      ))
    } else {
      result$mode[CONT_202]    <- as.character(CONT_202)
      result$heating[CONT_202] <- "21"
      result$cooling[CONT_202] <- "25"
      defaulted_rows <- c(defaulted_rows, CONT_202)
      messages <- c(messages, sprintf(
        "%s: row %d is invalid. Using a generic mode instead (heating=21, cooling=25).",
        filename, CONT_202
      ))
    }
  }

  list(df = result, defaulted_rows = defaulted_rows, messages = messages)
}

load_market_table_file_safe <- function(filename, default_filename, fallback_aim) {
  messages <- character(0)
  req_cols <- c("Market", "closure", "begin", "end", "end_optimization", "aim")
  df <- tryCatch(suppressWarnings(read_table_file(filename)), error = function(e) NULL)

  defaults_df <- tryCatch(suppressWarnings(read_table_file(default_filename)), error = function(e) NULL)
  defaults_ok <- !is.null(defaults_df) && all(req_cols %in% names(defaults_df)) &&
    nrow(defaults_df) > 0
  if (!defaults_ok) {
    messages <- c(messages, sprintf(
      "Default markets file '%s' could not be read; no defaults are available for '%s'.",
      default_filename, filename
    ))
  }

  file_ok <- !is.null(df) && all(req_cols %in% names(df)) && nrow(df) > 0
  if (!file_ok) {
    messages <- c(messages, sprintf(
      "Could not read '%s' (missing, empty file, or invalid columns).%s",
      filename,
      if (defaults_ok) " Loading the default markets instead." else ""
    ))
    if (defaults_ok) {
      return(list(df = defaults_df, defaulted_rows = seq_len(nrow(defaults_df)),
                  messages = messages))
    }
    return(list(
      df = data.frame(Market = character(0), closure = character(0),
                      begin = character(0), end = character(0),
                      end_optimization = character(0), aim = character(0),
                      stringsAsFactors = FALSE),
      defaulted_rows = integer(0), messages = messages
    ))
  }

  if (!defaults_ok) {
    return(list(df = df, defaulted_rows = integer(0), messages = messages))
  }

  df$Market <- trimws(as.character(df$Market))

  result_rows        <- list()
  defaulted_markets   <- character(0)

  for (CONT_203 in seq_len(nrow(df))) {
    market_name <- df$Market[CONT_203]
    if (market_table_row_valid(df$closure[CONT_203], df$begin[CONT_203],
                               df$end[CONT_203], df$end_optimization[CONT_203],
                               df$aim[CONT_203])) {
      result_rows[[market_name]] <- df[CONT_203, req_cols]
    } else {
      default_match <- defaults_df[defaults_df$Market == market_name, ]
      if (nrow(default_match) == 1) {
        result_rows[[market_name]] <- default_match
        messages <- c(messages, sprintf(
          "%s: the row for market '%s' is invalid. Using its default value.",
          filename, market_name
        ))
      } else {
        result_rows[[market_name]] <- data.frame(
          Market = market_name, closure = 1, begin = 0, end = 24,
          end_optimization = 6, aim = fallback_aim, stringsAsFactors = FALSE
        )
        messages <- c(messages, sprintf(
          "%s: the row for market '%s' is invalid and has no known default. Using a generic configuration instead.",
          filename, market_name
        ))
      }
      defaulted_markets <- c(defaulted_markets, market_name)
    }
  }

  missing_markets <- setdiff(defaults_df$Market, names(result_rows))
  for (market_name in missing_markets) {
    result_rows[[market_name]] <- defaults_df[defaults_df$Market == market_name, ]
    defaulted_markets <- c(defaulted_markets, market_name)
    messages <- c(messages, sprintf(
      "%s: market '%s' is missing. Adding it with its default configuration.",
      filename, market_name
    ))
  }

  result_df <- do.call(rbind, result_rows)
  rownames(result_df) <- NULL
  defaulted_rows <- which(result_df$Market %in% defaulted_markets)

  list(df = result_df, defaulted_rows = defaulted_rows, messages = messages)
}

load_occupancy_file_safe <- function(filename, default_filename) {
  messages     <- character(0)
  hour_cols    <- paste0("H", sprintf("%02d", 1:24))
  weekday_cols <- paste0("D", sprintf("%02d", 1:7))

  default_dfs <- tryCatch(suppressWarnings(read_use_patterns_file(default_filename)), error = function(e) NULL)
  defaults_ok <- !is.null(default_dfs) && !is.null(default_dfs$day_types) &&
    !is.null(default_dfs$month_profiles) &&
    all(c("TYPE", hour_cols) %in% names(default_dfs$day_types)) &&
    all(c("MONTH", weekday_cols) %in% names(default_dfs$month_profiles))
  if (!defaults_ok) {
    messages <- c(messages, sprintf(
      "Default occupancy file '%s' could not be read; no defaults are available for '%s'.",
      default_filename, filename
    ))
  }

  dfs <- tryCatch(suppressWarnings(read_use_patterns_file(filename)), error = function(e) NULL)
  file_ok <- !is.null(dfs) && !is.null(dfs$day_types) && !is.null(dfs$month_profiles) &&
    all(c("TYPE", hour_cols) %in% names(dfs$day_types)) &&
    all(c("MONTH", weekday_cols) %in% names(dfs$month_profiles))

  if (!file_ok) {
    messages <- c(messages, sprintf(
      "Could not read '%s' (missing file or invalid format).%s",
      filename,
      if (defaults_ok) " Loading the default occupancy profiles instead." else ""
    ))
    if (defaults_ok) {
      return(list(
        day_types = default_dfs$day_types,
        month_profiles = default_dfs$month_profiles,
        defaulted_type_rows = seq_len(nrow(default_dfs$day_types)),
        defaulted_month_rows = seq_len(nrow(default_dfs$month_profiles)),
        messages = messages
      ))
    }
    return(list(
      day_types = data.frame(TYPE = character(0), stringsAsFactors = FALSE),
      month_profiles = data.frame(MONTH = character(0), stringsAsFactors = FALSE),
      defaulted_type_rows = integer(0),
      defaulted_month_rows = integer(0),
      messages = messages
    ))
  }

  if (!defaults_ok) {
    return(list(
      day_types = dfs$day_types,
      month_profiles = dfs$month_profiles,
      defaulted_type_rows = integer(0),
      defaulted_month_rows = integer(0),
      messages = messages
    ))
  }

  default_day_types      <- default_dfs$day_types
  default_month_profiles <- default_dfs$month_profiles

  # ---- TYPE table ----
  day_df <- dfs$day_types
  day_df$TYPE <- trimws(as.character(day_df$TYPE))

  type_rows       <- list()
  defaulted_types <- character(0)
  for (CONT_204 in seq_len(nrow(day_df))) {
    type_name <- day_df$TYPE[CONT_204]
    if (day_type_row_valid(day_df[CONT_204, hour_cols])) {
      type_rows[[type_name]] <- day_df[CONT_204, c("TYPE", hour_cols)]
    } else {
      default_match <- default_day_types[default_day_types$TYPE == type_name, ]
      if (nrow(default_match) == 1) {
        type_rows[[type_name]] <- default_match
      } else {
        type_rows[[type_name]] <- data.frame(
          TYPE = type_name,
          as.list(setNames(rep("0", 24), hour_cols)),
          stringsAsFactors = FALSE
        )
      }
      defaulted_types <- c(defaulted_types, type_name)
      messages <- c(messages, sprintf(
        "%s: hourly profile '%s' is invalid (values other than 0/1). Using its default value.",
        filename, type_name
      ))
    }
  }
  missing_types <- setdiff(default_day_types$TYPE, names(type_rows))
  for (type_name in missing_types) {
    type_rows[[type_name]] <- default_day_types[default_day_types$TYPE == type_name, ]
    defaulted_types <- c(defaulted_types, type_name)
    messages <- c(messages, sprintf(
      "%s: hourly profile '%s' is missing. Adding it with its default value.",
      filename, type_name
    ))
  }
  day_types_result <- do.call(rbind, type_rows)
  rownames(day_types_result) <- NULL
  defaulted_type_rows <- which(day_types_result$TYPE %in% defaulted_types)

  # ---- MONTH table (validated against the just-resolved TYPE set) ----
  month_df <- dfs$month_profiles
  month_df$MONTH <- trimws(as.character(month_df$MONTH))
  valid_types <- day_types_result$TYPE

  month_rows       <- list()
  defaulted_months <- character(0)
  for (CONT_205 in seq_len(nrow(month_df))) {
    month_name <- month_df$MONTH[CONT_205]
    refs <- trimws(as.character(unlist(month_df[CONT_205, weekday_cols])))
    if (all(refs %in% valid_types)) {
      month_rows[[month_name]] <- month_df[CONT_205, c("MONTH", weekday_cols)]
    } else {
      default_match <- default_month_profiles[default_month_profiles$MONTH == month_name, ]
      if (nrow(default_match) == 1) {
        month_rows[[month_name]] <- default_match
      } else {
        month_rows[[month_name]] <- data.frame(
          MONTH = month_name,
          as.list(setNames(rep(valid_types[1], 7), weekday_cols)),
          stringsAsFactors = FALSE
        )
      }
      defaulted_months <- c(defaulted_months, month_name)
      messages <- c(messages, sprintf(
        "%s: monthly mapping '%s' references a nonexistent hourly profile. Using its default value.",
        filename, month_name
      ))
    }
  }
  missing_months <- setdiff(default_month_profiles$MONTH, names(month_rows))
  for (month_name in missing_months) {
    month_rows[[month_name]] <- default_month_profiles[default_month_profiles$MONTH == month_name, ]
    defaulted_months <- c(defaulted_months, month_name)
    messages <- c(messages, sprintf(
      "%s: month '%s' is missing. Adding it with its default value.",
      filename, month_name
    ))
  }
  month_profiles_result <- do.call(rbind, month_rows)
  rownames(month_profiles_result) <- NULL
  defaulted_month_rows <- which(month_profiles_result$MONTH %in% defaulted_months)

  list(
    day_types = day_types_result,
    month_profiles = month_profiles_result,
    defaulted_type_rows = defaulted_type_rows,
    defaulted_month_rows = defaulted_month_rows,
    messages = messages
  )
}

# -------------------------------------------------------------
# 7. Writers (unchanged: always write the current, already-validated
#    reactive state).
# -------------------------------------------------------------
write_use_patterns_file <- function(
    filename,
    day_types_df,
    month_profiles_df
) {
  con <- file(file.path(config_path, filename), open = "wt")
  on.exit(close(con), add = TRUE)

  writeLines(
    c(
      "# Occupancy use patterns configuration file",
      "# -------------------------------------------------------------",
      "# Day type profiles by hour"
    ),
    con
  )

  write.csv(
    rbind(
      setNames(
        as.data.frame(
          as.list(c("text", rep("0/1", max(0, ncol(day_types_df) - 1)))),
          stringsAsFactors = FALSE
        ),
        names(day_types_df)
      ),
      day_types_df
    ),
    con,
    row.names = FALSE,
    quote = FALSE
  )

  writeLines(
    c(
      "",
      "# -------------------------------------------------------------",
      "# Monthly mapping by weekday (D01 = Monday, D07 = Sunday)"
    ),
    con
  )

  write.csv(
    rbind(
      setNames(
        as.data.frame(
          as.list(c("text", rep("profile",
                                 max(0, ncol(month_profiles_df) - 1)))),
          stringsAsFactors = FALSE
        ),
        names(month_profiles_df)
      ),
      month_profiles_df
    ),
    con,
    row.names = FALSE,
    quote = FALSE
  )
}

write_param_file <- function(filename, header, df) {
  con <- file(file.path(config_path, filename), open = "wt")
  on.exit(close(con), add = TRUE)

  writeLines(header, con)
  write.csv(df, con, row.names = FALSE, quote = FALSE)
}

write_table_file <- function(filename, header, df) {
  con <- file(file.path(config_path, filename), open = "wt")
  on.exit(close(con), add = TRUE)

  writeLines(header, con)
  write.csv(df, con, row.names = FALSE, quote = FALSE)
}

get_param_value <- function(df, param) {
  value <- df$value[df$parameter == param]
  if (length(value) == 0) {
    return("")
  }
  as.character(value[1])
}

update_df_from_inputs <- function(df, prefix, input) {
  for (CONT_001 in seq_len(nrow(df))) {
    param_name <- as.character(df$parameter[CONT_001])
    input_id   <- paste0(prefix, param_name)
    if (!is.null(input[[input_id]])) {
      df$value[CONT_001] <- as.character(input[[input_id]])
    }
  }
  df
}

insert_row <- function(df, index, template_row) {
  if (nrow(df) == 0) {
    return(template_row)
  }

  index <- max(1, min(index, nrow(df) + 1))

  if (index == 1) {
    return(rbind(template_row, df))
  }

  if (index == nrow(df) + 1) {
    return(rbind(df, template_row))
  }

  rbind(
    df[1:(index - 1), , drop = FALSE],
    template_row,
    df[index:nrow(df), , drop = FALSE]
  )
}

add_row_controls <- function(df, prefix) {
  if (nrow(df) == 0) {
    df <- data.frame(stringsAsFactors = FALSE)
  }

  n_rows <- nrow(df)
  if (n_rows > 0) {
    df$`Add above` <- sprintf(
      "<a href='#' onclick=\"Shiny.setInputValue('%s_add_above', %d, {priority: 'event'});\">Add above</a>",
      prefix,
      seq_len(n_rows)
    )
    df$`Add below` <- sprintf(
      "<a href='#' onclick=\"Shiny.setInputValue('%s_add_below', %d, {priority: 'event'});\">Add below</a>",
      prefix,
      seq_len(n_rows)
    )
    df$`Delete` <- sprintf(
      "<a href='#' onclick=\"Shiny.setInputValue('%s_delete', %d, {priority: 'event'});\">Delete</a>",
      prefix,
      seq_len(n_rows)
    )
  }

  df
}

escape_html_attr <- function(value) {
  value <- as.character(value)
  value <- gsub("&", "&amp;", value, fixed = TRUE)
  value <- gsub("\"", "&quot;", value, fixed = TRUE)
  value <- gsub("<", "&lt;", value, fixed = TRUE)
  value <- gsub(">", "&gt;", value, fixed = TRUE)
  value
}

# Wraps an input label in red, plus a small note, whenever the
# parameter's current value came from the built-in defaults rather
# than from the configuration file on disk, and/or the parameter name
# was duplicated in the file (in which case the first value found is
# the one shown/used).
render_label <- function(label, is_default, is_duplicate = FALSE) {
  if (isTRUE(is_default) || isTRUE(is_duplicate)) {
    note <- if (isTRUE(is_default) && isTRUE(is_duplicate)) {
      " (default value; duplicated parameter)"
    } else if (isTRUE(is_default)) {
      " (default value)"
    } else {
      " (duplicated parameter, first value used)"
    }
    tags$span(
      style = "color:#c0392b; font-weight:600;",
      label,
      tags$em(note, style = "font-weight:400; font-size:85%;")
    )
  } else {
    label
  }
}

build_input_grid <- function(input_defs, max_per_row = 4) {
  if (length(input_defs) == 0) {
    return(NULL)
  }

  row_groups <- split(
    input_defs,
    ceiling(seq_along(input_defs) / max_per_row)
  )

  tags$div(
    lapply(
      row_groups,
      function(row_items) {
        fluidRow(
          lapply(
            row_items,
            function(item) {
              column(
                width = floor(12 / max_per_row),
                if (!is.null(item$options)) {
                  selectInput(
                    inputId  = item$id,
                    label    = render_label(item$label, item$is_default, item$is_duplicate),
                    choices  = item$options,
                    selected = item$value
                  )
                } else {
                  textInput(
                    inputId = item$id,
                    label   = render_label(item$label, item$is_default, item$is_duplicate),
                    value   = item$value
                  )
                }
              )
            }
          )
        )
      }
    )
  )
}

build_param_editor <- function(df, prefix, max_per_row = 1, options_list = list(),
                                defaulted = character(0), duplicated = character(0),
                                file_key = NULL) {
  input_defs <- lapply(
    seq_len(nrow(df)),
    function(CONT_002) {
      param_name <- as.character(df$parameter[CONT_002])
      list(
        id           = paste0(prefix, param_name),
        label        = if (is.null(file_key)) param_name else label_with_unit(param_name, file_key),
        value        = as.character(df$value[CONT_002]),
        options      = options_list[[param_name]],
        is_default   = param_name %in% defaulted,
        is_duplicate = param_name %in% duplicated
      )
    }
  )

  if (max_per_row <= 1) {
    return(
      tags$div(
        lapply(
          input_defs,
          function(item) {
            if (!is.null(item$options)) {
              selectInput(
                inputId  = item$id,
                label    = render_label(item$label, item$is_default),
                choices  = item$options,
                selected = item$value
              )
            } else {
              textInput(
                inputId = item$id,
                label   = render_label(item$label, item$is_default),
                value   = item$value
              )
            }
          }
        )
      )
    )
  }

  build_input_grid(input_defs, max_per_row = max_per_row)
}

build_group_editor <- function(df, prefix, title, parameters, options_list = list(),
                                defaulted = character(0), duplicated = character(0),
                                file_key = NULL) {
  input_defs <- lapply(
    parameters,
    function(CONT_003) {
      list(
        id           = paste0(prefix, CONT_003),
        label        = if (is.null(file_key)) CONT_003 else label_with_unit(CONT_003, file_key),
        value        = get_param_value(df, CONT_003),
        options      = options_list[[CONT_003]],
        is_default   = CONT_003 %in% defaulted,
        is_duplicate = CONT_003 %in% duplicated
      )
    }
  )

  wellPanel(
    h4(title),
    build_input_grid(input_defs, max_per_row = 4)
  )
}

build_table_cell_inputs <- function(df, prefix, defaulted_rows = integer(0),
                                     readonly_cols = character(0)) {
  if (nrow(df) == 0) {
    return(add_row_controls(df, prefix))
  }

  data_cols <- names(df)
  for (col_name in data_cols) {
    if (col_name %in% readonly_cols) {
      df[[col_name]] <- as.character(df[[col_name]])
      next
    }
    df[[col_name]] <- mapply(
      function(cell_value, row_idx) {
        cell_style <- if (row_idx %in% defaulted_rows) {
          " style=\"color:#c0392b; font-weight:600;\""
        } else {
          ""
        }
        sprintf(
          "<input type='text' class='form-control input-sm table-cell-input' data-prefix='%s' data-row='%d' data-col='%s' value=\"%s\"%s/>",
          prefix,
          row_idx,
          col_name,
          escape_html_attr(cell_value),
          cell_style
        )
      },
      df[[col_name]],
      seq_len(nrow(df)),
      USE.NAMES = FALSE
    )
  }

  add_row_controls(df, prefix)
}

apply_text_table_edit <- function(df, edit_info) {
  if (is.null(edit_info)) {
    return(df)
  }

  row_idx  <- as.integer(edit_info$row)
  col_name <- as.character(edit_info$col)

  if (!is.na(row_idx) &&
      row_idx >= 1 &&
      row_idx <= nrow(df) &&
      col_name %in% names(df)) {
    df[row_idx, col_name] <- as.character(edit_info$value)
  }

  df
}

flush_table_edits <- function(rv, input) {
  rv$modes <- apply_text_table_edit(
    rv$modes,
    input$modes_cell_text_edit
  )
  rv$occupancy_type <- apply_text_table_edit(
    rv$occupancy_type,
    input$occupancy_type_cell_text_edit
  )
  rv$occupancy_month <- apply_text_table_edit(
    rv$occupancy_month,
    input$occupancy_month_cell_text_edit
  )
  rv$sched <- apply_text_table_edit(
    rv$sched,
    input$sched_cell_text_edit
  )
  rv$pilot <- apply_text_table_edit(
    rv$pilot,
    input$pilot_cell_text_edit
  )
}

table_input_callback <- JS(
  "table.on('change', 'input.table-cell-input', function() {",
  "  var input = $(this);",
  "  Shiny.setInputValue(input.data('prefix') + '_cell_text_edit', {",
  "    row: parseInt(input.data('row'), 10),",
  "    col: input.data('col'),",
  "    value: input.val(),",
  "    nonce: Math.random()",
  "  }, {priority: 'event'});",
  "});"
)

# -------------------------------------------------------------
# 8. Initial (safe) loading of every configuration file.
# -------------------------------------------------------------
# load_param_file_safe() is called once per flat "parameter,value"
# configuration file, reconciling it against its Default_<file>
# counterpart so a missing/invalid entry never stops the app - the
# same call pattern repeats for every tab below.
model_load        <- load_param_file_safe(file_names$model, "11_Model_parameters.csv",
                                          default_file_for(file_names$model), validation_config)
control_load      <- load_param_file_safe(file_names$control, "12_Control_parameters.csv",
                                          default_file_for(file_names$control), validation_config)
optimization_load <- load_param_file_safe(file_names$optimization, "14_Optimization_parameters.csv",
                                          default_file_for(file_names$optimization), validation_config)
market_load       <- load_param_file_safe(file_names$market, "15_Market_config.csv",
                                          default_file_for(file_names$market), validation_config)
reward_load       <- load_param_file_safe(file_names$reward, "18_Reward_parameters.csv",
                                          default_file_for(file_names$reward), validation_config)
forecast_load     <- load_param_file_safe(file_names$forecast, "19_Forecast_parameters.csv",
                                          default_file_for(file_names$forecast), validation_config)
energy_price_load <- load_param_file_safe(file_names$energy_price, "21_Energy_price_parameters.csv",
                                          default_file_for(file_names$energy_price), validation_config)
flex_generation_load <- load_param_file_safe(file_names$flex_generation,
                                          "22_Flexibility_generation_parameters.csv",
                                          default_file_for(file_names$flex_generation), validation_config)
debug_load        <- load_param_file_safe(file_names$debug, "30_Debug_and_config.csv",
                                          default_file_for(file_names$debug), validation_config)
# The four remaining tables (modes, the two market schedules, and
# occupancy) each have their own row-level safe loader instead of
# load_param_file_safe(), since a row (not a single value) is the
# reconciliation unit for these.
modes_load        <- load_modes_file_safe(file_names$modes, default_file_for(file_names$modes))
sched_load        <- load_market_table_file_safe(file_names$sched, default_file_for(file_names$sched), "E")
pilot_load        <- load_market_table_file_safe(file_names$pilot, default_file_for(file_names$pilot), "O")
occupancy_load    <- load_occupancy_file_safe(file_names$occupancy, default_file_for(file_names$occupancy))

model_df           <- model_load$df
control_df         <- control_load$df
optimization_df    <- optimization_load$df
market_df          <- market_load$df
reward_df          <- reward_load$df
forecast_df        <- forecast_load$df
energy_price_df    <- energy_price_load$df
flex_generation_df <- flex_generation_load$df
debug_df           <- debug_load$df
modes_df           <- modes_load$df
sched_df           <- sched_load$df
pilot_df           <- pilot_load$df
occupancy_type_df  <- occupancy_load$day_types
occupancy_month_df <- occupancy_load$month_profiles

all_load_messages <- c(
  all_load_messages,
  model_load$messages, control_load$messages, optimization_load$messages,
  market_load$messages, reward_load$messages, forecast_load$messages,
  energy_price_load$messages,
  flex_generation_load$messages, debug_load$messages, modes_load$messages,
  sched_load$messages, pilot_load$messages, occupancy_load$messages
)

load_warning_banner <- if (length(all_load_messages) > 0) {
  tags$div(
    style = paste(
      "background:#fff3cd; border:1px solid #ffeeba; color:#856404;",
      "padding:12px 15px; margin-bottom:15px; border-radius:4px;"
    ),
    tags$strong("Configuration loading notice:"),
    tags$ul(lapply(all_load_messages, function(m) tags$li(m)))
  )
} else {
  NULL
}

ui <- fluidPage(
  useShinyjs(),
  titlePanel("MPC simulation configuration"),
  load_warning_banner,
  tabsetPanel(
    tabPanel(
      "Model",
      build_group_editor(
        model_df,
        "model__",
        "Building Inertia",
        c("Ci", "Ce", "Rie", "Rea", "Aw", "Ae"),
        defaulted = model_load$defaulted,
        duplicated = model_load$duplicated,
        file_key = "11_Model_parameters.csv"
      ),
      build_group_editor(
        model_df,
        "model__",
        "Shading",
        c("Shading_0", "Shading_1", "Setpoint_Shading1"),
        defaulted = model_load$defaulted,
        duplicated = model_load$duplicated,
        file_key = "11_Model_parameters.csv"
      ),
      build_group_editor(
        model_df,
        "model__",
        "Heat Pump",
        c("AT_hp_heat_1", "AT_hp_heat_2", "Q_hp_heat_1", "Q_hp_heat_2",
          "COP_hp_heat_1_coef1", "COP_hp_heat_1_coef2",
          "COP_hp_heat_1_coef3", "Tsup_hp_heat", "Q_hp_cool",
          "COP_hp_cool"),
        defaulted = model_load$defaulted,
        duplicated = model_load$duplicated,
        file_key = "11_Model_parameters.csv"
      ),
      build_group_editor(
        model_df,
        "model__",
        "Ventilation",
        c("RENvent01", "RENvent1", "RENvent2",
          "Setpoint_Rvent1", "Volume", "Efi_Vent_Rec"),
        defaulted = model_load$defaulted,
        duplicated = model_load$duplicated,
        file_key = "11_Model_parameters.csv"
      ),
      build_group_editor(
        model_df,
        "model__",
        "Initialization",
        c("Ti_0", "Te_0", "Qh_0", "Qc_0"),
        defaulted = model_load$defaulted,
        duplicated = model_load$duplicated,
        file_key = "11_Model_parameters.csv"
      ),
      build_group_editor(
        model_df,
        "model__",
        "Heat Distribution",
        c("inertial_fact"),
        defaulted = model_load$defaulted,
        duplicated = model_load$duplicated,
        file_key = "11_Model_parameters.csv"
      ),
      actionButton("save_model", "save", class = "btn-primary")
    ),
    tabPanel(
      "Occupancy",
      h4("Day Type Profiles [0/1 per hour]"),
      DTOutput("occupancy_type_table"),
      h4("Monthly Weekday Mapping [TYPE reference per weekday]"),
      DTOutput("occupancy_month_table"),
      actionButton("save_occupancy", "save", class = "btn-primary")
    ),
    tabPanel(
      "Control",
      build_group_editor(
        control_df,
        "control__",
        "Control Approach",
        c("control_type"),
        options_list = list(
          control_type = c("modes", "setpoints")
        ),
        defaulted = control_load$defaulted,
        duplicated = control_load$duplicated,
        file_key = "12_Control_parameters.csv"
      ),
      build_group_editor(
        control_df,
        "control__",
        "Default Setpoints",
        c("set_point_default_cooling", "set_point_default_heating"),
        defaulted = control_load$defaulted,
        duplicated = control_load$duplicated,
        file_key = "12_Control_parameters.csv"
      ),
      build_group_editor(
        control_df,
        "control__",
        "Acceptable Setpoint range",
        c("set_point_range_heating_low", "set_point_range_heating_high",
          "set_point_range_cooling_low", "set_point_range_cooling_high",
          "Deadband"),
        defaulted = control_load$defaulted,
        duplicated = control_load$duplicated,
        file_key = "12_Control_parameters.csv"
      ),
      build_group_editor(
        control_df,
        "control__",
        "Flexibility Event Response",
        c("flexibility_event_length_max", "flexibility_recover_timespan",
          "thermal_stabilization_timespan", "minimum_flexibility",
          "flexibility_splits"),
        defaulted = control_load$defaulted,
        duplicated = control_load$duplicated,
        file_key = "12_Control_parameters.csv"
      ),
      actionButton("save_control", "save", class = "btn-primary")
    ),
    tabPanel(
      "Modes",
      DTOutput("modes_table"),
      actionButton("save_modes", "save", class = "btn-primary")
    ),
    tabPanel(
      "Optimization",
      uiOutput("optimization_ui"),
      actionButton("save_optimization", "save", class = "btn-primary")
    ),
    tabPanel(
      "Market",
      build_group_editor(
        market_df,
        "market__",
        "Market definition",
        c("market_resolution", "Complex_Market_Config"),
        options_list = list(
          Complex_Market_Config = c("yes", "no")
        ),
        defaulted = market_load$defaulted,
        duplicated = market_load$duplicated,
        file_key = "15_Market_config.csv"
      ),
      build_group_editor(
        market_df,
        "market__",
        "Scheduling Markets",
        c("Optimization_horizon_scheduling",
          "Implementation_horizon_scheduling",
          "Anticipation_scheduling", "optimization_aim_scheduling"),
        options_list = list(
          optimization_aim_scheduling = c("O", "E", "O+F", "E+F")
        ),
        defaulted = market_load$defaulted,
        duplicated = market_load$duplicated,
        file_key = "15_Market_config.csv"
      ),
      build_group_editor(
        market_df,
        "market__",
        "Piloting Markets",
        c("Optimization_horizon_piloting",
          "Implementation_horizon_piloting",
          "Anticipation_piloting", "optimization_aim_piloting"),
        options_list = list(
          optimization_aim_piloting = c("O", "E", "O+F", "E+F")
        ),
        defaulted = market_load$defaulted,
        duplicated = market_load$duplicated,
        file_key = "15_Market_config.csv"
      ),
      build_group_editor(
        market_df,
        "market__",
        "Flexibility Price Emulation",
        c("Max_flex_periods_day", "Max_flex_com_price", "Max_flex_exec_price",
          "Max_flex_period_duration", "Max_flex_probability"),
        defaulted = market_load$defaulted,
        duplicated = market_load$duplicated,
        file_key = "15_Market_config.csv"
      ),
      actionButton("save_market", "save", class = "btn-primary")
    ),
    tabPanel(
      "Market Schedules (Scheduling)",
      DTOutput("sched_table"),
      actionButton("save_sched", "save", class = "btn-primary")
    ),
    tabPanel(
      "Market Schedules (Piloting)",
      DTOutput("pilot_table"),
      actionButton("save_pilot", "save", class = "btn-primary")
    ),
    tabPanel(
      "Reward Function",
      uiOutput("reward_ui"),
      actionButton("save_reward", "save", class = "btn-primary")
    ),
    tabPanel(
      "Forecasting",
      uiOutput("forecast_ui"),
      actionButton("save_forecast", "save", class = "btn-primary")
    ),
    tabPanel(
      "Energy Price",
      uiOutput("energy_price_ui"),
      actionButton("save_energy_price", "save", class = "btn-primary")
    ),
    tabPanel(
      "Flexibility Generation",
      uiOutput("flex_generation_ui"),
      actionButton("save_flex_generation", "save", class = "btn-primary")
    ),
    tabPanel(
      "Configuration and Debug",
      uiOutput("debug_ui"),
      actionButton("save_debug", "save", class = "btn-primary")
    )
  ),
  br(),
  uiOutput("msg_save")
)

server <- function(input, output, session) {

  rv <- reactiveValues(
    model           = model_df,
    occupancy_type  = occupancy_type_df,
    occupancy_month = occupancy_month_df,
    control         = control_df,
    modes           = modes_df,
    optimization    = optimization_df,
    market          = market_df,
    sched           = sched_df,
    pilot           = pilot_df,
    reward          = reward_df,
    forecast        = forecast_df,
    energy_price    = energy_price_df,
    flex_generation = flex_generation_df,
    debug           = debug_df,

    model_defaulted        = model_load$defaulted,
    control_defaulted      = control_load$defaulted,
    optimization_defaulted = optimization_load$defaulted,
    market_defaulted       = market_load$defaulted,
    reward_defaulted       = reward_load$defaulted,
    forecast_defaulted     = forecast_load$defaulted,
    energy_price_defaulted = energy_price_load$defaulted,
    flex_generation_defaulted = flex_generation_load$defaulted,
    debug_defaulted        = debug_load$defaulted,

    model_duplicated        = model_load$duplicated,
    control_duplicated      = control_load$duplicated,
    optimization_duplicated = optimization_load$duplicated,
    market_duplicated       = market_load$duplicated,
    reward_duplicated       = reward_load$duplicated,
    forecast_duplicated     = forecast_load$duplicated,
    energy_price_duplicated = energy_price_load$duplicated,
    flex_generation_duplicated = flex_generation_load$duplicated,
    debug_duplicated        = debug_load$duplicated,

    modes_defaulted_rows           = modes_load$defaulted_rows,
    sched_defaulted_rows           = sched_load$defaulted_rows,
    pilot_defaulted_rows           = pilot_load$defaulted_rows,
    occupancy_type_defaulted_rows  = occupancy_load$defaulted_type_rows,
    occupancy_month_defaulted_rows = occupancy_load$defaulted_month_rows
  )

  output$optimization_ui <- renderUI({
    build_param_editor(rv$optimization, "opt__", max_per_row = 4,
                       defaulted = rv$optimization_defaulted,
                       duplicated = rv$optimization_duplicated,
                       file_key = "14_Optimization_parameters.csv")
  })

  output$reward_ui <- renderUI({
    tagList(
      build_group_editor(
        rv$reward,
        "reward__",
        "Service",
        c("Alpha_Service_Min", "Service_T_Low", "Service_T_High",
          "Setback_T_Low", "Setback_T_High"),
        defaulted = rv$reward_defaulted,
        duplicated = rv$reward_duplicated,
        file_key = "18_Reward_parameters.csv"
      ),
      build_group_editor(
        rv$reward,
        "reward__",
        "Scheduling",
        c("Service_Anticipation_Begin", "Service_Anticipation_End",
          "Service_AT_Low_Sched_HDD", "Service_AT_High_Sched_CDD"),
        defaulted = rv$reward_defaulted,
        duplicated = rv$reward_duplicated,
        file_key = "18_Reward_parameters.csv"
      ),
      build_group_editor(
        rv$reward,
        "reward__",
        "Climate Correction for Scheduling",
        c("T_ref_Heating_Season", "HDD_period", "T_ref_Cooling_Season", "CDD_period"),
        defaulted = rv$reward_defaulted,
        duplicated = rv$reward_duplicated,
        file_key = "18_Reward_parameters.csv"
      ),
      build_group_editor(
        rv$reward,
        "reward__",
        "Correction for flex revenues",
        c("Revenue_discount_per_hour"),
        defaulted = rv$reward_defaulted,
        duplicated = rv$reward_duplicated,
        file_key = "18_Reward_parameters.csv"
      )
    )
  })

  output$forecast_ui <- renderUI({
    build_param_editor(
      rv$forecast,
      "forecast__",
      options_list = list(
        forecast_type = c("accurate", "inaccurate")
      ),
      defaulted = rv$forecast_defaulted,
      duplicated = rv$forecast_duplicated,
      file_key = "19_Forecast_parameters.csv"
    )
  })

  output$energy_price_ui <- renderUI({
    build_param_editor(rv$energy_price, "energyprice__", defaulted = rv$energy_price_defaulted,
                       duplicated = rv$energy_price_duplicated,
                       file_key = "21_Energy_price_parameters.csv")
  })

  output$flex_generation_ui <- renderUI({
    build_param_editor(rv$flex_generation, "flexgen__", defaulted = rv$flex_generation_defaulted,
                       duplicated = rv$flex_generation_duplicated,
                       file_key = "22_Flexibility_generation_parameters.csv")
  })

  output$debug_ui <- renderUI({
    build_param_editor(
      rv$debug,
      "debug__",
      options_list = list(
        verbose         = c("0", "1"),
        parallel        = c("0", "1"),
        Price_emulation = c("0", "1")
      ),
      defaulted = rv$debug_defaulted,
      duplicated = rv$debug_duplicated,
      file_key = "30_Debug_and_config.csv"
    )
  })

  output$modes_table <- renderDT({
    display_df <- build_table_cell_inputs(rv$modes, "modes",
                                          defaulted_rows = rv$modes_defaulted_rows,
                                          readonly_cols = "mode")
    datatable(
      display_df,
      rownames = FALSE,
      escape   = FALSE,
      editable = FALSE,
      callback = table_input_callback,
      colnames = sapply(names(display_df), label_with_unit,
                        file_key = "13_Modes_setpoints.csv", USE.NAMES = FALSE),
      options  = list(dom = "t", ordering = FALSE,
                      pageLength = max(1, nrow(display_df)))
    )
  })

  output$occupancy_type_table <- renderDT({
    display_df <- build_table_cell_inputs(rv$occupancy_type, "occupancy_type",
                                          defaulted_rows = rv$occupancy_type_defaulted_rows)
    datatable(
      display_df,
      rownames = FALSE,
      escape   = FALSE,
      editable = FALSE,
      callback = table_input_callback,
      options  = list(dom = "t", ordering = FALSE,
                      pageLength = max(1, nrow(display_df)))
    )
  })

  output$occupancy_month_table <- renderDT({
    display_df <- build_table_cell_inputs(rv$occupancy_month, "occupancy_month",
                                          defaulted_rows = rv$occupancy_month_defaulted_rows)
    datatable(
      display_df,
      rownames = FALSE,
      escape   = FALSE,
      editable = FALSE,
      callback = table_input_callback,
      options  = list(dom = "t", ordering = FALSE,
                      pageLength = max(1, nrow(display_df)))
    )
  })

  output$sched_table <- renderDT({
    display_df <- build_table_cell_inputs(rv$sched, "sched",
                                          defaulted_rows = rv$sched_defaulted_rows)
    datatable(
      display_df,
      rownames = FALSE,
      escape   = FALSE,
      editable = FALSE,
      callback = table_input_callback,
      colnames = sapply(names(display_df), label_with_unit,
                        file_key = "16_Market_config_scheduling.csv", USE.NAMES = FALSE),
      options  = list(dom = "t", ordering = FALSE,
                      pageLength = max(1, nrow(display_df)))
    )
  })

  output$pilot_table <- renderDT({
    display_df <- build_table_cell_inputs(rv$pilot, "pilot",
                                          defaulted_rows = rv$pilot_defaulted_rows)
    datatable(
      display_df,
      rownames = FALSE,
      escape   = FALSE,
      editable = FALSE,
      callback = table_input_callback,
      colnames = sapply(names(display_df), label_with_unit,
                        file_key = "17_Market_config_piloting.csv", USE.NAMES = FALSE),
      options  = list(dom = "t", ordering = FALSE,
                      pageLength = max(1, nrow(display_df)))
    )
  })

  observeEvent(input$modes_cell_text_edit, {
    rv$modes <- apply_text_table_edit(rv$modes, input$modes_cell_text_edit)
  })

  observeEvent(input$occupancy_type_cell_text_edit, {
    rv$occupancy_type <- apply_text_table_edit(
      rv$occupancy_type,
      input$occupancy_type_cell_text_edit
    )
  })

  observeEvent(input$occupancy_month_cell_text_edit, {
    rv$occupancy_month <- apply_text_table_edit(
      rv$occupancy_month,
      input$occupancy_month_cell_text_edit
    )
  })

  observeEvent(input$sched_cell_text_edit, {
    rv$sched <- apply_text_table_edit(rv$sched, input$sched_cell_text_edit)
  })

  observeEvent(input$pilot_cell_text_edit, {
    rv$pilot <- apply_text_table_edit(rv$pilot, input$pilot_cell_text_edit)
  })

  observeEvent(input$modes_add_above, {
    template <- rv$modes[max(1, input$modes_add_above), , drop = FALSE]
    rv$modes <- insert_row(rv$modes, input$modes_add_above, template)
    rv$modes$mode <- seq_len(nrow(rv$modes))
  })

  observeEvent(input$modes_add_below, {
    template <- rv$modes[max(1, input$modes_add_below), , drop = FALSE]
    rv$modes <- insert_row(rv$modes, input$modes_add_below + 1, template)
    rv$modes$mode <- seq_len(nrow(rv$modes))
  })

  observeEvent(input$modes_delete, {
    if (nrow(rv$modes) <= 1) {
      return()
    }
    rv$modes <- rv$modes[-input$modes_delete, , drop = FALSE]
    rv$modes$mode <- seq_len(nrow(rv$modes))
  })

  observeEvent(input$occupancy_type_add_above, {
    template <- rv$occupancy_type[max(1, input$occupancy_type_add_above), ,
                                  drop = FALSE]
    rv$occupancy_type <- insert_row(
      rv$occupancy_type,
      input$occupancy_type_add_above,
      template
    )
  })

  observeEvent(input$occupancy_type_add_below, {
    template <- rv$occupancy_type[max(1, input$occupancy_type_add_below), ,
                                  drop = FALSE]
    rv$occupancy_type <- insert_row(
      rv$occupancy_type,
      input$occupancy_type_add_below + 1,
      template
    )
  })

  observeEvent(input$occupancy_type_delete, {
    if (nrow(rv$occupancy_type) <= 1) {
      return()
    }
    rv$occupancy_type <- rv$occupancy_type[-input$occupancy_type_delete, ,
                                           drop = FALSE]
  })

  observeEvent(input$occupancy_month_add_above, {
    template <- rv$occupancy_month[max(1, input$occupancy_month_add_above), ,
                                   drop = FALSE]
    rv$occupancy_month <- insert_row(
      rv$occupancy_month,
      input$occupancy_month_add_above,
      template
    )
  })

  observeEvent(input$occupancy_month_add_below, {
    template <- rv$occupancy_month[max(1, input$occupancy_month_add_below), ,
                                   drop = FALSE]
    rv$occupancy_month <- insert_row(
      rv$occupancy_month,
      input$occupancy_month_add_below + 1,
      template
    )
  })

  observeEvent(input$occupancy_month_delete, {
    if (nrow(rv$occupancy_month) <= 1) {
      return()
    }
    rv$occupancy_month <- rv$occupancy_month[-input$occupancy_month_delete, ,
                                             drop = FALSE]
  })

  observeEvent(input$sched_add_above, {
    template <- rv$sched[max(1, input$sched_add_above), , drop = FALSE]
    rv$sched <- insert_row(rv$sched, input$sched_add_above, template)
  })

  observeEvent(input$sched_add_below, {
    template <- rv$sched[max(1, input$sched_add_below), , drop = FALSE]
    rv$sched <- insert_row(rv$sched, input$sched_add_below + 1, template)
  })

  observeEvent(input$sched_delete, {
    if (nrow(rv$sched) <= 1) {
      return()
    }
    rv$sched <- rv$sched[-input$sched_delete, , drop = FALSE]
  })

  observeEvent(input$pilot_add_above, {
    template <- rv$pilot[max(1, input$pilot_add_above), , drop = FALSE]
    rv$pilot <- insert_row(rv$pilot, input$pilot_add_above, template)
  })

  observeEvent(input$pilot_add_below, {
    template <- rv$pilot[max(1, input$pilot_add_below), , drop = FALSE]
    rv$pilot <- insert_row(rv$pilot, input$pilot_add_below + 1, template)
  })

  observeEvent(input$pilot_delete, {
    if (nrow(rv$pilot) <= 1) {
      return()
    }
    rv$pilot <- rv$pilot[-input$pilot_delete, , drop = FALSE]
  })

  save_all <- function() {
    tryCatch(
      {
        # flush_table_edits() pulls in any pending cell edits from the
        # DT tables (modes/occupancy) before the parameter tabs below
        # are read from their individual Shiny inputs, so nothing
        # entered by the user is lost regardless of which tab is
        # currently open when "save" is pressed.
        flush_table_edits(rv, input)

        # update_df_from_inputs() re-reads every widget's current
        # value back into its reactive data frame - one call per tab,
        # all sharing the same pattern (widget input -> df$value).
        rv$model        <- update_df_from_inputs(rv$model, "model__", input)
        rv$control      <- update_df_from_inputs(rv$control, "control__", input)
        rv$optimization <- update_df_from_inputs(rv$optimization, "opt__", input)
        rv$market       <- update_df_from_inputs(rv$market, "market__", input)
        rv$reward       <- update_df_from_inputs(rv$reward, "reward__", input)
        rv$forecast     <- update_df_from_inputs(rv$forecast, "forecast__", input)
        rv$energy_price <- update_df_from_inputs(rv$energy_price, "energyprice__", input)
        rv$flex_generation <- update_df_from_inputs(rv$flex_generation, "flexgen__", input)
        rv$debug        <- update_df_from_inputs(rv$debug, "debug__", input)

        rv$occupancy_type[]  <- lapply(rv$occupancy_type, as.character)
        rv$occupancy_month[] <- lapply(rv$occupancy_month, as.character)

        # ---- Validate everything before writing anything ----
        # Every tab is validated against the same Parameter_config.csv
        # rules used by the real simulation pipeline, before any file
        # on disk is touched, so a single invalid value in one tab
        # cannot leave the configuration half-written.
        validation_errors <- c(
          validate_param_df_gui(rv$model, "11_Model_parameters.csv", validation_config),
          validate_param_df_gui(rv$control, "12_Control_parameters.csv", validation_config),
          validate_param_df_gui(rv$optimization, "14_Optimization_parameters.csv", validation_config),
          validate_param_df_gui(rv$market, "15_Market_config.csv", validation_config),
          validate_param_df_gui(rv$reward, "18_Reward_parameters.csv", validation_config),
          validate_param_df_gui(rv$forecast, "19_Forecast_parameters.csv", validation_config),
          validate_param_df_gui(rv$energy_price, "21_Energy_price_parameters.csv", validation_config),
          validate_param_df_gui(rv$flex_generation, "22_Flexibility_generation_parameters.csv", validation_config),
          validate_param_df_gui(rv$debug, "30_Debug_and_config.csv", validation_config),
          validate_modes_df_gui(rv$modes),
          validate_market_table_df_gui(rv$sched, "16_Market_config_scheduling.csv"),
          validate_market_table_df_gui(rv$pilot, "17_Market_config_piloting.csv"),
          validate_occupancy_dfs_gui(rv$occupancy_type, rv$occupancy_month)
        )

        if (length(validation_errors) > 0) {
          output$msg_save <- renderUI(
            tags$div(
              style = "color:#c0392b; white-space:pre-wrap;",
              tags$strong("✖ Nothing was saved. Fix these values:"),
              tags$ul(lapply(validation_errors, function(m) tags$li(m)))
            )
          )
          return(invisible(NULL))
        }

        rv$modes$mode <- seq_len(nrow(rv$modes))

        # All validation above passed, so every tab is now written to
        # its configuration file on disk - write_param_file() for flat
        # "parameter,value,unit" files, write_table_file() for the
        # modes/market-schedule tables, write_use_patterns_file() for
        # the two-block occupancy file.
        write_param_file(
          file_names$model,
          "# Physical and thermal parameters of the building and HVAC system",
          rv$model
        )
        write_use_patterns_file(
          file_names$occupancy,
          rv$occupancy_type,
          rv$occupancy_month
        )
        write_param_file(
          file_names$control,
          "# HVAC control parameters",
          rv$control
        )
        write_param_file(
          file_names$optimization,
          "# Optimization and MPC horizon parameters",
          rv$optimization
        )
        write_param_file(
          file_names$market,
          "# Market definition and horizon parameters",
          rv$market
        )
        write_table_file(
          file_names$modes,
          "# Setpoint modes & associated heating and cooling setpoints",
          rv$modes
        )
        write_table_file(
          file_names$sched,
          "# Market configuration table",
          rv$sched
        )
        write_table_file(
          file_names$pilot,
          "# Market configuration table",
          rv$pilot
        )
        write_param_file(
          file_names$reward,
          "# Reward function parameters",
          rv$reward
        )
        write_param_file(
          file_names$forecast,
          "# Weather forecast parameters",
          rv$forecast
        )
        write_param_file(
          file_names$energy_price,
          "# Energy market price discount/premium parameters",
          rv$energy_price
        )
        write_param_file(
          file_names$flex_generation,
          "# Market-aware flexibility generation parameters (Complex_Market_Config == \"yes\" only)",
          rv$flex_generation
        )
        write_param_file(
          file_names$debug,
          "# Debug and configuration parameters",
          rv$debug
        )

        # Values just written are the user's deliberate choice, not
        # leftover defaults or duplicates: clear every "defaulted" and
        # "duplicated" flag so the red highlighting disappears now
        # that it has been persisted.
        rv$model_defaulted        <- character(0)
        rv$control_defaulted      <- character(0)
        rv$optimization_defaulted <- character(0)
        rv$market_defaulted       <- character(0)
        rv$reward_defaulted       <- character(0)
        rv$forecast_defaulted     <- character(0)
        rv$energy_price_defaulted <- character(0)
        rv$flex_generation_defaulted <- character(0)
        rv$debug_defaulted        <- character(0)
        rv$model_duplicated        <- character(0)
        rv$control_duplicated      <- character(0)
        rv$optimization_duplicated <- character(0)
        rv$market_duplicated       <- character(0)
        rv$reward_duplicated       <- character(0)
        rv$forecast_duplicated     <- character(0)
        rv$energy_price_duplicated <- character(0)
        rv$flex_generation_duplicated <- character(0)
        rv$debug_duplicated        <- character(0)
        rv$modes_defaulted_rows           <- integer(0)
        rv$sched_defaulted_rows           <- integer(0)
        rv$pilot_defaulted_rows           <- integer(0)
        rv$occupancy_type_defaulted_rows  <- integer(0)
        rv$occupancy_month_defaulted_rows <- integer(0)

        output$msg_save <- renderUI(
          tags$div(
            style = "color:#1e7e34;",
            paste("✔ All configuration files saved in:", config_path)
          )
        )
      },
      error = function(e) {
        output$msg_save <- renderUI(
          tags$div(
            style = "color:#c0392b;",
            paste("Error while saving configuration files:", e$message)
          )
        )
      }
    )
  }

  save_buttons <- c(
    "save_model", "save_occupancy", "save_control", "save_modes",
    "save_optimization", "save_market", "save_sched", "save_pilot",
    "save_reward", "save_forecast", "save_energy_price", "save_flex_generation", "save_debug"
  )

  for (CONT_004 in save_buttons) {
    local({
      button_id <- CONT_004
      observeEvent(input[[button_id]], {
        # Every "save" button triggers the same save_all(): it always
        # validates and writes the whole configuration at once, not
        # just the tab the button belongs to (see the "Clear scope for
        # save actions" rule in 00_Base_Criteria.md).
        save_all()
      })
    })
  }
}

shinyApp(ui = ui, server = server)
