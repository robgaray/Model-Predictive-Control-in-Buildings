# -------------------------------------------------------------
# Script: load_gui_configuration.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Reads the whole configuration of the simulation from disk for the
# configuration app (GUI_config.R):
#   - the file paths;
#   - the relations between parameters;
#   - the parameter catalogue and the tolerances of the validation;
#   - every configuration file of the system;
#   - the asset registry and the files of each asset.
# The app sources it each time its page is opened or reloaded, so
# that the page always shows what is on disk at that moment, and not
# what was there when the app started.
#
# Every file is read through a safe loader: whatever is missing or
# invalid takes its default value and is flagged, so that the page
# shows it in red, and a notice is collected for the banner of the
# page. Nothing here stops the app, except a missing file of default
# paths, without which no file can be found.
# -------------------------------------------------------------
# Inputs
#   Objects of the environment of the app, where it is sourced:
#     - config_path  : Character. Absolute path of
#                      30_Simulation/02_Config.
#     - gui_fallback : List. The fallback values of the app.
#     - the helper functions of 03_Functions/.
#   The configuration files under 30_Simulation/02_Config/, with
#   their names read from 00_Inner_parameters/04_File_paths.csv.
# -------------------------------------------------------------
# Outputs
#   Objects written into the environment of the app:
#     - all_load_messages   : Character vector. The loading notices.
#     - paths               : List. The files of the system, by key.
#     - paths_table         : Data frame. Every row of the paths.
#     - file_names          : List. The files of the system the app
#                             edits.
#     - file_labels         : List. Their file names.
#     - parameter_relations : Data frame. The relations between
#                             parameters.
#     - validation_config   : List. The catalogue and the tolerances.
#     - <file>_load         : List. The result of the safe loader of
#                             each file of the system.
#     - <file>_df           : Data frame. The values of each file.
#     - market_basic_only_params : Character vector. The parameters
#                             of the market file read only with
#                             Complex_Market_Config = no.
#     - registry_df         : Data frame. The asset registry.
#     - asset_status        : Character vector. The status of each
#                             asset.
#     - registry_defaulted_rows : Integer vector. The rows of the
#                             registry taken from its defaults.
#     - asset_types         : Character vector. The types of model.
#     - asset_save_prefix   : Character. The start of the id of the
#                             save button of an asset.
#     - asset_files         : List. The files of each asset.
#     - asset_states        : List. The values of each asset.
# -------------------------------------------------------------
# Code outline
# 1. File paths (04_File_paths.csv), 1.1 relations between
#    parameters (Validation_parameter_relations.csv)
# 2. The parameter catalogue and the tolerances of the validation
# 3. Safe loading of every configuration file of the system, 3.1 the
#    asset registry and the files of each asset
# 4. The loading notices of every file
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the environment of the app:
#   source(file.path(app_dir, "04_Scripts",
#                    "load_gui_configuration.R"), local = app_env)
# -------------------------------------------------------------


# Collects every loading warning/notice generated below, shown to the
# user in a banner at the top of the app.
all_load_messages <- character(0)

# -------------------------------------------------------------
# 1. File paths (30_Simulation/02_Config/00_Inner_parameters/04_File_paths.csv)
# -------------------------------------------------------------
# The files of the system are named by the rows whose scope is
# system. The files of an asset, whose scope is its type of model,
# are in the configuration folder of the asset, and are read through
# asset_type_files() once the registry is loaded (block 3.1).
# -------------------------------------------------------------
{
  # The paths are read from 04_File_paths.csv. When it cannot be read,
  # or lacks a key, the default paths of the repository are used
  # (00_Validation/Default_04_File_paths.csv), and the user is told.
  read_paths_table <- function(file_name) {
    table <- tryCatch(
      suppressWarnings(read.csv(file.path(config_path, file_name), comment.char = "#",
                                stringsAsFactors = FALSE, strip.white = TRUE)),
      error = function(e) NULL
    )
    if (is.null(table) ||
        !all(c("key", "scope", "filename") %in% names(table)) ||
        nrow(table) == 0) {
      return(NULL)
    }
    data.frame(
      key      = trimws(as.character(table$key)),
      scope    = trimws(as.character(table$scope)),
      filename = trimws(as.character(table$filename)),
      stringsAsFactors = FALSE
    )
  }

  paths_file_name   <- "00_Inner_parameters/04_File_paths.csv"
  default_file_name <- "00_Validation/Default_04_File_paths.csv"
  default_table     <- read_paths_table(default_file_name)
  loaded_table      <- read_paths_table(paths_file_name)

  if (is.null(default_table)) {
    stop("Neither the paths file nor its defaults could be read: '",
         default_file_name, "' is missing or invalid.")
  }

  if (is.null(loaded_table)) {
    all_load_messages <- c(all_load_messages, sprintf(
      "Could not read '%s' (missing file or invalid columns). Using the default file paths.",
      paths_file_name
    ))
    paths_table <- default_table
  } else {
    paths_table <- loaded_table
    for (CONT_301 in setdiff(default_table$key, loaded_table$key)) {
      default_row <- default_table[default_table$key == CONT_301, ]
      paths_table <- rbind(paths_table, default_row)
      all_load_messages <- c(all_load_messages, sprintf(
        "'%s' is missing from %s. Using the default path '%s'.",
        CONT_301, paths_file_name, default_row$filename
      ))
    }
  }

  # The files of the system.
  system_rows <- paths_table[paths_table$scope == "system", ]
  paths       <- setNames(as.list(system_rows$filename), system_rows$key)

  file_names <- list(
    asset_registry = paths$asset_registry_file,
    flexibility_events    = paths$flexibility_events_file,
    optimization = paths$optimization_file,
    market       = paths$market_file,
    sched        = paths$market_config_scheduling_file,
    pilot        = paths$market_config_piloting_file,
    reward       = paths$reward_file,
    forecast     = paths$forecast_file,
    energy_price = paths$energy_price_file,
    flex_generation = paths$flexibility_price_emulation_file,
    debug        = paths$debug_and_config_file
  )

  # The catalogue, the rules and the messages name every configuration
  # file by its file name, which is derived from the path of the file.
  file_labels <- lapply(file_names, basename)

  rm(read_paths_table, paths_file_name, default_file_name,
     default_table, loaded_table, system_rows)
  rm(list = intersect(c("CONT_301", "default_row"), ls()))
}

# -------------------------------------------------------------
# 1.1. Relations between parameters
# (00_Validation/Validation_parameter_relations.csv), checked before
# saving. Without the file the GUI warns and saves without them.
# -------------------------------------------------------------
{
  parameter_relations <- tryCatch(
    suppressWarnings(read.csv(file.path(config_path, paths$parameter_relations_validation_file),
                              comment.char = "#", stringsAsFactors = FALSE,
                              strip.white = TRUE)),
    error = function(e) NULL
  )
  if (is.null(parameter_relations) || !"relation" %in% names(parameter_relations)) {
    all_load_messages <- c(all_load_messages, sprintf(
      "Could not read '%s'. The relations between parameters will not be checked before saving.",
      paths$parameter_relations_validation_file
    ))
    parameter_relations <- data.frame(relation = character(0))
  }
}

# -------------------------------------------------------------
# 2. The parameter catalogue and the tolerances of the validation
# (Parameter_catalogue.csv and Validation_tolerances.csv)
# -------------------------------------------------------------
# The parameters of every flat file and their order, their blocks,
# units, options and default values, and the rules their values are
# validated against, are the rows of the catalogue for that file.
# When the catalogue or the tolerances cannot be read the app warns
# the user and goes on with what is valid: the values are then
# only checked for not being empty, there are no units or dropdowns,
# the flat files are loaded as they are, with nothing to fill what
# is missing or invalid, and the new files are written with no units.
# -------------------------------------------------------------
{
  # load_gui_catalogue is called to read the catalogue and the integer
  # tolerance, whose paths come from the file paths, without stopping
  # the app.
  validation_config <- load_gui_catalogue(
    catalogue_filename  = paths$parameter_catalogue_file,
    tolerances_filename = paths$tolerances_validation_file
  )
  all_load_messages <- c(all_load_messages, validation_config$messages)
}

# -------------------------------------------------------------
# 3. Safe loading of every configuration file of the system
# -------------------------------------------------------------
# load_param_file_safe() is called once per flat "parameter,value"
# configuration file, reconciling it against the defaults of the
# parameter catalogue so a missing/invalid entry never stops the app - the
# same call pattern repeats for every tab below.
flex_events_load  <- load_param_file_safe(
  filename          = file_names$flexibility_events,
  file_label        = file_labels$flexibility_events,
  validation_config = validation_config,
  reader            = read_param_file
)
optimization_load <- load_param_file_safe(
  filename          = file_names$optimization,
  file_label        = file_labels$optimization,
  validation_config = validation_config,
  reader            = read_param_file
)
market_load       <- load_param_file_safe(
  filename          = file_names$market,
  file_label        = file_labels$market,
  validation_config = validation_config,
  reader            = read_param_file
)
reward_load       <- load_param_file_safe(
  filename          = file_names$reward,
  file_label        = file_labels$reward,
  validation_config = validation_config,
  reader            = read_param_file
)
forecast_load     <- load_param_file_safe(
  filename          = file_names$forecast,
  file_label        = file_labels$forecast,
  validation_config = validation_config,
  reader            = read_param_file
)
energy_price_load <- load_param_file_safe(
  filename          = file_names$energy_price,
  file_label        = file_labels$energy_price,
  validation_config = validation_config,
  reader            = read_param_file
)
flex_generation_load <- load_param_file_safe(
  filename          = file_names$flex_generation,
  file_label        = file_labels$flex_generation,
  validation_config = validation_config,
  reader            = read_param_file
)
debug_load        <- load_param_file_safe(
  filename          = file_names$debug,
  file_label        = file_labels$debug,
  validation_config = validation_config,
  reader            = read_param_file
)
# The two market schedules have their own row-level safe loader
# instead of load_param_file_safe(), since a row (not a single value)
# is the reconciliation unit for these.
sched_load        <- load_market_table_file_safe(file_names$sched, default_file_for(file_names$sched),
                                                 gui_fallback$market_aim_scheduling)
pilot_load        <- load_market_table_file_safe(file_names$pilot, default_file_for(file_names$pilot),
                                                 gui_fallback$market_aim_piloting)

flex_events_df     <- flex_events_load$df
optimization_df    <- optimization_load$df
market_df          <- market_load$df
reward_df          <- reward_load$df
forecast_df        <- forecast_load$df
energy_price_df    <- energy_price_load$df
flex_generation_df <- flex_generation_load$df
debug_df           <- debug_load$df
sched_df           <- sched_load$df
pilot_df           <- pilot_load$df

# The parameters of the market file whose name ends in the family of
# markets they configure: the simulation reads them only when
# Complex_Market_Config is no, and the app shades them when it is yes.
market_basic_only_params <- grep("_(scheduling|piloting)$", market_df$parameter,
                                 value = TRUE)

# -------------------------------------------------------------
# 3.1. The asset registry and the files of each asset
# -------------------------------------------------------------
# The registry lists the assets of the system. The files of each
# asset are the rows of 04_File_paths.csv whose scope is the type of
# the asset, and they are in its own folder. Each asset is loaded
# with load_asset_state(): its folder when it exists, and the
# defaults of the repository for whatever is missing.
# -------------------------------------------------------------
{
  # load_asset_registry_safe is called to read the registry, drop its
  # invalid rows and fall back on the default registry when none is
  # valid.
  registry_load <- load_asset_registry_safe(
    filename         = paths$asset_registry_file,
    default_filename = default_file_for(paths$asset_registry_file)
  )
  registry_df       <- registry_load$df
  all_load_messages <- c(all_load_messages, registry_load$messages)

  # The status of each asset of the registry, shown in the Assets tab.
  # The assets of a default registry are not in the file yet.
  asset_status <- setNames(
    ifelse(seq_len(nrow(registry_df)) %in% registry_load$defaulted_rows,
           "default registry, not saved", "in the registry"),
    registry_df$asset_id
  )
  registry_defaulted_rows <- registry_load$defaulted_rows

  # The types of model that have a selector in the Assets tab: the
  # options of asset_type in the catalogue, and any other type the
  # registry holds.
  asset_types <- union(
    validation_options(validation_config, file_labels$asset_registry,
                       "asset_type"),
    registry_df$asset_type
  )

  # The start of the id of the save button of each asset.
  asset_save_prefix <- "save_asset_"

  asset_files  <- list()
  asset_states <- list()
  for (CONT_501 in seq_len(nrow(registry_df))) {
    asset_id   <- registry_df$asset_id[CONT_501]
    asset_type <- registry_df$asset_type[CONT_501]

    # asset_type_files is called to find the files of the type of the
    # asset.
    asset_files[[asset_id]] <- asset_type_files(paths_table, asset_type)

    # load_asset_state is called to load every file of the asset, with
    # the defaults of the repository for whatever is missing.
    asset_load <- load_asset_state(
      asset_id          = asset_id,
      files             = asset_files[[asset_id]],
      asset_folder      = file.path(paths$asset_config_folder, asset_id),
      validation_config = validation_config
    )
    asset_states[[asset_id]] <- asset_load$state
    all_load_messages        <- c(all_load_messages, asset_load$messages)
    rm(asset_id, asset_type, asset_load)
  }
  rm(registry_load, CONT_501)
}

# -------------------------------------------------------------
# 4. The loading notices of every file
# -------------------------------------------------------------
{
  all_load_messages <- c(
    all_load_messages,
    flex_events_load$messages, optimization_load$messages,
    market_load$messages, reward_load$messages,
    forecast_load$messages,
    energy_price_load$messages,
    flex_generation_load$messages, debug_load$messages,
    sched_load$messages, pilot_load$messages
  )
}
