# -------------------------------------------------------------
# Function: building_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the contract of the type of model Building: the table of
# the functions through which the rest of the simulator operates a
# building, the thermal model of a building with a heat pump. It is
# the table that model_type_contract() returns for an asset whose
# asset_type is Building. The operations, with their arguments and
# their results, are described in model_type_contract(); here each
# one is bound to the function of the building that carries it out.
# Every function named here lives in this folder,
# 30_Simulation/05_Models/01_Building/03_Functions/, and no code
# outside the folder of the type calls them by name.
# -------------------------------------------------------------
# The operations
# For a building:
#   - load_parameters: its parameter groups, read from the files of
#       its configuration folder.
#   - variable_registry: the path of its variable registry, which
#       declares the columns of its table.
#   - new_table: its table on the time grid, with the columns of its
#       variable registry.
#   - prepare_year: the climate of each day, tagged on the whole
#       year.
#   - initial_state: its initial condition, written into row 1 of
#       its table.
#   - prepare_period: its occupancy, its scheduling window and its
#       reference temperature profiles, on the simulated period.
#   - gene_options: the number of setpoint modes.
#   - decode_genes: turns the genes, one setpoint mode per market
#       interval, into the setpoints of the horizon.
#   - default_control: the lowest setpoint mode, the control of a
#       row that no market has determined yet.
#   - can_hold: whether it can keep its electricity apart from its
#       plan in a flexibility itinerary.
#   - plan_start_state: starts the plan from the executed state of
#       the building.
#   - simulate_itinerary: the RC model of the building and its heat
#       pump, over a chunk, for one itinerary.
#   - comfort: the comfort term of the reward, from the comfort
#       bands of the building.
#   - window_feasible: the technical rules of the heat pump for the
#       flexibility windows of one leg.
#   - slot_offer: whether the building may have something to offer
#       on a new flexibility window.
#   - window_draft: the contribution of the building to a
#       flexibility window, before the commitment margin.
#   - margin_fit: fits the margin data of the building inside the
#       band of the system.
#   - margin_energy: the electricity of the heat pump on each row of
#       the margin data.
#   - window_contribution: the itinerary of the building on a
#       flexibility window, with the technical rules applied.
#   - restate_systems: the heating and cooling systems with which a
#       window already sold may be redrawn.
#   - hold_room: the electricity the heat pump can hold on each row
#       of a window already sold.
#   - window_hold: holds a commitment already sold, within the limits
#       of the heat pump. It holds the Commitment Phase alone: the
#       window held (hold) is not read.
#   - continue_window_tail: continues the Neutral and Recovery Phases
#       of a window whose Commitment Phase ended before the chunk.
#   - tail_state: the state a window left in the itinerary at the
#       start of the horizon.
#   - execute_step: runs the building over a step of the simulation,
#       with the setpoints it holds.
#   - reads_rest_net: FALSE, it does not read the net electricity of
#       the rest of the system.
#   - stored_energy_change: NULL, a building stores no energy that
#       the reward values.
#   - recovery_choices: NULL, the Recovery Phase of a building has no
#       alternatives.
# -------------------------------------------------------------
# Auxiliary functions
# The operations that are a line are written as auxiliary functions of
# building_model_contract(), in this file, after it. They are named
# functions, defined once when the file is sourced, so that the
# contract hands over the same functions on every call instead of
# creating them again. The file holds:
#   - building_model_contract() (main function)
#   - building_window_hold()
#   - building_reads_rest_net()
#   - building_stored_energy_change()
#   - building_recovery_choices()
# -------------------------------------------------------------
# Inputs
#   None.
# -------------------------------------------------------------
# Outputs
#   Named list of functions, one per operation above.
# -------------------------------------------------------------
# Code outline
# 1. Bind each operation to its function
# -------------------------------------------------------------
# Usage instructions
# contract <- building_model_contract()
# contract$simulate_itinerary(
#   period_chunk        = period_chunk,
#   asset               = asset,
#   calculation_mode    = 1,
#   calculation_context = "plan"
# )
# -------------------------------------------------------------

building_model_contract <- function() {

  # -------------------------------------------------------------
  # 1. Bind each operation to its function
  # The functions are named, not called: the caller calls the
  # operation it needs.
  # -------------------------------------------------------------
  {
    contract <- list(
      load_parameters      = load_building_parameters,
      variable_registry    = building_variable_registry,
      new_table            = building_new_table,
      prepare_year         = prepare_climate,
      initial_state        = building_initial_state,
      prepare_period       = building_prepare_period,
      gene_options         = building_gene_options,
      decode_genes         = decode_building_genes,
      default_control      = lowest_mode_setpoints,
      can_hold             = building_can_hold,
      plan_start_state     = building_plan_start_state,
      simulate_itinerary   = period_calculation,
      comfort              = comfort_term,
      window_feasible      = flex_window_is_feasible,
      slot_offer           = building_slot_offer,
      window_draft         = flex_window_draft,
      margin_fit           = apply_commitment_margin,
      margin_energy        = building_margin_energy,
      window_contribution  = flex_evaluation,
      restate_systems      = building_restate_systems,
      hold_room            = building_hold_room,
      # A building holds the Commitment Phase alone; hold is not read.
      window_hold          = building_window_hold,
      continue_window_tail = continue_standing_tail,
      tail_state           = building_tail_state,
      execute_step         = implement_control_step,
      reads_rest_net       = building_reads_rest_net,
      # A building stores no energy that the reward values.
      stored_energy_change = building_stored_energy_change,
      # The Recovery Phase of a building has no alternatives.
      recovery_choices = building_recovery_choices
    )
  }

  return(contract)
}

# -------------------------------------------------------------
# Function: building_window_hold()
# Auxiliary function of building_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation window_hold of the type of model Building, an auxiliary
# function of building_model_contract(), which hands it over in the
# contract of the type.
# A building holds the Commitment Phase alone; hold is not read.
# -------------------------------------------------------------
# Inputs
#   period_chunk : the argument of the operation window_hold, as every
#     type of model receives it.
#   leg : the argument of the operation window_hold, as every type of
#     model receives it.
#   window_rows : the argument of the operation window_hold, as every
#     type of model receives it.
#   standing : the argument of the operation window_hold, as every
#     type of model receives it.
#   hold : the argument of the operation window_hold, as every type of
#     model receives it. Not read.
#   parameters : the argument of the operation window_hold, as every
#     type of model receives it.
#   asset : the argument of the operation window_hold, as every type
#     of model receives it.
# -------------------------------------------------------------
# Outputs
#   The chunk with the share of the building held on its electricity
#   itinerary of the leg, as hold_standing_window() returns it.
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation window_hold.
# contract <- building_model_contract()
# -------------------------------------------------------------

building_window_hold <- function(period_chunk,
                                 leg,
                                 window_rows,
                                 standing,
                                 hold,
                                 parameters,
                                 asset
                                 ) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    # hold_standing_window is called to hold the share asked of the
    # building on its electricity itinerary of the leg, within the
    # limits of the heat pump.
    return(hold_standing_window(
      period_chunk = period_chunk,
      leg          = leg,
      window_rows  = window_rows,
      standing     = standing,
      parameters   = parameters,
      asset        = asset
    ))
  }
}

# -------------------------------------------------------------
# Function: building_reads_rest_net()
# Auxiliary function of building_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation reads_rest_net of the type of model Building, an auxiliary
# function of building_model_contract(), which hands it over in the
# contract of the type.
# -------------------------------------------------------------
# Inputs
#   asset : the argument of the operation reads_rest_net, as every
#     type of model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always FALSE.
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation reads_rest_net.
# contract <- building_model_contract()
# -------------------------------------------------------------

building_reads_rest_net <- function(asset) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(FALSE)
  }
}

# -------------------------------------------------------------
# Function: building_stored_energy_change()
# Auxiliary function of building_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation stored_energy_change of the type of model Building, an
# auxiliary function of building_model_contract(), which hands it over
# in the contract of the type.
# A building stores no energy that the reward values.
# -------------------------------------------------------------
# Inputs
#   asset_df : the argument of the operation stored_energy_change, as
#     every type of model receives it. Not read.
#   itinerary : the argument of the operation stored_energy_change, as
#     every type of model receives it. Not read.
#   asset : the argument of the operation stored_energy_change, as
#     every type of model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always NULL.
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation stored_energy_change.
# contract <- building_model_contract()
# -------------------------------------------------------------

building_stored_energy_change <- function(asset_df,
                                          itinerary,
                                          asset
                                          ) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(NULL)
  }
}

# -------------------------------------------------------------
# Function: building_recovery_choices()
# Auxiliary function of building_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation recovery_choices of the type of model Building, an
# auxiliary function of building_model_contract(), which hands it over
# in the contract of the type.
# The Recovery Phase of a building has no alternatives.
# -------------------------------------------------------------
# Inputs
#   asset : the argument of the operation recovery_choices, as every
#     type of model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always NULL.
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation recovery_choices.
# contract <- building_model_contract()
# -------------------------------------------------------------

building_recovery_choices <- function(asset) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(NULL)
  }
}
