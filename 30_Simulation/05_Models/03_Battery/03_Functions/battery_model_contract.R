# -------------------------------------------------------------
# Function: battery_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the contract of the type of model Battery: the table of the
# functions through which the rest of the simulator operates a
# battery. It is the table that model_type_contract() returns for an
# asset whose asset_type is Battery. The operations, with their
# arguments and their results, are described in model_type_contract().
# A battery charges from the system and discharges into it. Its
# operations are bound as follows:
#   - Those that carry out something are bound to functions of this
#     folder, 30_Simulation/05_Models/03_Battery/03_Functions/:
#     load_parameters, variable_registry, new_table, initial_state,
#     plan_start_state, simulate_itinerary, execute_step,
#     decode_genes, stored_energy_change, window_feasible,
#     slot_offer, window_draft, margin_fit, window_contribution,
#     hold_room, window_hold, continue_window_tail and tail_state.
#     can_hold, recovery_choices, margin_energy and restate_systems
#     are written below, in the table.
#   - prepare_year and prepare_period are written below, in the
#     table: a battery has nothing to prepare on the year or on the
#     period, and they return the table as it comes.
# -------------------------------------------------------------
# The operations
# For a battery:
#   - load_parameters: its parameter group, battery, read from its
#       file.
#   - variable_registry: the path of its variable registry, which
#       declares the columns of its table.
#   - new_table: its table on the time grid, with the columns of its
#       variable registry.
#   - prepare_year, prepare_period: it has nothing to prepare: they
#       return the table as it comes.
#   - initial_state: the energy it stores at the start, written in
#       row 1 of its table.
#   - plan_start_state: the plan starts from the energy the battery
#       has actually stored.
#   - simulate_itinerary: what it stores, takes from the system and
#       gives to it over a chunk, for one itinerary, in the mode of
#       each row and within its limits.
#   - execute_step: the same over a step of the simulation.
#   - reads_rest_net: TRUE. The mode of the battery works over the
#       net electricity of the rest of the system, so the battery is
#       simulated after the other assets.
#   - gene_options: 5, the number of modes of battery_modes(). Each
#       gene of a battery is the mode of one market interval.
#   - decode_genes: the genes become the control of the battery, the
#       table with the start and the mode of each market interval.
#   - default_control: the stop mode, for the rows that no market
#       has decided.
#   - comfort: 0 on every row, a battery changes no room.
#   - stored_energy_change: the change of the energy it stores on
#       each row of an itinerary, on the side of the system, which
#       the reward values.
#   - window_feasible: whether the flexibility windows of a leg
#       respect the power and the energy limits of the battery.
#   - slot_offer: whether the battery has something to give, or to
#       take, on the leg in a market interval.
#   - window_draft: its contribution to a flexibility window of the
#       system in the Commitment Phase, before the commitment margin,
#       and its margin data.
#   - margin_fit: its electricity inside the band of the commitment
#       margin, when it is the only asset that contributes.
#   - margin_energy: the electricity of the margin data, which is
#       the quantity the margin moves.
#   - window_contribution: its contribution to the window, with the
#       Recovery Phase corrected so that the leg can be carried out
#       until the close of the control horizon, or the refusal
#       no_recovery.
#   - recovery_choices: the two ways it may draw the Recovery Phase of
#       a window, minimum and plan, in the order they are tried.
#   - can_hold: TRUE, a battery can keep its electricity apart from
#       its plan.
#   - hold_room: the electricity it can hold on each row of a window
#       already sold.
#   - window_hold: holds what the system asks of it in a window
#       already sold, within its limits, and carries its leg out until
#       the close of the control horizon.
#   - restate_systems: NULL, it has no alternatives to redraw a window
#       already sold with.
#   - continue_window_tail: continues the Neutral and Recovery Phases
#       of a window whose Commitment Phase ended before the chunk, from
#       the energy the window left, and carries its leg out until the
#       close of the control horizon.
#   - tail_state: the energy the leg stores at the start of the
#       horizon. A battery has no system to give.
# -------------------------------------------------------------
# Auxiliary functions
# The operations that are a line are written as auxiliary functions of
# battery_model_contract(), in this file, after it. They are named
# functions, defined once when the file is sourced, so that the
# contract hands over the same functions on every call instead of
# creating them again. The file holds:
#   - battery_model_contract() (main function)
#   - battery_recovery_choices()
#   - battery_can_hold()
#   - battery_margin_energy()
#   - battery_comfort()
#   - battery_reads_rest_net()
#   - battery_prepare_year()
#   - battery_prepare_period()
#   - battery_gene_options()
#   - battery_default_control()
#   - battery_restate_systems()
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
# contract <- battery_model_contract()
# battery_df <- contract$new_table(
#   time  = Main_df$time,
#   paths = paths
# )
# -------------------------------------------------------------

battery_model_contract <- function() {

  # -------------------------------------------------------------
  # 1. Bind each operation to its function
  # The functions are named, not called: the caller calls the
  # operation it needs. The operations that are a line are
  # auxiliary functions of this file, written after it, each one
  # with what it returns and why.
  # -------------------------------------------------------------
  {
    contract <- list(
      load_parameters = load_battery_parameters,

      variable_registry = battery_variable_registry,

      new_table = battery_new_table,

      initial_state = battery_initial_state,

      plan_start_state = battery_plan_start_state,

      simulate_itinerary = battery_simulate_itinerary,

      execute_step = battery_execute_step,

      stored_energy_change = battery_stored_energy_change,

      window_feasible = battery_window_feasible,

      slot_offer = battery_slot_offer,

      window_draft = battery_window_draft,

      margin_fit = battery_margin_fit,

      window_contribution = battery_window_contribution,

      hold_room = battery_hold_room,

      window_hold = battery_window_hold,

      continue_window_tail = battery_continue_window_tail,

      tail_state = battery_tail_state,

      # The Recovery Phase of a battery is drawn with the least
      # correction, or buying or selling until it is back on the
      # energy of the plan.
      recovery_choices = battery_recovery_choices,

      # A battery can keep its electricity apart from its plan.
      can_hold = battery_can_hold,

      # The quantity a battery moves in a window is its electricity.
      margin_energy = battery_margin_energy,

      # A battery changes no room: it has no comfort.
      comfort = battery_comfort,

      # The mode of the battery works over the net electricity of the
      # rest of the system.
      reads_rest_net = battery_reads_rest_net,

      # A battery has nothing to prepare on the year or on the
      # period: the table is returned as it comes.
      prepare_year = battery_prepare_year,

      prepare_period = battery_prepare_period,

      decode_genes = decode_battery_genes,

      # The number of options of each gene of a battery: one per
      # mode.
      gene_options = battery_gene_options,

      # The control of a row that no market has decided: the stop
      # mode.
      default_control = battery_default_control,

      # A battery has no alternatives to redraw a window already sold
      # with: it has no system to choose.
      restate_systems = battery_restate_systems
    )
  }

  return(contract)
}

# -------------------------------------------------------------
# Function: battery_recovery_choices()
# Auxiliary function of battery_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation recovery_choices of the type of model Battery, an
# auxiliary function of battery_model_contract(), which hands it over
# in the contract of the type.
# The Recovery Phase of a battery is drawn with the least correction,
# or buying or selling until it is back on the energy of the plan.
# -------------------------------------------------------------
# Inputs
#   asset : the argument of the operation recovery_choices, as every
#     type of model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always c("minimum", "plan").
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation recovery_choices.
# contract <- battery_model_contract()
# -------------------------------------------------------------

battery_recovery_choices <- function(asset) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(c("minimum", "plan"))
  }
}

# -------------------------------------------------------------
# Function: battery_can_hold()
# Auxiliary function of battery_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation can_hold of the type of model Battery, an auxiliary
# function of battery_model_contract(), which hands it over in the
# contract of the type.
# A battery can keep its electricity apart from its plan.
# -------------------------------------------------------------
# Inputs
#   asset : the argument of the operation can_hold, as every type of
#     model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always TRUE.
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation can_hold.
# contract <- battery_model_contract()
# -------------------------------------------------------------

battery_can_hold <- function(asset) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(TRUE)
  }
}

# -------------------------------------------------------------
# Function: battery_margin_energy()
# Auxiliary function of battery_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation margin_energy of the type of model Battery, an auxiliary
# function of battery_model_contract(), which hands it over in the
# contract of the type.
# The quantity a battery moves in a window is its electricity.
# -------------------------------------------------------------
# Inputs
#   margin : the argument of the operation margin_energy, as every
#     type of model receives it. Not read.
#   control : the argument of the operation margin_energy, as every
#     type of model receives it.
#   asset : the argument of the operation margin_energy, as every type
#     of model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always control$Elec.
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation margin_energy.
# contract <- battery_model_contract()
# -------------------------------------------------------------

battery_margin_energy <- function(margin,
                                  control,
                                  asset
                                  ) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(control$Elec)
  }
}

# -------------------------------------------------------------
# Function: battery_comfort()
# Auxiliary function of battery_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation comfort of the type of model Battery, an auxiliary
# function of battery_model_contract(), which hands it over in the
# contract of the type.
# A battery changes no room: it has no comfort.
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
# contract <- battery_model_contract()
# -------------------------------------------------------------

battery_comfort <- function(period_chunk,
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
# Function: battery_reads_rest_net()
# Auxiliary function of battery_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation reads_rest_net of the type of model Battery, an auxiliary
# function of battery_model_contract(), which hands it over in the
# contract of the type.
# The mode of the battery works over the net electricity of the rest
# of the system.
# -------------------------------------------------------------
# Inputs
#   asset : the argument of the operation reads_rest_net, as every
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
# the operation reads_rest_net.
# contract <- battery_model_contract()
# -------------------------------------------------------------

battery_reads_rest_net <- function(asset) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(TRUE)
  }
}

# -------------------------------------------------------------
# Function: battery_prepare_year()
# Auxiliary function of battery_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation prepare_year of the type of model Battery, an auxiliary
# function of battery_model_contract(), which hands it over in the
# contract of the type.
# A battery has nothing to prepare on the year or on the period: the
# table is returned as it comes.
# -------------------------------------------------------------
# Inputs
#   Main_df : the argument of the operation prepare_year, as every
#     type of model receives it. Not read.
#   asset_df : the argument of the operation prepare_year, as every
#     type of model receives it.
#   asset : the argument of the operation prepare_year, as every type
#     of model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always asset_df.
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation prepare_year.
# contract <- battery_model_contract()
# -------------------------------------------------------------

battery_prepare_year <- function(Main_df,
                                 asset_df,
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
# Function: battery_prepare_period()
# Auxiliary function of battery_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation prepare_period of the type of model Battery, an auxiliary
# function of battery_model_contract(), which hands it over in the
# contract of the type.
# A battery has nothing to prepare on the year or on the period: the
# table is returned as it comes.
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
# contract <- battery_model_contract()
# -------------------------------------------------------------

battery_prepare_period <- function(asset_df,
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
# Function: battery_gene_options()
# Auxiliary function of battery_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation gene_options of the type of model Battery, an auxiliary
# function of battery_model_contract(), which hands it over in the
# contract of the type.
# The number of options of each gene of a battery: one per mode.
# -------------------------------------------------------------
# Inputs
#   asset : the argument of the operation gene_options, as every type
#     of model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always length(battery_modes()).
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation gene_options.
# contract <- battery_model_contract()
# -------------------------------------------------------------

battery_gene_options <- function(asset) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(length(battery_modes()))
  }
}

# -------------------------------------------------------------
# Function: battery_default_control()
# Auxiliary function of battery_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation default_control of the type of model Battery, an auxiliary
# function of battery_model_contract(), which hands it over in the
# contract of the type.
# The control of a row that no market has decided: the stop mode.
# -------------------------------------------------------------
# Inputs
#   parameters : the argument of the operation default_control, as
#     every type of model receives it. Not read.
#   asset : the argument of the operation default_control, as every
#     type of model receives it. Not read.
# -------------------------------------------------------------
# Outputs
#   Always list(Mode = battery_modes()[["stop"]]).
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# Not called by its name: the contract hands it over as
# the operation default_control.
# contract <- battery_model_contract()
# -------------------------------------------------------------

battery_default_control <- function(parameters,
                                    asset
                                    ) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    return(list(Mode = battery_modes()[["stop"]]))
  }
}

# -------------------------------------------------------------
# Function: battery_restate_systems()
# Auxiliary function of battery_model_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation restate_systems of the type of model Battery, an auxiliary
# function of battery_model_contract(), which hands it over in the
# contract of the type.
# A battery has no alternatives to redraw a window already sold with:
# it has no system to choose.
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
# contract <- battery_model_contract()
# -------------------------------------------------------------

battery_restate_systems <- function(period_chunk,
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
