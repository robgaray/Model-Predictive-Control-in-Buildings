# -------------------------------------------------------------
# Script: load_12_asset_registry.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads the asset registry, 12_Asset_registry.csv, and gathers the
# parameters of each asset into parameters$assets, one entry per
# asset, named by its asset id.
# -------------------------------------------------------------
# The assets
# The system operates its assets behind a single connection point
# with the grid. Each row of the registry is an asset: its id and its
# type of model. Each asset has its own configuration folder, named
# by its id inside the folder of the assets, with the files of its
# type of model (see build_asset_paths()). The parameters of an asset
# are loaded by the operation load_parameters of the contract of its
# type (see model_type_contract()), and gathered here into its entry
# of parameters$assets. A Building holds the groups:
#   - model
#   - operational_temperature_corrections
#   - setpoint_modes
#   - use_patterns
#   - comfort, the comfort weight and the comfort bands of the
#     building
# Every operation of the type of model of an asset receives the entry
# of its asset (see model_type_contract()).
# The registry holds one or more assets. The assets share the
# weather, the markets and the prices of the system.
# -------------------------------------------------------------
# Validation
# The run stops when:
#   - the registry lacks one of its columns, or holds no asset;
#   - a value breaks its rule of the parameter catalogue;
#   - an asset id is repeated, or is not its type followed by an
#     underscore and three digits (for example Building_001);
#   - a type of model of the file paths table is not an asset type of
#     the catalogue;
#   - the folder of an asset, or one of its files, does not exist.
# -------------------------------------------------------------
# Inputs
#   paths : List. The paths of the simulation, as set by
#     initialize_simulator(). It holds asset_registry_file, the path
#     of 12_Asset_registry.csv, and config_path, the configuration
#     folder.
#   validation_config : the parameter catalogue, as
#     load_parameter_catalogue() returns it.
#   bounding_validation_config : the content of
#     Validation_bounding_simulation.csv.
#   parameters : the list being assembled, with the system parameters
#     already loaded, among them:
#       - physical_properties
# -------------------------------------------------------------
# Outputs
#   parameters$assets : named list, one entry per asset of the
#     registry, named by its asset id. The entry of a Building holds:
#       - asset_id
#       - asset_type
#       - model
#       - operational_temperature_corrections
#       - setpoint_modes
#       - use_patterns
#       - comfort
#   One LOAD line per asset is written to the console, with its type
#   and the number of files it loaded.
# -------------------------------------------------------------
# Code outline
# 1. Read the registry, dropping its units row
# 2. Validate each asset
# 3. Load the parameters of each asset through the contract of its
#    type
# -------------------------------------------------------------
# Usage instructions
#   Not called: sourced by load_configuration_files.R, which supplies
#   paths, validation_config, bounding_validation_config and
#   parameters.
# -------------------------------------------------------------

# -------------------------------------------------------------
# 1. Read the registry, dropping its units row
# The units row is told apart from an asset by its asset_type, which
# is not one of the types the catalogue allows.
# -------------------------------------------------------------
{
  registry_file <- basename(paths$asset_registry_file)
  registry      <- read.csv(
    paths$asset_registry_file,
    comment.char     = "#",
    stringsAsFactors = FALSE,
    strip.white      = TRUE,
    colClasses       = "character"
  )

  registry_rules   <- validation_config$rules[
    validation_config$rules$file == registry_file, , drop = FALSE
  ]
  registry_columns <- registry_rules$parameter
  missing_columns  <- setdiff(registry_columns, names(registry))
  if (length(registry_columns) == 0 || length(missing_columns) > 0) {
    stop(registry_file, " is missing required columns: ",
         paste(missing_columns, collapse = ", "))
  }

  asset_types <- trimws(strsplit(
    registry_rules$options[registry_rules$parameter == "asset_type"], ","
  )[[1]])

  # drop_unit_row is called to remove the units row, the first row
  # under the header, after checking that it is not an asset.
  registry <- drop_unit_row(
    table             = registry,
    file_name         = registry_file,
    number_columns    = character(0),
    reference_columns = "asset_type",
    reference_values  = asset_types
  )

  if (nrow(registry) == 0) {
    stop(registry_file, " does not hold any asset")
  }

  rm(list = c("registry_rules", "missing_columns"))
}

# -------------------------------------------------------------
# 2. Validate each asset
# -------------------------------------------------------------
{
  for (CONT_001 in seq_len(nrow(registry))) {
    # validate_parameter_config is called on each asset, so that each
    # of its values is checked against its rule of the parameter
    # catalogue, as a value of a parameter file would be, and a column
    # that no rule describes stops the run.
    validate_parameter_config(
      values            = as.list(registry[CONT_001, , drop = FALSE]),
      file_name         = registry_file,
      validation_config = validation_config
    )
  }

  if (anyDuplicated(registry$asset_id) > 0) {
    stop(registry_file, ": asset ids must be unique. Repeated: ",
         paste(unique(registry$asset_id[duplicated(registry$asset_id)]),
               collapse = ", "))
  }

  wrong_ids <- registry$asset_id[!grepl(
    "^[A-Za-z]+_[0-9]{3}$", registry$asset_id
  ) | sub("_[0-9]+$", "", registry$asset_id) != registry$asset_type]
  if (length(wrong_ids) > 0) {
    stop(registry_file, ": an asset id is its asset_type followed by an ",
         "underscore and three digits (for example Building_001). ",
         "Wrong: ", paste(wrong_ids, collapse = ", "))
  }

  rm(list = c("CONT_001", "wrong_ids", "registry_columns"))
}

# -------------------------------------------------------------
# 3. Load the parameters of each asset
# The files of each asset are in its own folder. Its parameters are
# loaded by the operation load_parameters of the contract of its type
# of model, so that the parameters of an asset are read in one place
# only: its entry of parameters$assets.
# -------------------------------------------------------------
{
  # read_file_paths_table is called to read the types of model that
  # hold files in the file paths table, which must be asset types of
  # the catalogue.
  file_paths_table <- read_file_paths_table(config_path = paths$config_path)
  file_scopes      <- setdiff(unique(file_paths_table$scope), "system")
  unknown_scopes   <- setdiff(file_scopes, asset_types)
  if (length(unknown_scopes) > 0) {
    stop("04_File_paths.csv: the scope ",
         paste(unknown_scopes, collapse = ", "),
         " is not a type of model of the asset registry")
  }
  rm(list = c("file_paths_table", "file_scopes", "unknown_scopes"))

  parameters$assets <- list()
  for (CONT_002 in seq_len(nrow(registry))) {
    asset <- list(
      asset_id   = registry$asset_id[CONT_002],
      asset_type = registry$asset_type[CONT_002]
    )

    # build_asset_paths is called to get the paths of the files of
    # the asset, and to stop if its folder or one of its files is
    # missing.
    asset_paths <- build_asset_paths(
      config_path = paths$config_path,
      asset_id    = asset$asset_id,
      asset_type  = asset$asset_type
    )

    # model_type_contract is called to get the operations of the type
    # of model of the asset, among them the one that loads its
    # parameters.
    model <- model_type_contract(asset$asset_type)

    # The operation load_parameters is called to read the files of the
    # asset and give back its parameter groups.
    asset_groups <- model$load_parameters(
      asset_paths                = asset_paths,
      validation_config          = validation_config,
      bounding_validation_config = bounding_validation_config,
      parameters                 = parameters
    )
    parameters$assets[[asset$asset_id]] <- c(asset, asset_groups)

    # console_message is called to write the line of this asset: its
    # type and the number of configuration files it loaded.
    console_message(
      label = "LOAD",
      text  = paste0(asset$asset_id, ": ", asset$asset_type, ", ",
                     length(asset_paths), " files")
    )
  }

  rm(list = c("CONT_002", "asset", "asset_paths", "model", "asset_groups",
              "asset_types", "registry", "registry_file"))
}
