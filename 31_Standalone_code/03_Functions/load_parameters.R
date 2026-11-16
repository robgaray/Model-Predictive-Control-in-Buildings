# -------------------------------------------------------------
# Function: load_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Reads and validates every configuration file of the standalone
# market script and assembles them into the parameters list the
# copied simulation functions expect. Each file is checked against
# its rows of 00_Validation/Parameter_catalogue.csv before its values
# are used, and a failed check stops execution. The values keep the
# type their rule gives them, so no parameter name is written here.
# The names of the files are those of
# 00_Inner_parameters/05_File_paths.csv.
# -------------------------------------------------------------
# The assets
# 12_Asset_registry.csv lists the assets the script can operate,
# each with its type of model. Each asset has its own configuration
# folder, 20_Assets/<asset_id>/, with the files of its type. The
# parameters of an asset are loaded by the operation load_parameters
# of the contract of its type (model_type_contract()) and gathered in
# its entry of parameters$assets. The comfort weight and the comfort
# bands are not in the reward file: each building loads them from
# its own file.
# -------------------------------------------------------------
# Inputs
#   config_path : Character. Configuration folder (02_Config).
# -------------------------------------------------------------
# Outputs
#   parameters : Named list with the sub-lists:
#     - computing          : main_resolution_sec, flex_energy_tol
#     - physical_properties: Cp_air, dens_air and the reference
#                            conditions of photovoltaic modules
#     - market             : market_resolution
#     - debug_and_config   : parallel, parallel_workers, random_seed
#                            (set later from the input)
#     - optimization       : the genetic algorithm parameters
#     - control            : the flexibility parameters
#     - reward             : the parameters of the reward
#     - assets             : one entry per asset of the registry,
#                            named by its asset id, with its
#                            asset_id, its asset_type and the groups
#                            of its type. A Building holds model,
#                            operational_temperature_corrections,
#                            setpoint_modes, comfort and control. A
#                            Photovoltaic holds photovoltaic and
#                            reference_conditions.
#     - joined_cols        : the columns of the view of an asset, in
#                            order, as build_column_lists() gives
#     - itinerary_variables: the variables of each type of model that
#                            are expanded into the itineraries, as
#                            build_column_lists() gives
#     - input_validation   : rules of 00_Validation/Validation_Inputs.csv
#                            for the vectors of an input
#     - parameter_catalogue: the parameter catalogue and its
#                            tolerances, as load_parameter_catalogue()
#                            returns them
# -------------------------------------------------------------
# Code outline
# 1. Read the validation tables
# 2. Computing parameters and physical properties
# 3. Run configuration
# 4. Optimization and flexibility parameters
# 5. Reward parameters
# 6. Consistency of the time resolutions
# 7. Asset registry
# 8. Relations between parameters
# 9. Columns of the tables
# -------------------------------------------------------------
# Usage instructions
# parameters <- load_parameters(config_path)
# -------------------------------------------------------------

load_parameters <- function(config_path) {

  # -------------------------------------------------------------
  # 1. Read the validation tables
  # -------------------------------------------------------------
  {
    # build_config_paths is called to get the path of every system
    # file of the configuration from the table of file names.
    paths <- build_config_paths(config_path)

    # load_parameter_catalogue is called to read the parameter
    # catalogue, which holds the rules of every configuration file,
    # and the tolerances of the validation.
    validation_config <- load_parameter_catalogue(
      paths$parameter_catalogue_file,
      paths$tolerances_validation_file
    )

    bounding_validation_config <- read.csv(
      paths$bounding_simulation_validation_file,
      comment.char     = "#",
      stringsAsFactors = FALSE
    )
    input_validation_config    <- read.csv(
      paths$input_validation_file,
      comment.char     = "#",
      stringsAsFactors = FALSE
    )

    parameters <- list()
  }

  # -------------------------------------------------------------
  # 2. Computing parameters and physical properties
  # -------------------------------------------------------------
  {
    # load_parameter_file is called to read the computing parameters
    # and check them against their rows of the catalogue.
    parameters$computing <- load_parameter_file(
      paths$computing_parameters_file,
      validation_config
    )

    # load_parameter_file is called to read the air properties used to
    # turn air changes into ventilation resistances, and the
    # reference conditions of photovoltaic modules.
    parameters$physical_properties <- load_parameter_file(
      paths$physical_properties_file,
      validation_config
    )

    # load_parameter_file is called again to read the reference values
    # the physical properties are compared against.
    reference_values <- load_parameter_file(
      paths$physical_properties_validation_file,
      validation_config
    )

    # validate_physical_properties is called to warn when the physical
    # properties differ from their reference values.
    validate_physical_properties(parameters$physical_properties,
                                 reference_values)

    rm(list = "reference_values")
  }

  # -------------------------------------------------------------
  # 3. Run configuration
  # -------------------------------------------------------------
  # random_seed is not a configuration value: it comes with each call
  # and optimize_market() sets it.
  # -------------------------------------------------------------
  {
    # load_parameter_file is called to read the market resolution and
    # the execution options of the optimizer.
    run_values <- load_parameter_file(
      paths$run_config_file,
      validation_config
    )

    parameters$market <- list(
      market_resolution = run_values$market_resolution
    )
    parameters$debug_and_config <- list(
      parallel         = run_values$parallel,
      parallel_workers = run_values$parallel_workers,
      random_seed      = 0
    )
    rm(list = "run_values")
  }

  # -------------------------------------------------------------
  # 4. Optimization and flexibility parameters
  # -------------------------------------------------------------
  {
    # load_parameter_file is called to read the genetic algorithm
    # parameters.
    parameters$optimization <- load_parameter_file(
      paths$optimization_file,
      validation_config
    )

    # load_parameter_file is called to read the flexibility event
    # parameters, which are the control parameters of the system.
    parameters$control <- load_parameter_file(
      paths$flexibility_events_file,
      validation_config
    )
  }

  # -------------------------------------------------------------
  # 5. Reward parameters
  # -------------------------------------------------------------
  {
    # load_parameter_file is called to read the weight of cost and the
    # discount of future revenue of the reward.
    parameters$reward <- load_parameter_file(
      paths$reward_file,
      validation_config
    )
  }

  # -------------------------------------------------------------
  # 6. Consistency of the time resolutions
  # -------------------------------------------------------------
  {
    if ((parameters$market$market_resolution * 60) %%
        parameters$computing$main_resolution_sec != 0) {
      stop("market_resolution (minutes) must be a multiple of ",
           "main_resolution_sec (", parameters$computing$main_resolution_sec,
           " s)")
    }

    parameters$input_validation    <- input_validation_config
    parameters$parameter_catalogue <- validation_config
  }

  # -------------------------------------------------------------
  # 7. Asset registry
  # The registry lists the assets with their type of model. Each
  # asset loads its own files, from its own configuration folder,
  # through the function of its type.
  # The run stops when:
  #   - the registry lacks one of its columns, or holds no asset
  #   - a value breaks its rule of the parameter catalogue
  #   - an asset id is repeated, or is not its type followed by an
  #     underscore and three digits (for example Building_001)
  #   - a type of model of the file paths table is not an asset type
  #     of the catalogue
  #   - the folder of an asset, or one of its files, does not exist
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

    for (CONT_001 in seq_len(nrow(registry))) {
      # validate_parameter_config is called on each asset, so that
      # each of its values is checked against its rule of the
      # parameter catalogue, as a value of a parameter file would be,
      # and a column that no rule describes stops the run.
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
      stop(registry_file, ": an asset id is its asset_type followed by ",
           "an underscore and three digits (for example Building_001). ",
           "Wrong: ", paste(wrong_ids, collapse = ", "))
    }

    # read_file_paths_table is called to read the types of model that
    # hold files in the file paths table, which must be asset types
    # of the catalogue.
    file_paths_table <- read_file_paths_table(config_path = config_path)
    unknown_scopes   <- setdiff(
      setdiff(unique(file_paths_table$scope), "system"),
      asset_types
    )
    if (length(unknown_scopes) > 0) {
      stop("05_File_paths.csv: the scope ",
           paste(unknown_scopes, collapse = ", "),
           " is not a type of model of the asset registry")
    }

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
        config_path = config_path,
        asset_id    = asset$asset_id,
        asset_type  = asset$asset_type
      )

      # model_type_contract is called to get the operations of the
      # type of model of the asset, which include the one that loads
      # its parameters. It stops if the type has no contract.
      model <- model_type_contract(asset$asset_type)

      # The operation load_parameters of the type is called to read
      # the files of the asset and give back its parameter groups.
      asset_groups <- model$load_parameters(
        asset_paths                = asset_paths,
        validation_config          = validation_config,
        bounding_validation_config = bounding_validation_config,
        parameters                 = parameters
      )
      parameters$assets[[asset$asset_id]] <- c(asset, asset_groups)
    }
    rm(list = c("registry_file", "registry_rules", "registry_columns",
                "missing_columns", "asset_types", "wrong_ids", "unknown_scopes",
                "CONT_001", "CONT_002", "asset", "asset_paths", "model",
                "asset_groups"))
  }

  # -------------------------------------------------------------
  # 8. Relations between parameters
  # The relations of Validation_parameter_relations.csv need every
  # parameter, so they are checked once all of them are loaded.
  # -------------------------------------------------------------
  {
    # read.csv is called to read the relations, drop_unit_row to
    # remove the units row of the table, and
    # validate_parameter_relations to check each relation for each
    # asset it applies to.
    parameter_relations <- drop_unit_row(
      table             = read.csv(
        paths$parameter_relations_validation_file,
        comment.char     = "#",
        stringsAsFactors = FALSE,
        strip.white      = TRUE
      ),
      file_name         = basename(paths$parameter_relations_validation_file),
      number_columns    = character(0),
      reference_columns = "relation",
      reference_values  = c("<", "<=", ">", ">=")
    )
    validate_parameter_relations(
      parameters       = parameters,
      relations        = parameter_relations,
      file_paths_table = file_paths_table
    )
    rm(list = c("parameter_relations", "file_paths_table"))
  }

  # -------------------------------------------------------------
  # 9. Columns of the tables
  # The order of the columns of the view of an asset, and the
  # variables of each type of model that the itineraries expand, come
  # from the variable registries of the system and of the types of the
  # assets.
  # -------------------------------------------------------------
  {
    # build_column_lists is called to read the variable registries and
    # give the two lists of columns the market process reads.
    column_lists <- build_column_lists(
      paths       = paths,
      asset_types = unique(vapply(parameters$assets,
                                  function(CONT_003) CONT_003$asset_type,
                                  character(1)))
    )
    parameters$joined_cols          <- column_lists$joined
    parameters$itinerary_variables  <- column_lists$itinerary_variables
    rm(list = "column_lists")
  }

  rm(list = c("paths", "validation_config", "bounding_validation_config",
              "input_validation_config"))

  return(parameters)
}
