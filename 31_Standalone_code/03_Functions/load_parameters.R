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
# 00_Validation/Parameter_config.csv (or its own validation table)
# before its values are used, and a failed check stops execution.
# -------------------------------------------------------------
# Inputs
#   config_path : Character. Configuration folder (02_Config).
# -------------------------------------------------------------
# Outputs
#   parameters : Named list with the sub-lists:
#     - computing          : main_resolution_sec, flex_energy_tol
#     - physical_properties: Cp_air, dens_air
#     - market             : market_resolution
#     - debug_and_config   : parallel, parallel_workers, random_seed
#                            (set later from the input)
#     - optimization       : the genetic algorithm parameters
#     - control            : control, mode and flexibility parameters
#     - reward             : reward and comfort band parameters
#     - operational_temperature_corrections : anticipation and
#                            seasonal corrections of the comfort bands
#     - model              : building model, with the ventilation
#                            resistances added by compute_Rvent()
#     - setpoint_modes     : data frame of modes (mode, heating,
#                            cooling)
#     - input_validation   : rules of 00_Validation/Validation_Inputs.csv
# -------------------------------------------------------------
# Code outline
# 1. Read the validation tables
# 2. Computing parameters and physical properties
# 3. Run configuration
# 4. Optimization, control and flexibility parameters
# 5. Reward parameters
#    5.1. Operational temperature corrections
# 6. Model parameters
# 7. Modes
# 8. Consistency of the time resolutions
# -------------------------------------------------------------
# Usage instructions
# parameters <- load_parameters(config_path)
# -------------------------------------------------------------
# Where this function/script is used
#   - optimize_market(): once per call, before the inputs are read.
# -------------------------------------------------------------
# functions/scripts called
#   - read_and_validate_parameter_csv(): reads a parameter,value,unit
#     file and checks it against its validation rules
#   - validate_physical_properties(): compares the air properties
#     with their reference values
#   - load_optimization_parameters(): builds the optimization sub-list
#   - load_flexibility_event_parameters(): builds the flexibility
#     part of the control sub-list
#   - validate_model_parameters(): checks the model parameters
#   - compute_Rvent(): adds the ventilation resistances to the model
# -------------------------------------------------------------

load_parameters <- function(config_path) {

  # -------------------------------------------------------------
  # 1. Read the validation tables
  # -------------------------------------------------------------
  {
    read_rules <- function(file_name) {
      read.csv(file.path(config_path, "00_Validation", file_name),
               comment.char     = "#",
               stringsAsFactors = FALSE)
    }

    validation_config           <- read_rules("Parameter_config.csv")
    computing_validation_config <- read_rules("Validation_01_computing_parameters.csv")
    bounding_validation_config  <- read_rules("Validation_bounding_simulation.csv")
    input_validation_config     <- read_rules("Validation_Inputs.csv")

    parameters <- list()
  }

  # -------------------------------------------------------------
  # 2. Computing parameters and physical properties
  # -------------------------------------------------------------
  {
    # read_and_validate_parameter_csv is called to read the computing
    # parameters and check them against their own validation table.
    raw_values <- read_and_validate_parameter_csv(
      file.path(config_path, "00_Inner_parameters", "01_computing_parameters.csv"),
      "01_computing_parameters.csv",
      computing_validation_config
    )
    parameters$computing <- lapply(raw_values, as.numeric)

    # read_and_validate_parameter_csv is called to read the air
    # properties used to turn air changes into ventilation resistances.
    raw_values <- read_and_validate_parameter_csv(
      file.path(config_path, "00_Inner_parameters", "03_Physical_properties.csv"),
      "03_Physical_properties.csv",
      validation_config
    )
    parameters$physical_properties <- lapply(raw_values, as.numeric)

    # read_and_validate_parameter_csv is called again to read the
    # reference values the air properties are compared against.
    reference_values <- read_and_validate_parameter_csv(
      file.path(config_path, "00_Validation", "Validation_03_Physical_properties.csv"),
      "Validation_03_Physical_properties.csv",
      validation_config
    )

    # validate_physical_properties is called to warn when the air
    # properties differ from their reference values.
    validate_physical_properties(parameters$physical_properties,
                                 lapply(reference_values, as.numeric))

    rm(raw_values, reference_values)
  }

  # -------------------------------------------------------------
  # 3. Run configuration
  # -------------------------------------------------------------
  # random_seed is not a configuration value: it comes with each call
  # and optimize_market() sets it.
  # -------------------------------------------------------------
  {
    # read_and_validate_parameter_csv is called to read the market
    # resolution and the execution options of the optimizer.
    raw_values <- read_and_validate_parameter_csv(
      file.path(config_path, "03_Run_config.csv"),
      "03_Run_config.csv",
      validation_config
    )
    raw_values <- lapply(raw_values, function(x) as.numeric(trimws(as.character(x))))

    parameters$market <- list(
      market_resolution = raw_values$market_resolution
    )
    parameters$debug_and_config <- list(
      parallel         = raw_values$parallel,
      parallel_workers = raw_values$parallel_workers,
      random_seed      = 0
    )
    rm(raw_values)
  }

  # -------------------------------------------------------------
  # 4. Optimization, control and flexibility parameters
  # -------------------------------------------------------------
  {
    # read_and_validate_parameter_csv is called to read the genetic
    # algorithm parameters, which load_optimization_parameters() then
    # turns into their sub-list.
    raw_values <- read_and_validate_parameter_csv(
      file.path(config_path, "01_Optimization_parameters.csv"),
      "01_Optimization_parameters.csv",
      validation_config
    )
    parameters$optimization <- load_optimization_parameters(raw_values)

    # read_and_validate_parameter_csv is called to read the control
    # parameters of the mode-based control.
    raw_values <- read_and_validate_parameter_csv(
      file.path(config_path, "02_Control.csv"),
      "02_Control.csv",
      validation_config
    )
    parameters$control <- lapply(raw_values, function(x) as.numeric(trimws(as.character(x))))

    # read_and_validate_parameter_csv is called to read the
    # flexibility event parameters, which
    # load_flexibility_event_parameters() turns into the flexibility
    # part of the control sub-list.
    raw_values <- read_and_validate_parameter_csv(
      file.path(config_path, "08_Flexibility_Event_Configuration.csv"),
      "08_Flexibility_Event_Configuration.csv",
      validation_config
    )
    parameters$control <- c(parameters$control,
                            load_flexibility_event_parameters(raw_values))
    rm(raw_values)
  }

  # -------------------------------------------------------------
  # 5. Reward parameters
  # -------------------------------------------------------------
  {
    # read_and_validate_parameter_csv is called to read the weights of
    # the reward and the comfort bands.
    raw_values <- read_and_validate_parameter_csv(
      file.path(config_path, "09_Reward_parameters.csv"),
      "09_Reward_parameters.csv",
      validation_config
    )
    parameters$reward <- lapply(raw_values, as.numeric)
    rm(raw_values)
  }

  # -------------------------------------------------------------
  # 5.1. Operational temperature corrections
  # -------------------------------------------------------------
  {
    # read_and_validate_parameter_csv is called to read the
    # anticipation and seasonal corrections of the comfort bands.
    raw_values <- read_and_validate_parameter_csv(
      file.path(config_path, "10_Operational_temperature_corrections.csv"),
      "10_Operational_temperature_corrections.csv",
      validation_config
    )
    parameters$operational_temperature_corrections <- lapply(raw_values, as.numeric)
    rm(raw_values)
  }

  # -------------------------------------------------------------
  # 6. Model parameters
  # -------------------------------------------------------------
  {
    # read_and_validate_parameter_csv is called to read the building
    # and heat pump parameters.
    raw_values <- read_and_validate_parameter_csv(
      file.path(config_path, "11_Model_parameters.csv"),
      "11_Model_parameters.csv",
      validation_config
    )

    # validate_model_parameters is called to check the parameters that
    # need more than a range, such as the building volume.
    model_parameters <- validate_model_parameters(
      model_parameters           = lapply(raw_values, as.numeric),
      bounding_validation_config = bounding_validation_config
    )

    # compute_Rvent is called to turn the air change rates into the
    # ventilation resistances the physics uses.
    parameters$model <- compute_Rvent(model_parameters,
                                      parameters$physical_properties)
    rm(raw_values, model_parameters)
  }

  # -------------------------------------------------------------
  # 7. Modes
  # -------------------------------------------------------------
  # The table carries a units row under its column names, which is
  # dropped. Modes must be the consecutive integers 1..n, because the
  # optimizer encodes each mode by its number.
  # -------------------------------------------------------------
  {
    setpoint_modes <- read.csv(file.path(config_path, "13_Modes_setpoints.csv"),
                               comment.char     = "#",
                               stringsAsFactors = FALSE)

    required_columns <- c("mode", "heating", "cooling")
    missing_columns  <- setdiff(required_columns, names(setpoint_modes))
    if (length(missing_columns) > 0) {
      stop("13_Modes_setpoints.csv is missing required columns: ",
           paste(missing_columns, collapse = ", "))
    }

    if (nrow(setpoint_modes) > 0 &&
        identical(trimws(tolower(as.character(setpoint_modes$mode[1]))), "text")) {
      setpoint_modes <- setpoint_modes[-1, , drop = FALSE]
    }

    for (CONT_001 in required_columns) {
      setpoint_modes[[CONT_001]] <- suppressWarnings(as.numeric(setpoint_modes[[CONT_001]]))
      if (any(is.na(setpoint_modes[[CONT_001]]))) {
        stop("13_Modes_setpoints.csv contains missing or non-numeric values ",
             "in column '", CONT_001, "'")
      }
    }

    if (nrow(setpoint_modes) == 0 ||
        !identical(as.integer(sort(setpoint_modes$mode)),
                   seq_len(nrow(setpoint_modes)))) {
      stop("13_Modes_setpoints.csv column 'mode' must contain the ",
           "consecutive integers starting at 1")
    }

    rownames(setpoint_modes)  <- NULL
    parameters$setpoint_modes <- setpoint_modes
    rm(setpoint_modes, required_columns, missing_columns, CONT_001)
  }

  # -------------------------------------------------------------
  # 8. Consistency of the time resolutions
  # -------------------------------------------------------------
  {
    if ((parameters$market$market_resolution * 60) %%
        parameters$computing$main_resolution_sec != 0) {
      stop("market_resolution (minutes) must be a multiple of ",
           "main_resolution_sec (", parameters$computing$main_resolution_sec,
           " s)")
    }

    parameters$input_validation <- input_validation_config
  }

  rm(read_rules, validation_config, computing_validation_config,
     bounding_validation_config, input_validation_config)

  return(parameters)
}
