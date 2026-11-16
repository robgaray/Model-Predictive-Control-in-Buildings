# -------------------------------------------------------------
# Function: itinerary_columns.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Returns the columns of one itinerary of the assets: the columns of
# every variable that the variable registry of each type of model
# of the assets of the system (Simulation_Variables_<type>.txt)
# expands into the four itineraries, with the suffix of the one
# asked for. A type that no asset of the registry has adds no
# column. A column that several types declare is named once. The
# itineraries are:
#   - exec           : what was executed
#   - plan           : the plan
#   - plan_flex_down : the downward flexibility itinerary
#   - plan_flex_up   : the upward flexibility itinerary
# The columns are built from the variables, not found by their
# suffix, so a column that only ends like an itinerary is never taken
# for one. The commitments (Elec_flex_down_plan, Elec_flex_up_plan)
# and the phase codes (Flex_phase_down_plan, Flex_phase_up_plan) end
# in "_plan" but belong to no itinerary.
# -------------------------------------------------------------
# Inputs
#   itinerary  : Character scalar. One of "exec", "plan",
#                "plan_flex_down" or "plan_flex_up".
#   parameters : List. Uses itinerary_variables, a list with one
#                element per type of model, each with the variables
#                of its registry with scenario == "yes", in registry
#                order, and assets, the asset registry, whose
#                asset_type selects the types.
# -------------------------------------------------------------
# Outputs
#   Character vector. The columns of the itinerary of every type of
#   model that an asset of the system has, once each, in registry
#   order and then in the order of the types.
# -------------------------------------------------------------
# Code outline
# 1. Check the itinerary
# 2. Build its columns
# -------------------------------------------------------------
# Usage instructions
# plan_cols <- itinerary_columns("plan", parameters)
# -------------------------------------------------------------

itinerary_columns <- function(itinerary, parameters) {

  # -------------------------------------------------------------
  # 1. Check the itinerary
  # -------------------------------------------------------------
  {
    itineraries <- c("exec", "plan", "plan_flex_down", "plan_flex_up")
    if (length(itinerary) != 1 || !itinerary %in% itineraries) {
      stop("itinerary_columns: itinerary must be one of ",
           paste(itineraries, collapse = ", "))
    }
    rm(list = "itineraries")
  }

  # -------------------------------------------------------------
  # 2. Build its columns
  # -------------------------------------------------------------
  {
    asset_types <- unique(vapply(parameters$assets,
                                 function(CONT_001) CONT_001$asset_type,
                                 character(1)))
    columns     <- unique(paste0(
      unlist(parameters$itinerary_variables[
        names(parameters$itinerary_variables) %in% asset_types
      ], use.names = FALSE),
      "_", itinerary
    ))
    rm(list = "asset_types")
  }

  return(columns)
}
