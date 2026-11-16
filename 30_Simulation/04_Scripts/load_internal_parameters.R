# -------------------------------------------------------------
# Script: load_internal_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads the internal parameters: what the assembly of Main_df and the
# loaders of the configuration files need before any of those files
# is read.
#   - the computing parameters, which set the master time grid of
#     Main_df
#   - the physical properties
#   - the debug and configuration switches
#   - the list of needed columns
# Every file is validated against the parameter catalogue as it is
# read. The verification battery sources this script too, so the two
# load the same parameters in the same order.
# The scripts it sources run in the environment this script runs in
# (local = TRUE), so they fill the parameters of whoever sources it.
# -------------------------------------------------------------
# Inputs
#   paths             : List. Paths built by initialize_simulator().
#   validation_config : Named list. The parameter catalogue, read by
#                       load_parameter_catalogue().
#   parameters        : List. The parameters being assembled, empty
#                       when this script starts.
# -------------------------------------------------------------
# Outputs
#   parameters, with the sub-lists:
#     - computing
#     - physical_properties
#     - debug_and_config
#     - needed_cols          : every column of Main_df, in the order
#                              of the output table Main_df_computed
#     - needed_cols_assembly : the columns the assembled Main_df
#                              must hold
#     - asset_cols           : a list with one element per type of
#                              model, with every column of the table
#                              of an asset of the type, time first,
#                              in the order of the output table of
#                              each asset
#     - asset_cols_assembly  : a list with one element per type of
#                              model, with the columns the assembled
#                              table of an asset of the type must
#                              hold
#     - asset_input_cols     : a list with one element per type of
#                              model, with the inputs of the type:
#                              the columns of Main_df that the table
#                              of each asset of the type holds a
#                              copy of during the whole run
#     - joined_cols          : every column of Main_df and of the
#                              tables of every type, once, in the
#                              order of the pieces the markets and
#                              the execution work on
#     - itinerary_variables  : a list with one element per type of
#                              model, with the variables of the type
#                              expanded into the four itineraries
#                              (see itinerary_columns())
#   One LOAD line is written to the console, once the parameters are
#   loaded. The scripts it sources write nothing.
# -------------------------------------------------------------
# Code outline
# 1. Computing parameters
# 2. Physical properties
# 3. Debug and configuration
# 4. Needed columns
# 5. Report
# -------------------------------------------------------------
# Usage instructions
#   source(file.path("30_Simulation", "04_Scripts",
#                    "load_internal_parameters.R"))
#   Not called: sourced by load_all_parameters(), which supplies
#   paths, validation_config and parameters.
# -------------------------------------------------------------

# -------------------------------------------------------------
# 1. Computing parameters
# The numerical constants of the simulation engine: the resolution of
# the master time grid every dataframe is built on, the tolerance
# below which a market slot's planned energy is treated as zero, and
# the time margin the flexibility event generator keeps between
# events. They are loaded before Main_df, because its assembly needs
# the master resolution.
# -------------------------------------------------------------
{
  # load_parameter_file is called to read 01_computing_parameters.csv
  # and check every value against the parameter catalogue.
  parameters$computing <- load_parameter_file(
    paths$computing_parameters_file,
    validation_config
  )
}

# -------------------------------------------------------------
# 2. Physical properties
# -------------------------------------------------------------
{
  # load_03_physical_properties.R is sourced to load and validate
  # 03_Physical_properties.csv into parameters$physical_properties,
  # and to compare it with its reference values.
  source(file.path("30_Simulation", "04_Scripts", "load_03_physical_properties.R"), local = TRUE)
}

# -------------------------------------------------------------
# 3. Debug and configuration
# -------------------------------------------------------------
{
  # load_16_debug_and_config.R is sourced to load and validate
  # 16_Debug_and_config.csv into parameters$debug_and_config.
  source(file.path("30_Simulation", "04_Scripts", "load_16_debug_and_config.R"), local = TRUE)
}

# -------------------------------------------------------------
# 4. Needed columns
# -------------------------------------------------------------
{
  # load_needed_columns is called to read 02_Needed_cols.csv, check it
  # against the parameter catalogue, and expand the columns of
  # System_variables_df and of the tables of each type of model from
  # the variable registries of the system and of the types.
  needed_cols <- load_needed_columns(
    needed_cols_path  = paths$needed_cols_file,
    paths             = paths,
    validation_config = validation_config
  )

  parameters$needed_cols          <- needed_cols$all
  parameters$needed_cols_assembly <- needed_cols$assembly
  parameters$asset_cols           <- needed_cols$asset
  parameters$asset_cols_assembly  <- needed_cols$asset_assembly
  parameters$asset_input_cols     <- needed_cols$asset_input
  parameters$joined_cols          <- needed_cols$joined
  parameters$itinerary_variables  <- needed_cols$itinerary_variables
  rm(list = "needed_cols")
}

# -------------------------------------------------------------
# 5. Report
# -------------------------------------------------------------
{
  # console_message is called to write the only line of this script:
  # what it loaded and the number of columns of Main_df.
  console_message(
    label = "LOAD",
    text  = paste0("Internal parameters: computing parameters, ",
                   "physical properties, debug and configuration, ",
                   length(parameters$needed_cols), " needed columns")
  )
}
