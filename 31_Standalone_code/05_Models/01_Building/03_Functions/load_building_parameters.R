# -------------------------------------------------------------
# Function: load_building_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads the parameter groups of one Building from the files of its
# configuration folder, each one validated against the parameter
# catalogue as it is read:
#   - 10_Operational_temperature_corrections.csv
#   - 11_Model_parameters.csv, from which the ventilation
#     resistances are computed
#   - 13_Modes_setpoints.csv, which holds the table of the modes and,
#     above it, the block with the deadband of the hysteresis
#   - 18_Comfort_parameters.csv, with the comfort weight and the
#     comfort bands of the building
# The occupancy of the building is not a configuration file: it
# arrives with each input.
# The modes are the consecutive integers 1..n, because the optimizer
# encodes each mode by its number.
# It is the operation load_parameters of the type Building (see
# model_type_contract()).
# -------------------------------------------------------------
# Inputs
#   asset_paths                : List. The paths of the files of the
#                                asset, as build_asset_paths()
#                                gives them.
#   validation_config          : Named list. The parameter catalogue.
#   bounding_validation_config : Data frame. Content of
#                                Validation_bounding_simulation.csv.
#   parameters                 : List. The parameters of the system
#                                already loaded. It must hold
#                                physical_properties.
# -------------------------------------------------------------
# Outputs
#   Named list with the groups of the building, in this order:
#   - model
#   - operational_temperature_corrections
#   - setpoint_modes, a data frame of modes (mode, heating, cooling)
#   - comfort
#   - control, the block of parameters of the modes file (Deadband),
#     under the group the catalogue gives its rows
#   The run stops if a file has an invalid value.
# -------------------------------------------------------------
# Code outline
# 1. Operational temperature corrections
# 2. Model parameters
# 3. Modes
# 4. Block of the modes file
# 5. Comfort parameters
# 6. Gather the groups
# -------------------------------------------------------------
# Usage instructions
# model  <- model_type_contract("Building")
# groups <- model$load_parameters(
#   asset_paths                = asset_paths,
#   validation_config          = validation_config,
#   bounding_validation_config = bounding_validation_config,
#   parameters                 = parameters
# )
# -------------------------------------------------------------

load_building_parameters <- function(asset_paths,
                                     validation_config,
                                     bounding_validation_config,
                                     parameters) {

  # -------------------------------------------------------------
  # 1. Operational temperature corrections
  # -------------------------------------------------------------
  {
    # load_parameter_file is called to read the corrections of the
    # reference temperature curves, and check every value against the
    # parameter catalogue.
    corrections <- load_parameter_file(
      asset_paths$operational_temperature_corrections_file,
      validation_config
    )
  }

  # -------------------------------------------------------------
  # 2. Model parameters
  # -------------------------------------------------------------
  {
    # load_parameter_file is called to read the building and heat pump
    # parameters.
    model_values <- load_parameter_file(
      asset_paths$model_file,
      validation_config
    )

    # validate_model_parameters is called to check the parameters that
    # need more than a range, such as the building volume.
    model_parameters <- validate_model_parameters(
      model_parameters           = model_values,
      bounding_validation_config = bounding_validation_config,
      model_file_name            = basename(asset_paths$model_file)
    )

    # compute_Rvent is called to turn the air change rates into the
    # ventilation resistances the physics uses.
    model <- compute_Rvent(model_parameters,
                           parameters$physical_properties)
    rm(list = c("model_values", "model_parameters"))
  }

  # -------------------------------------------------------------
  # 3. Modes
  # The table of the modes carries a units row under its column
  # names, which is dropped. It is the part of the file that follows
  # the block of parameters.
  # -------------------------------------------------------------
  {
    mode_file  <- basename(asset_paths$setpoint_mode_file)
    mode_lines <- readLines(asset_paths$setpoint_mode_file)

    # split_config_sections is called to find the lines of the table,
    # which is the whole file when the file holds no block of
    # parameters above it.
    sections <- split_config_sections(mode_lines)
    if (length(sections$table) == 0) {
      stop(mode_file, " does not contain any mode definitions")
    }
    setpoint_modes <- read.csv(
      text             = paste(mode_lines[sections$table], collapse = "\n"),
      comment.char     = "#",
      stringsAsFactors = FALSE
    )

    required_columns <- c("mode", "heating", "cooling")
    missing_columns  <- setdiff(required_columns, names(setpoint_modes))
    if (length(missing_columns) > 0) {
      stop(mode_file, " is missing required columns: ",
           paste(missing_columns, collapse = ", "))
    }

    # drop_unit_row is called to remove the units row, the first row
    # under the header, after checking it is not a mode.
    setpoint_modes <- drop_unit_row(
      table             = setpoint_modes,
      file_name         = mode_file,
      number_columns    = c("heating", "cooling"),
      reference_columns = character(0),
      reference_values  = character(0)
    )

    for (CONT_001 in required_columns) {
      setpoint_modes[[CONT_001]] <- suppressWarnings(
        as.numeric(setpoint_modes[[CONT_001]])
      )
      if (any(is.na(setpoint_modes[[CONT_001]]))) {
        stop(mode_file, " contains missing or non-numeric values ",
             "in column '", CONT_001, "'")
      }
    }

    if (nrow(setpoint_modes) == 0 ||
        !identical(as.integer(sort(setpoint_modes$mode)),
                   seq_len(nrow(setpoint_modes)))) {
      stop(mode_file, " column 'mode' must contain the ",
           "consecutive integers starting at 1")
    }

    rownames(setpoint_modes) <- NULL
    rm(list = c("mode_lines", "sections", "required_columns", "missing_columns",
                "CONT_001"))
  }

  # -------------------------------------------------------------
  # 4. Block of the modes file
  # The block holds the deadband of the hysteresis. It is kept under
  # the group its rows have in the parameter catalogue.
  # -------------------------------------------------------------
  {
    # load_parameter_block is called to read the block of the modes
    # file and check it against the parameter catalogue.
    control_block <- load_parameter_block(
      path              = asset_paths$setpoint_mode_file,
      validation_config = validation_config
    )

    block_rules   <- validation_config$rules[
      validation_config$rules$file == mode_file &
        !validation_config$rules$default %in% c("", "-"), ]
    control_group <- unique(block_rules$group)
    if (length(control_group) != 1) {
      stop("The parameters of the block of ", mode_file,
           " must all belong to one group in the parameter catalogue")
    }
    rm(list = c("block_rules", "mode_file"))
  }

  # -------------------------------------------------------------
  # 5. Comfort parameters
  # The comfort weight and the comfort bands of the building.
  # -------------------------------------------------------------
  {
    # load_parameter_file is called to read the comfort weight and the
    # comfort bands of the building, and check every value against the
    # parameter catalogue.
    comfort <- load_parameter_file(
      asset_paths$comfort_file,
      validation_config
    )
  }

  # -------------------------------------------------------------
  # 6. Gather the groups
  # -------------------------------------------------------------
  {
    building_groups <- list(
      model                               = model,
      operational_temperature_corrections = corrections,
      setpoint_modes                      = setpoint_modes,
      comfort                             = comfort
    )
    building_groups[[control_group]] <- control_block
    rm(list = c("corrections", "model", "setpoint_modes", "comfort",
                "control_block", "control_group"))
  }

  return(building_groups)
}
