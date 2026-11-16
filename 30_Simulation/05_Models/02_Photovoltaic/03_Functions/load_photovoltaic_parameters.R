# -------------------------------------------------------------
# Function: load_photovoltaic_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads the parameter groups of one photovoltaic installation. It is
# the operation load_parameters of the contract of the type
# Photovoltaic (see model_type_contract()). The installation has one
# file in its configuration folder, 17_Photovoltaic_parameters.csv,
# validated against the parameter catalogue as it is read. The
# reference conditions of the modules (the standard test conditions
# of the efficiency and the conditions of the NOCT) and the solar
# constant are common to every installation: they come from the
# physical properties of the system, and each installation takes a
# copy, so that its model finds everything it needs in its own entry
# of parameters$assets.
# -------------------------------------------------------------
# Inputs
#   asset_paths                : List. The paths of the files of the
#                                asset, as build_asset_paths()
#                                gives them.
#   validation_config          : Named list. The parameter catalogue.
#   bounding_validation_config : Data frame. Content of
#                                Validation_bounding_simulation.csv.
#                                Not read.
#   parameters                 : List. The parameters of the system
#                                already loaded. It must hold
#                                physical_properties.
# -------------------------------------------------------------
# Outputs
#   Named list with the groups of the installation, in this order:
#   - photovoltaic: the 15 parameters of the file:
#     - Latitude
#     - Longitude
#     - Irradiance_time_offset
#     - Diffuse_threshold
#     - Min_sun_elevation
#     - Tilt
#     - Azimuth
#     - Albedo
#     - Module_area
#     - Module_efficiency
#     - DC_losses
#     - Temperature_coefficient
#     - NOCT
#     - Inverter_efficiency
#     - Inverter_power
#   - reference_conditions: PV_STC_irradiance,
#     PV_STC_cell_temperature, PV_NOCT_irradiance and
#     PV_NOCT_ambient_temperature
#   - sun: Solar_constant
#   The run stops if one of the reference conditions or the solar
#   constant is missing in parameters$physical_properties.
# -------------------------------------------------------------
# Code outline
# 1. Load the file of the installation
# 2. Take the reference conditions of the modules and the solar
#    constant
# -------------------------------------------------------------
# Usage instructions
# groups <- load_photovoltaic_parameters(
#   asset_paths                = asset_paths,
#   validation_config          = validation_config,
#   bounding_validation_config = bounding_validation_config,
#   parameters                 = parameters
# )
# -------------------------------------------------------------

load_photovoltaic_parameters <- function(asset_paths,
                                         validation_config,
                                         bounding_validation_config,
                                         parameters) {

  # -------------------------------------------------------------
  # 1. Load the file of the installation
  # -------------------------------------------------------------
  {
    # load_parameter_file is called to read the parameters of the
    # installation and check every value against the parameter
    # catalogue.
    photovoltaic_parameters <- load_parameter_file(
      asset_paths$photovoltaic_file,
      validation_config
    )
  }

  # -------------------------------------------------------------
  # 2. Take the reference conditions of the modules and the solar
  #    constant
  # -------------------------------------------------------------
  {
    reference_names <- c("PV_STC_irradiance", "PV_STC_cell_temperature",
                         "PV_NOCT_irradiance",
                         "PV_NOCT_ambient_temperature")
    missing_names   <- setdiff(c(reference_names, "Solar_constant"),
                               names(parameters$physical_properties))
    if (length(missing_names) > 0) {
      stop("load_photovoltaic_parameters: the physical properties of ",
           "the system do not hold ",
           paste(missing_names, collapse = ", "))
    }

    photovoltaic_groups <- list(
      photovoltaic         = photovoltaic_parameters,
      reference_conditions = parameters$physical_properties[reference_names],
      sun                  = parameters$physical_properties["Solar_constant"]
    )

    rm(list = c("photovoltaic_parameters", "reference_names", "missing_names"))
  }

  return(photovoltaic_groups)
}
