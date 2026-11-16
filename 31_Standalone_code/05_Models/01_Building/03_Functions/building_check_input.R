# -------------------------------------------------------------
# Function: building_check_input.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation check_input of the type of model Building: checks the
# block of a building in the input of a call, beyond the general
# rules every block meets (the interval grid, the type and the range
# of each vector). The call stops if:
#   - Ti or Te is missing at i0 in the plan itinerary: the plan of a
#     building starts from its state at i0
#   - Overall_Climate is not one of the options of the parameter
#     catalogue (rows of the file building_input)
# -------------------------------------------------------------
# Inputs
#   asset_input : Named list. The block of the building in the input
#                 of the call, with Overall_Climate and the data
#                 frames of its itineraries, whose first row is the
#                 interval that starts at i0.
#   parameters  : Named list. The parameters of the system. Uses
#                 parameter_catalogue.
#   asset       : Named list. The parameters of the building, its
#                 entry of parameters$assets. Uses asset_id, to name
#                 the building in the messages.
# -------------------------------------------------------------
# Outputs
#   The block of the building, with Overall_Climate as text without
#   surrounding spaces. The call stops if the block is invalid.
# -------------------------------------------------------------
# Code outline
# 1. State at i0
# 2. Climate season
# -------------------------------------------------------------
# Usage instructions
# asset_input <- building_check_input(
#   asset_input = asset_input,
#   parameters  = parameters,
#   asset       = parameters$assets[["Building_001"]]
# )
# -------------------------------------------------------------

building_check_input <- function(asset_input,
                                 parameters,
                                 asset
                                 ) {

  # -------------------------------------------------------------
  # 1. State at i0
  # -------------------------------------------------------------
  {
    plan <- asset_input$itineraries$plan
    if (is.null(plan) || length(plan$Ti) == 0 || length(plan$Te) == 0 ||
        is.na(plan$Ti[1]) || is.na(plan$Te[1])) {
      stop(asset$asset_id, ": the plan itinerary must give Ti and Te at ",
           "i0 (its first interval)")
    }
    rm(list = "plan")
  }

  # -------------------------------------------------------------
  # 2. Climate season
  # -------------------------------------------------------------
  {
    asset_input$Overall_Climate <- trimws(
      as.character(asset_input$Overall_Climate)
    )

    # validate_parameter_config is called to check the climate season
    # against its rule of the parameter catalogue.
    validate_parameter_config(
      values            = asset_input["Overall_Climate"],
      file_name         = "building_input",
      validation_config = parameters$parameter_catalogue
    )
  }

  return(asset_input)
}
