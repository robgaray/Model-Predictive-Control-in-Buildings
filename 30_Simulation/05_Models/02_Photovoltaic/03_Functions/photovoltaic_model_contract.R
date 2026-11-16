# -------------------------------------------------------------
# Function: photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the contract of the type of model Photovoltaic: the table of
# the functions through which the rest of the simulator operates a
# photovoltaic installation. It is the table that
# model_type_contract() returns for an asset whose asset_type is
# Photovoltaic. The operations, with their arguments and their
# results, are described in model_type_contract().
# A photovoltaic installation has no control. It produces electricity
# from the solar radiation and the outdoor temperature, and nothing
# the system decides changes what it produces. It has no genes, no
# setpoints, no comfort and no state to carry, and it cannot move its
# electricity in time. Its operations are written for that:
#   - Those that carry out something are bound to functions of this
#     folder, 30_Simulation/05_Models/02_Photovoltaic/03_Functions/:
#     load_parameters, variable_registry, new_table,
#     simulate_itinerary and execute_step.
#   - The others are written below, in the table, because each one
#     is a line: they return what they receive, or an answer that
#     says the installation has nothing to do there.
#   - decode_genes, margin_fit and margin_energy work on genes and on
#     the margin data of a window, which an installation never
#     holds. They stop with a message if they are called.
# -------------------------------------------------------------
# The operations
# For a photovoltaic installation:
#   - load_parameters: its parameter group, read from its file, the
#       reference conditions of the modules and the solar constant.
#   - variable_registry: the path of its variable registry, which
#       declares the columns of its table.
#   - new_table: its table on the time grid, with the columns of its
#       variable registry.
#   - prepare_year: the geometry of the sun (its elevation and azimuth
#       and the incidence of its rays on the modules), written in the
#       table for the whole year.
#   - initial_state, prepare_period: it has nothing to prepare and no
#       initial condition to write: they return the table as it comes.
#   - gene_options: 0, it has no genes.
#   - decode_genes: it stops, it has no genes to decode.
#   - default_control: an empty list, it has no control.
#   - can_hold: FALSE. Its equipment cannot keep its electricity
#       apart from its production.
#   - plan_start_state: it carries no state, and the chunk comes back
#       as it comes.
#   - simulate_itinerary: its production over a chunk, with the
#       weather of the context.
#   - comfort: 0 on every row.
#   - window_feasible: TRUE, it holds no energy of a window that
#       could break a technical rule.
#   - slot_offer: FALSE, it has nothing to offer on a new window.
#   - window_draft: it draws nothing, and has no margin data.
#   - margin_fit, margin_energy: they stop, it has no margin data.
#   - window_contribution: the chunk as it comes, with nothing drawn
#       and no refusal.
#   - restate_systems: NULL, it has no alternatives to redraw with.
#   - hold_room: 0 on every row, it can hold nothing.
#   - window_hold, continue_window_tail: the chunk as it comes.
#   - tail_state: no state and no system.
#   - execute_step: its production over a step of the simulation.
#   - reads_rest_net: FALSE, its production does not depend on the
#       rest of the system.
#   - stored_energy_change: NULL, it stores no energy.
#   - recovery_choices: NULL, it has no Recovery Phase to draw.
# -------------------------------------------------------------
# Auxiliary functions
# The operations that are a line are written as auxiliary functions of
# photovoltaic_model_contract(), in this file, after it. They are
# named functions, defined once when the file is sourced, so that the
# contract hands over the same functions on every call instead of
# creating them again. The file holds:
#   - photovoltaic_model_contract() (main function)
#   - photovoltaic_prepare_year()
#   - photovoltaic_initial_state()
#   - photovoltaic_prepare_period()
#   - photovoltaic_gene_options()
#   - photovoltaic_decode_genes()
#   - photovoltaic_default_control()
#   - photovoltaic_can_hold()
#   - photovoltaic_plan_start_state()
#   - photovoltaic_comfort()
#   - photovoltaic_window_feasible()
#   - photovoltaic_slot_offer()
#   - photovoltaic_window_draft()
#   - photovoltaic_margin_fit()
#   - photovoltaic_margin_energy()
#   - photovoltaic_window_contribution()
#   - photovoltaic_restate_systems()
#   - photovoltaic_hold_room()
#   - photovoltaic_window_hold()
#   - photovoltaic_continue_window_tail()
#   - photovoltaic_tail_state()
#   - photovoltaic_reads_rest_net()
#   - photovoltaic_stored_energy_change()
#   - photovoltaic_recovery_choices()
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
# contract <- photovoltaic_model_contract()
# contract$simulate_itinerary(
#   period_chunk        = period_chunk,
#   asset               = asset,
#   calculation_mode    = 1,
#   calculation_context = "plan"
# )
# -------------------------------------------------------------

photovoltaic_model_contract <- function() {

  # -------------------------------------------------------------
  # 1. Bind each operation to its function
  # The functions are named, not called: the caller calls the
  # operation it needs. The operations that are a line are
  # auxiliary functions of this file, written after it, each one
  # with what it returns and why.
  # -------------------------------------------------------------
  {
    contract <- list(
      load_parameters = load_photovoltaic_parameters,

      variable_registry = photovoltaic_variable_registry,

      new_table = photovoltaic_new_table,

      # The geometry of the sun only depends on the instant, the
      # location and the orientation: it is written in the table for
      # the whole year, before the period is cut.
      prepare_year = photovoltaic_prepare_year,

      # The installation has nothing to prepare on the period and no
      # initial condition: the table is returned as it comes.
      initial_state = photovoltaic_initial_state,

      prepare_period = photovoltaic_prepare_period,

      # No genes: the installation has no control to search for.
      gene_options = photovoltaic_gene_options,

      decode_genes = photovoltaic_decode_genes,

      # No control: nothing is set on a row that no market has
      # determined.
      default_control = photovoltaic_default_control,

      # The equipment cannot keep its electricity apart from its
      # production.
      can_hold = photovoltaic_can_hold,

      # The installation carries no state from the executed rows to
      # the plan: the chunk is returned as it comes.
      plan_start_state = photovoltaic_plan_start_state,

      simulate_itinerary = photovoltaic_generation,

      # No comfort: nothing it does changes a room.
      comfort = photovoltaic_comfort,

      # It holds no energy of a window, so no technical rule of a
      # window can be broken by it.
      window_feasible = photovoltaic_window_feasible,

      # It has nothing to offer on a new window.
      slot_offer = photovoltaic_slot_offer,

      # It draws nothing on a window, and has no margin data.
      window_draft = photovoltaic_window_draft,

      margin_fit = photovoltaic_margin_fit,

      margin_energy = photovoltaic_margin_energy,

      # The chunk comes back as it comes: nothing drawn, no refusal.
      window_contribution = photovoltaic_window_contribution,

      # It has no alternatives to redraw a window with.
      restate_systems = photovoltaic_restate_systems,

      # It can hold nothing, on any row.
      hold_room = photovoltaic_hold_room,

      # It holds nothing of a window, and has no tail to continue: the
      # chunk is returned as it comes.
      window_hold = photovoltaic_window_hold,

      continue_window_tail = photovoltaic_continue_window_tail,

      # It leaves no state and no system in the itinerary of a window.
      tail_state = photovoltaic_tail_state,

      execute_step = photovoltaic_execute_step,

      # The production depends on the weather and not on the rest of
      # the system.
      reads_rest_net = photovoltaic_reads_rest_net,

      # It stores no energy.
      stored_energy_change = photovoltaic_stored_energy_change,

      # It has no Recovery Phase to draw.
      recovery_choices = photovoltaic_recovery_choices
    )
  }

  return(contract)
}

# -------------------------------------------------------------
# Function: photovoltaic_prepare_year()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation prepare_year of the type of model Photovoltaic, an
# auxiliary function of photovoltaic_model_contract(), which hands it
# over in the contract of the type.
# The geometry of the sun only depends on the instant, the location
# and the orientation: it is written in the table for the whole year,
# before the period is cut.
# -------------------------------------------------------------
# Inputs
#   Main_df : the argument of the operation prepare_year, as every
#     type of model receives it. Not read.
#   asset_df : the argument of the operation prepare_year, as every
#     type of model receives it.
#   asset : the argument of the operation prepare_year, as every type
#     of model receives it.
# -------------------------------------------------------------
# Outputs
#   asset_df, with the geometry of the sun written by
#   photovoltaic_solar_geometry().
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation prepare_year.
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_prepare_year <- function(Main_df,
                                      asset_df,
                                      asset
                                      ) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    # photovoltaic_solar_geometry is called to write the elevation
    # and the azimuth of the sun and the incidence of its rays on
    # the modules in the table of the installation.
    asset_df <- photovoltaic_solar_geometry(
      asset_df = asset_df,
      asset    = asset
    )
    return(asset_df)
  }
}

# -------------------------------------------------------------
# Function: photovoltaic_initial_state()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation initial_state of the type of model Photovoltaic, an
# auxiliary function of photovoltaic_model_contract(), which hands it
# over in the contract of the type.
# The installation has nothing to prepare on the period and no initial
# condition: the table is returned as it comes.
# -------------------------------------------------------------
# Inputs
#   asset_df : the argument of the operation initial_state, as every
#     type of model receives it.
#   asset : the argument of the operation initial_state, as every type
#     of model receives it. Not read.
#   delta_t_h : the argument of the operation initial_state, as every
#     type of model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always asset_df.
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation initial_state.
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_initial_state <- function(asset_df,
                                       asset,
                                       delta_t_h
                                       ) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(asset_df)
  }
}

# -------------------------------------------------------------
# Function: photovoltaic_prepare_period()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation prepare_period of the type of model Photovoltaic, an
# auxiliary function of photovoltaic_model_contract(), which hands it
# over in the contract of the type.
# The installation has nothing to prepare on the period and no initial
# condition: the table is returned as it comes.
# -------------------------------------------------------------
# Inputs
#   asset_df : the argument of the operation prepare_period, as every
#     type of model receives it.
#   asset : the argument of the operation prepare_period, as every
#     type of model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always asset_df.
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation prepare_period.
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_prepare_period <- function(asset_df,
                                        asset
                                        ) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(asset_df)
  }
}

# -------------------------------------------------------------
# Function: photovoltaic_gene_options()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation gene_options of the type of model Photovoltaic, an
# auxiliary function of photovoltaic_model_contract(), which hands it
# over in the contract of the type.
# No genes: the installation has no control to search for.
# -------------------------------------------------------------
# Inputs
#   asset : the argument of the operation gene_options, as every type
#     of model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always 0L.
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation gene_options.
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_gene_options <- function(asset) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(0L)
  }
}

# -------------------------------------------------------------
# Function: photovoltaic_decode_genes()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation decode_genes of the type of model Photovoltaic, an
# auxiliary function of photovoltaic_model_contract(), which hands it
# over in the contract of the type.
# No genes: the installation has no control to search for.
# -------------------------------------------------------------
# Inputs
#   genes : the argument of the operation decode_genes, as every type
#     of model receives it. Not read.
#   gene_options : the argument of the operation decode_genes, as
#     every type of model receives it. Not read.
#   target_periods : the argument of the operation decode_genes, as
#     every type of model receives it. Not read.
#   parameters : the argument of the operation decode_genes, as every
#     type of model receives it. Not read.
#   asset : the argument of the operation decode_genes, as every type
#     of model receives it.
# -------------------------------------------------------------
# Outputs
#   None: the type has nothing to do in this operation, so it stops
#   with a message that names the asset.
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation decode_genes.
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_decode_genes <- function(genes,
                                      gene_options,
                                      target_periods,
                                      parameters,
                                      asset
                                      ) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    stop("photovoltaic_model_contract: a photovoltaic installation ",
         "has no genes to decode (", asset$asset_id, ")")
  }
}

# -------------------------------------------------------------
# Function: photovoltaic_default_control()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation default_control of the type of model Photovoltaic, an
# auxiliary function of photovoltaic_model_contract(), which hands it
# over in the contract of the type.
# No control: nothing is set on a row that no market has determined.
# -------------------------------------------------------------
# Inputs
#   parameters : the argument of the operation default_control, as
#     every type of model receives it. Not read.
#   asset : the argument of the operation default_control, as every
#     type of model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always list().
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation default_control.
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_default_control <- function(parameters,
                                         asset
                                         ) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(list())
  }
}

# -------------------------------------------------------------
# Function: photovoltaic_can_hold()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation can_hold of the type of model Photovoltaic, an auxiliary
# function of photovoltaic_model_contract(), which hands it over in
# the contract of the type.
# The equipment cannot keep its electricity apart from its production.
# -------------------------------------------------------------
# Inputs
#   asset : the argument of the operation can_hold, as every type of
#     model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always FALSE.
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation can_hold.
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_can_hold <- function(asset) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(FALSE)
  }
}

# -------------------------------------------------------------
# Function: photovoltaic_plan_start_state()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation plan_start_state of the type of model Photovoltaic, an
# auxiliary function of photovoltaic_model_contract(), which hands it
# over in the contract of the type.
# The installation carries no state from the executed rows to the
# plan: the chunk is returned as it comes.
# -------------------------------------------------------------
# Inputs
#   period_chunk : the argument of the operation plan_start_state, as
#     every type of model receives it.
#   asset : the argument of the operation plan_start_state, as every
#     type of model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always period_chunk.
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation plan_start_state.
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_plan_start_state <- function(period_chunk,
                                          asset
                                          ) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(period_chunk)
  }
}

# -------------------------------------------------------------
# Function: photovoltaic_comfort()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation comfort of the type of model Photovoltaic, an auxiliary
# function of photovoltaic_model_contract(), which hands it over in
# the contract of the type.
# No comfort: nothing it does changes a room.
# -------------------------------------------------------------
# Inputs
#   period_chunk : the argument of the operation comfort, as every
#     type of model receives it.
#   asset : the argument of the operation comfort, as every type of
#     model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always rep(0, nrow(period_chunk)).
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation comfort.
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_comfort <- function(period_chunk,
                                 asset
                                 ) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(rep(0, nrow(period_chunk)))
  }
}

# -------------------------------------------------------------
# Function: photovoltaic_window_feasible()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation window_feasible of the type of model Photovoltaic, an
# auxiliary function of photovoltaic_model_contract(), which hands it
# over in the contract of the type.
# It holds no energy of a window, so no technical rule of a window can
# be broken by it.
# -------------------------------------------------------------
# Inputs
#   period_chunk : the argument of the operation window_feasible, as
#     every type of model receives it. Not read.
#   leg : the argument of the operation window_feasible, as every type
#     of model receives it. Not read.
#   parameters : the argument of the operation window_feasible, as
#     every type of model receives it. Not read.
#   asset : the argument of the operation window_feasible, as every
#     type of model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always TRUE.
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation window_feasible.
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_window_feasible <- function(period_chunk,
                                         leg,
                                         parameters,
                                         asset
                                         ) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(TRUE)
  }
}

# -------------------------------------------------------------
# Function: photovoltaic_slot_offer()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation slot_offer of the type of model Photovoltaic, an auxiliary
# function of photovoltaic_model_contract(), which hands it over in
# the contract of the type.
# It has nothing to offer on a new window.
# -------------------------------------------------------------
# Inputs
#   period_chunk : the argument of the operation slot_offer, as every
#     type of model receives it. Not read.
#   leg : the argument of the operation slot_offer, as every type of
#     model receives it. Not read.
#   slot_rows : the argument of the operation slot_offer, as every
#     type of model receives it. Not read.
#   parameters : the argument of the operation slot_offer, as every
#     type of model receives it. Not read.
#   asset : the argument of the operation slot_offer, as every type of
#     model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always FALSE.
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation slot_offer.
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_slot_offer <- function(period_chunk,
                                    leg,
                                    slot_rows,
                                    parameters,
                                    asset
                                    ) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(FALSE)
  }
}

# -------------------------------------------------------------
# Function: photovoltaic_window_draft()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation window_draft of the type of model Photovoltaic, an
# auxiliary function of photovoltaic_model_contract(), which hands it
# over in the contract of the type.
# It draws nothing on a window, and has no margin data.
# -------------------------------------------------------------
# Inputs
#   leg : the argument of the operation window_draft, as every type of
#     model receives it. Not read.
#   period_chunk : the argument of the operation window_draft, as
#     every type of model receives it. Not read.
#   window : the argument of the operation window_draft, as every type
#     of model receives it. Not read.
#   parameters : the argument of the operation window_draft, as every
#     type of model receives it. Not read.
#   asset : the argument of the operation window_draft, as every type
#     of model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always list(drawn = FALSE, margin = NULL).
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation window_draft.
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_window_draft <- function(leg,
                                      period_chunk,
                                      window,
                                      parameters,
                                      asset
                                      ) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(list(drawn = FALSE, margin = NULL))
  }
}

# -------------------------------------------------------------
# Function: photovoltaic_margin_fit()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation margin_fit of the type of model Photovoltaic, an auxiliary
# function of photovoltaic_model_contract(), which hands it over in
# the contract of the type.
# It draws nothing on a window, and has no margin data.
# -------------------------------------------------------------
# Inputs
#   margin : the argument of the operation margin_fit, as every type
#     of model receives it. Not read.
#   band : the argument of the operation margin_fit, as every type of
#     model receives it. Not read.
#   leg : the argument of the operation margin_fit, as every type of
#     model receives it. Not read.
#   parameters : the argument of the operation margin_fit, as every
#     type of model receives it. Not read.
#   asset : the argument of the operation margin_fit, as every type of
#     model receives it.
# -------------------------------------------------------------
# Outputs
#   None: the type has nothing to do in this operation, so it stops
#   with a message that names the asset.
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation margin_fit.
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_margin_fit <- function(margin,
                                    band,
                                    leg,
                                    parameters,
                                    asset
                                    ) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    stop("photovoltaic_model_contract: a photovoltaic installation ",
         "has no margin data to fit (", asset$asset_id, ")")
  }
}

# -------------------------------------------------------------
# Function: photovoltaic_margin_energy()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation margin_energy of the type of model Photovoltaic, an
# auxiliary function of photovoltaic_model_contract(), which hands it
# over in the contract of the type.
# It draws nothing on a window, and has no margin data.
# -------------------------------------------------------------
# Inputs
#   margin : the argument of the operation margin_energy, as every
#     type of model receives it. Not read.
#   control : the argument of the operation margin_energy, as every
#     type of model receives it. Not read.
#   asset : the argument of the operation margin_energy, as every type
#     of model receives it.
# -------------------------------------------------------------
# Outputs
#   None: the type has nothing to do in this operation, so it stops
#   with a message that names the asset.
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation margin_energy.
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_margin_energy <- function(margin,
                                       control,
                                       asset
                                       ) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    stop("photovoltaic_model_contract: a photovoltaic installation ",
         "has no margin data (", asset$asset_id, ")")
  }
}

# -------------------------------------------------------------
# Function: photovoltaic_window_contribution()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation window_contribution of the type of model Photovoltaic, an
# auxiliary function of photovoltaic_model_contract(), which hands it
# over in the contract of the type.
# The chunk comes back as it comes: nothing drawn, no refusal.
# -------------------------------------------------------------
# Inputs
#   leg : the argument of the operation window_contribution, as every
#     type of model receives it. Not read.
#   period_chunk : the argument of the operation window_contribution,
#     as every type of model receives it.
#   window : the argument of the operation window_contribution, as
#     every type of model receives it. Not read.
#   draft : the argument of the operation window_contribution, as
#     every type of model receives it. Not read.
#   margined : the argument of the operation window_contribution, as
#     every type of model receives it. Not read.
#   parameters : the argument of the operation window_contribution, as
#     every type of model receives it. Not read.
#   asset : the argument of the operation window_contribution, as
#     every type of model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always list(chunk = period_chunk, refusal = NULL, drawn = FALSE).
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation window_contribution.
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_window_contribution <- function(leg,
                                             period_chunk,
                                             window,
                                             draft,
                                             margined,
                                             parameters,
                                             asset
                                             ) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(list(chunk = period_chunk, refusal = NULL, drawn = FALSE))
  }
}

# -------------------------------------------------------------
# Function: photovoltaic_restate_systems()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation restate_systems of the type of model Photovoltaic, an
# auxiliary function of photovoltaic_model_contract(), which hands it
# over in the contract of the type.
# It has no alternatives to redraw a window with.
# -------------------------------------------------------------
# Inputs
#   period_chunk : the argument of the operation restate_systems, as
#     every type of model receives it. Not read.
#   leg : the argument of the operation restate_systems, as every type
#     of model receives it. Not read.
#   i_flex : the argument of the operation restate_systems, as every
#     type of model receives it. Not read.
#   parameters : the argument of the operation restate_systems, as
#     every type of model receives it. Not read.
#   asset : the argument of the operation restate_systems, as every
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
# the operation restate_systems.
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_restate_systems <- function(period_chunk,
                                         leg,
                                         i_flex,
                                         parameters,
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
# Function: photovoltaic_hold_room()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation hold_room of the type of model Photovoltaic, an auxiliary
# function of photovoltaic_model_contract(), which hands it over in
# the contract of the type.
# It can hold nothing, on any row.
# -------------------------------------------------------------
# Inputs
#   period_chunk : the argument of the operation hold_room, as every
#     type of model receives it. Not read.
#   leg : the argument of the operation hold_room, as every type of
#     model receives it. Not read.
#   window_rows : the argument of the operation hold_room, as every
#     type of model receives it.
#   parameters : the argument of the operation hold_room, as every
#     type of model receives it. Not read.
#   asset : the argument of the operation hold_room, as every type of
#     model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always rep(0, length(window_rows)).
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation hold_room.
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_hold_room <- function(period_chunk,
                                   leg,
                                   window_rows,
                                   parameters,
                                   asset
                                   ) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(rep(0, length(window_rows)))
  }
}

# -------------------------------------------------------------
# Function: photovoltaic_window_hold()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation window_hold of the type of model Photovoltaic, an
# auxiliary function of photovoltaic_model_contract(), which hands it
# over in the contract of the type.
# It holds nothing of a window, and has no tail to continue: the chunk
# is returned as it comes.
# -------------------------------------------------------------
# Inputs
#   period_chunk : the argument of the operation window_hold, as every
#     type of model receives it.
#   leg : the argument of the operation window_hold, as every type of
#     model receives it. Not read.
#   window_rows : the argument of the operation window_hold, as every
#     type of model receives it. Not read.
#   standing : the argument of the operation window_hold, as every
#     type of model receives it. Not read.
#   hold : the argument of the operation window_hold, as every type of
#     model receives it. Not read.
#   parameters : the argument of the operation window_hold, as every
#     type of model receives it. Not read.
#   asset : the argument of the operation window_hold, as every type
#     of model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always period_chunk.
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation window_hold.
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_window_hold <- function(period_chunk,
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
    return(period_chunk)
  }
}

# -------------------------------------------------------------
# Function: photovoltaic_continue_window_tail()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation continue_window_tail of the type of model Photovoltaic, an
# auxiliary function of photovoltaic_model_contract(), which hands it
# over in the contract of the type.
# It holds nothing of a window, and has no tail to continue: the chunk
# is returned as it comes.
# -------------------------------------------------------------
# Inputs
#   period_chunk : the argument of the operation continue_window_tail,
#     as every type of model receives it.
#   leg : the argument of the operation continue_window_tail, as every
#     type of model receives it. Not read.
#   tail : the argument of the operation continue_window_tail, as
#     every type of model receives it. Not read.
#   asset : the argument of the operation continue_window_tail, as
#     every type of model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always period_chunk.
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation continue_window_tail.
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_continue_window_tail <- function(period_chunk,
                                              leg,
                                              tail,
                                              asset
                                              ) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(period_chunk)
  }
}

# -------------------------------------------------------------
# Function: photovoltaic_tail_state()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation tail_state of the type of model Photovoltaic, an auxiliary
# function of photovoltaic_model_contract(), which hands it over in
# the contract of the type.
# It leaves no state and no system in the itinerary of a window.
# -------------------------------------------------------------
# Inputs
#   stretch_chunk : the argument of the operation tail_state, as every
#     type of model receives it. Not read.
#   i_begin_horizon : the argument of the operation tail_state, as
#     every type of model receives it. Not read.
#   leg : the argument of the operation tail_state, as every type of
#     model receives it. Not read.
#   asset : the argument of the operation tail_state, as every type of
#     model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always list(state = NULL, system = NULL).
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation tail_state.
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_tail_state <- function(stretch_chunk,
                                    i_begin_horizon,
                                    leg,
                                    asset
                                    ) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(list(state = NULL, system = NULL))
  }
}

# -------------------------------------------------------------
# Function: photovoltaic_reads_rest_net()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation reads_rest_net of the type of model Photovoltaic, an
# auxiliary function of photovoltaic_model_contract(), which hands it
# over in the contract of the type.
# The production depends on the weather and not on the rest of the
# system.
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
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_reads_rest_net <- function(asset) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(FALSE)
  }
}

# -------------------------------------------------------------
# Function: photovoltaic_stored_energy_change()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation stored_energy_change of the type of model Photovoltaic, an
# auxiliary function of photovoltaic_model_contract(), which hands it
# over in the contract of the type.
# It stores no energy.
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
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_stored_energy_change <- function(asset_df,
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
# Function: photovoltaic_recovery_choices()
# Auxiliary function of photovoltaic_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation recovery_choices of the type of model Photovoltaic, an
# auxiliary function of photovoltaic_model_contract(), which hands it
# over in the contract of the type.
# It has no Recovery Phase to draw.
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
# contract <- photovoltaic_model_contract()
# -------------------------------------------------------------

photovoltaic_recovery_choices <- function(asset) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(NULL)
  }
}
