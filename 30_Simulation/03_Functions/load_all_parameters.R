# -------------------------------------------------------------
# Function: load_all_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Master parameter-loading function. It reads the parameter
# catalogue, loads the internal parameters
# (load_internal_parameters.R), assembles and validates Main_df,
# loads every configuration file (load_configuration_files.R),
# checks the relations between parameters, and builds the table of
# each asset of the asset registry. Every file is validated against
# the parameter catalogue as it is read.
# -------------------------------------------------------------
# The data of the system and of its assets
# Main_df holds what is common to every asset (the time grid, the
# weather, the prices) and the balances of the system. The columns of
# each asset are in its own table, assets[[asset_id]]$df, one row per
# row of Main_df, with the column time as the key of its rows. The
# table of a building is generated from the variable registry of the
# building.
# -------------------------------------------------------------
# The scripts it sources
# load_internal_parameters.R, assemble_main_df.R and
# load_configuration_files.R are scripts: each is sourced into the
# environment of this function, where it finds paths,
# validation_config and parameters and leaves what it loads. Nothing
# is created in the global environment.
# -------------------------------------------------------------
# Inputs
#   paths : List. The paths of the simulation: the configuration
#           files, the data files and the output folder, as built by
#           initialize_simulator().
# -------------------------------------------------------------
# Outputs
#   Named list with:
#   - Main_df    : Data frame. Main simulation data frame (full year,
#                  not subsetted), with the common columns and those
#                  of the system.
#   - assets     : Named list, one entry per asset of the registry,
#                  named by its asset id. Each entry is a list with
#                  df, the table of the asset (full year, not
#                  subsetted).
#   - parameters : List with these sub-lists:
#       - computing
#       - physical_properties
#       - needed_cols
#       - control
#       - optimization
#       - market
#       - market_config_scheduling
#       - market_config_piloting
#       - reward
#       - forecast
#       - energy_price
#       - flexibility_price_emulation
#       - debug_and_config
#       - assets : one entry per asset of 12_Asset_registry.csv,
#                  named by its asset id, with the groups of the
#                  asset. A Building holds model, use_patterns,
#                  setpoint_modes and
#                  operational_temperature_corrections.
#   One DATA line per asset is written to the console, with the size
#   of its table. The scripts it sources and the validations write
#   no other line when all goes well.
# -------------------------------------------------------------
# Code outline
#   A. Internal parameters
#      1. Validation configuration files (the parameter catalogue and
#         the validation tables of 00_Validation/)
#      2. Computing parameters, physical properties, debug and
#         configuration, and needed columns, via
#         load_internal_parameters.R
#   B. Main_df
#      3. Assemble Main_df via assemble_main_df.R (Meteo_df/
#         Energy_Prices_df + synthetic dataframes)
#      4. Validate its structure (validate_Main_df())
#   C. Parameters
#      5. Every configuration file, from 01_Optimization_parameters.csv
#         to 15_Forecast_parameters.csv, and the asset registry, via
#         load_configuration_files.R
#      6. Check the relations between parameters
#         (validate_parameter_relations())
#      7. Recalculate T_ext_24h from previous-day averages
#   D. The tables of the assets
#      8. Build the table of each asset on the grid of Main_df, through
#         the operation new_table of its type of model, and validate
#         it (validate_asset_df()), and copy into it the columns of
#         Main_df its type declares as inputs (copy_asset_inputs())
#      9. Return Main_df, the assets and parameters
# -------------------------------------------------------------
# Usage instructions
# loaded <- load_all_parameters(
#   paths = sim$paths
# )
# loaded$Main_df
# loaded$assets$Building_001$df
# loaded$parameters$control
# -------------------------------------------------------------

load_all_parameters <- function(paths) {

  # -------------------------------------------------------------
  # A. Internal parameters
  # Loads what the rest of the script and the loaders need before any
  # configuration file of 02_Config is read:
  #   - the parameter catalogue and the validation tables of
  #     00_Validation/
  #   - the internal parameters: computing parameters, physical
  #     properties, debug and configuration switches, needed columns
  # Steps:
  #   1. Validation configuration files
  #   2. Internal parameters
  # -------------------------------------------------------------
  {
    # -------------------------------------------------------------
    # 1. Validation configuration files
    # The parameter catalogue holds the type/range rules of every
    # parameter of every configuration file, the computing parameters
    # included. The table read next holds the limits that are applied
    # outside that mechanism: the plausibility bounds of Main_df's
    # columns and of the building volume. None of these limits is
    # written in the code that enforces them.
    # -------------------------------------------------------------
    # load_parameter_catalogue is called to read the catalogue and the
    # tolerances of the validation, and to check that every rule can be
    # applied, before any configuration file is validated with them.
    validation_config <- load_parameter_catalogue(
      catalogue_path  = paths$parameter_catalogue_file,
      tolerances_path = paths$tolerances_validation_file
    )

    bounding_validation_config <- read.csv(
      paths$bounding_simulation_validation_file,
      comment.char     = "#",
      stringsAsFactors = FALSE
    )

    # -------------------------------------------------------------
    # 2. Internal parameters
    # They are loaded before Main_df because main_resolution_sec, a
    # computing parameter, defines the master time grid that Main_df is
    # assembled on, in block B.
    # -------------------------------------------------------------
    parameters <- list()

    # load_internal_parameters.R is sourced to load the computing
    # parameters, the physical properties, the debug and configuration
    # switches and the needed columns into parameters.
    source(file.path("30_Simulation", "04_Scripts", "load_internal_parameters.R"), local = TRUE)
  }

  # -------------------------------------------------------------
  # B. Main_df
  # Assembles Main_df from Meteo_df/Energy_Prices_df (real input
  # dataframes) and System_variables_df/Flexibility_actions_df/
  # Meteo_transformations_df (synthetic dataframes), and validates its
  # structure before any parameter is loaded on top of it.
  # Steps:
  #   3. Assemble Main_df
  #   4. Validate Main_df
  # -------------------------------------------------------------
  {
    # -------------------------------------------------------------
    # 3. Assemble Main_df
    # -------------------------------------------------------------
    # assemble_main_df.R is sourced to load Meteo_df/Energy_Prices_df
    # and build the synthetic dataframes, assembling all of them into
    # Main_df on the common master grid defined by
    # parameters$computing$main_resolution_sec.
    source(file.path("30_Simulation", "04_Scripts", "assemble_main_df.R"), local = TRUE)

    # -------------------------------------------------------------
    # 4. Validate Main_df
    # -------------------------------------------------------------
    # validate_Main_df is called to check that the freshly assembled
    # Main_df has the expected structure (columns, types) and that its
    # columns stay inside the plausibility bounds of
    # Validation_bounding_simulation.csv, before any parameter is
    # loaded on top of it.
    validate_Main_df(
      Main_df                    = Main_df,
      bounding_validation_config = bounding_validation_config,
      required_cols              = parameters$needed_cols_assembly
    )
  }

  # -------------------------------------------------------------
  # C. Parameters
  # Loads every configuration file of 02_Config, in the order of their
  # numbers, then checks the relations between parameters. Once the
  # forecast parameters are loaded, T_ext_24h of Main_df is
  # recalculated, since it needs their default value.
  # Steps:
  #   5. Configuration files
  #   6. Relations between parameters
  #   7. Recalculate T_ext_24h
  # -------------------------------------------------------------
  {
    # -------------------------------------------------------------
    # 5. Configuration files
    # -------------------------------------------------------------
    # load_configuration_files.R is sourced to load every configuration
    # file, from 01_Optimization_parameters.csv to
    # 15_Forecast_parameters.csv, into parameters, and to gather the
    # parameters of each asset of 12_Asset_registry.csv.
    source(file.path("30_Simulation", "04_Scripts", "load_configuration_files.R"), local = TRUE)

    # -------------------------------------------------------------
    # 6. Relations between parameters
    # The relations of Validation_parameter_relations.csv need every
    # parameter, so they are checked once all of them are loaded.
    # -------------------------------------------------------------
    # drop_unit_row is called to remove the units row of the relations
    # table, and validate_parameter_relations to check each relation.
    parameter_relations <- read.csv(
      paths$parameter_relations_validation_file,
      comment.char     = "#",
      stringsAsFactors = FALSE,
      strip.white      = TRUE
    )
    parameter_relations <- drop_unit_row(
      table             = parameter_relations,
      file_name         = basename(paths$parameter_relations_validation_file),
      number_columns    = character(0),
      reference_columns = "relation",
      reference_values  = c("<", "<=", ">", ">=")
    )
    # read_file_paths_table is called to give the scope of each file,
    # which decides the assets a relation applies to.
    file_paths_table <- read_file_paths_table(config_path = paths$config_path)
    validate_parameter_relations(
      parameters       = parameters,
      relations        = parameter_relations,
      file_paths_table = file_paths_table
    )
    rm(list = c("parameter_relations", "file_paths_table"))

    # -------------------------------------------------------------
    # 7. Recalculate T_ext_24h
    # T_ext_24h is set to the mean Text of the previous calendar day.
    # The first day has no previous day and takes t_ext_24h_default,
    # from 15_Forecast_parameters.csv, loaded in step 5.
    # -------------------------------------------------------------
    t_ext_24h_default <- parameters$forecast$t_ext_24h_default
    if (is.null(t_ext_24h_default) || is.na(t_ext_24h_default)) {
      stop("t_ext_24h_default is missing\n")
    }

    row_dates       <- as.Date(Main_df$time)
    daily_mean_text <- tapply(Main_df$Text, row_dates, mean, na.rm = TRUE)
    unique_dates    <- sort(unique(row_dates))
    previous_dates  <- unique_dates - 1

    previous_day_means                    <- rep(t_ext_24h_default, length(unique_dates))
    names(previous_day_means)             <- as.character(unique_dates)
    has_previous                          <- as.character(previous_dates) %in% names(daily_mean_text)
    previous_day_means[has_previous]      <- daily_mean_text[as.character(previous_dates[has_previous])]

    Main_df$T_ext_24h <- previous_day_means[as.character(row_dates)]

    rm(list = c("t_ext_24h_default", "row_dates", "daily_mean_text",
                "unique_dates", "previous_dates", "previous_day_means",
                "has_previous"))
    rm(list = c("validation_config", "bounding_validation_config"))
  }

  # -------------------------------------------------------------
  # D. The tables of the assets
  # Each asset of the registry gets its table, on the time grid of
  # Main_df, built by the type of model of the asset.
  # Steps:
  #   8. Build and validate the table of each asset
  # -------------------------------------------------------------
  {
    # -------------------------------------------------------------
    # 8. Build and validate the table of each asset
    # The table of an asset is built by its type of model, from its
    # contract, and then it gets the copy of its inputs. The
    # operations that prepare it are run in run_simulation().
    # -------------------------------------------------------------
    assets <- list()
    for (CONT_001 in names(parameters$assets)) {
      # model_type_contract is called to get the operations of the
      # type of model of the asset, which builds its table.
      model <- model_type_contract(parameters$assets[[CONT_001]]$asset_type)

      # The operation new_table is called to synthesize the table of
      # the asset on the time grid of Main_df.
      asset_df <- model$new_table(
        time  = Main_df$time,
        paths = paths
      )

      # The columns the assembled table must hold are those of the
      # type of model of the asset, and a type with no columns in
      # 02_Needed_cols.csv stops the run.
      asset_type <- parameters$assets[[CONT_001]]$asset_type
      if (!asset_type %in% names(parameters$asset_cols_assembly)) {
        stop("load_all_parameters: 02_Needed_cols.csv has no columns ",
             "for the type of model ", asset_type, " of ", CONT_001)
      }

      # validate_asset_df is called to check that the table has the
      # rows of Main_df and the columns, types and flags its type
      # needs, before anything is prepared on it.
      validate_asset_df(
        asset_df      = asset_df,
        time          = Main_df$time,
        required_cols = parameters$asset_cols_assembly[[asset_type]],
        asset_id      = CONT_001
      )

      assets[[CONT_001]] <- list(df = asset_df)

      # console_message is called to write the line of this asset: the
      # size of its table.
      console_message(
        label = "DATA",
        text  = paste0(CONT_001, ": table of ", nrow(asset_df), " rows, ",
                       ncol(asset_df), " columns")
      )
    }
    rm(list = c("CONT_001", "model", "asset_df", "asset_type"))

    # copy_asset_inputs is called to give the table of each asset a
    # copy of the columns of Main_df its type declares as inputs.
    # T_ext_24h is final since block 7, and the tables are cut by the
    # same rows as Main_df afterwards, so the copies stay equal to it.
    assets <- copy_asset_inputs(
      Main_df    = Main_df,
      assets     = assets,
      parameters = parameters,
      rows       = NULL,
      columns    = unique(unlist(parameters$asset_input_cols))
    )
  }

  # -------------------------------------------------------------
  # 9. Return Main_df, the assets and parameters
  # -------------------------------------------------------------
  {
    return(
      list(
        Main_df    = Main_df,
        assets     = assets,
        parameters = parameters
      )
    )
  }
}
