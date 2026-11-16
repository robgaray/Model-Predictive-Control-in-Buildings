# -------------------------------------------------------------
# Function: model_type_contract.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the contract of a type of model: the table of the functions
# through which the rest of the script operates an asset of that
# type. The market, the genetic algorithm and the reward never call
# the model of an asset by its own name. They
# take its contract from here, by the asset_type of the asset in the
# asset registry, and call the operation they need.
# -------------------------------------------------------------
# The operations
# Every type of model supplies the same operations, with the same
# arguments and the same result. Every operation receives asset, the
# parameters of the asset it operates: its entry of
# parameters$assets, which holds its asset_id, its asset_type and the
# parameter groups of its type (for a Building: model,
# operational_temperature_corrections, setpoint_modes, comfort and
# control; for a Photovoltaic: photovoltaic and reference_conditions;
# for a Battery: battery). The parameters of the system, when the
# operation needs them, come in parameters. An operation that
# receives period_chunk works on the view of its asset of the piece
# of the market (piece_asset_view()), and what it returns comes back
# into the table of the asset (piece_absorb_asset()).
#   - load_parameters: loads the parameter groups of the asset from
#       the files of its configuration folder (build_asset_paths()),
#       each one validated against the parameter catalogue. The
#       groups it returns are those the other operations read from
#       asset.
#       f(asset_paths, validation_config, bounding_validation_config,
#         parameters) -> named list of parameter groups. parameters
#       is the system parameters already loaded.
#   - variable_registry: the path of the variable registry of the
#       type, Simulation_Variables_<type>.txt, which declares the
#       columns of the table of its assets.
#       f(paths) -> character scalar. paths is the paths of the
#       script.
#   - prepare_period: prepares the table of the asset for the call
#       (for a building, its scheduling window and its reference
#       temperature profiles, from its occupancy and its climate
#       season).
#       f(asset_df, asset) -> asset_df.
#   - gene_options: the number of options of each gene of the asset.
#       f(asset) -> integer scalar.
#   - decode_genes: turns one gene per market interval into the
#       control of the asset over the horizon.
#       f(genes, gene_options, target_periods, parameters, asset) ->
#       the control table, one row per market interval.
#   - default_control: the control of a row that no market has
#       determined yet.
#       f(parameters, asset) -> named list, one value per control
#       column.
#   - can_hold: whether the asset can keep its electricity apart
#       from its plan in a flexibility itinerary. It is a physical
#       capability of the equipment: whether the asset can hold
#       energy.
#       f(asset) -> logical scalar.
#   - plan_start_state: starts the plan of the asset from its state
#       at i0, on row 1 of the chunk.
#       f(period_chunk, asset) -> the chunk.
#   - simulate_itinerary: simulates the asset over a chunk, for one
#       itinerary.
#       f(period_chunk, asset, calculation_mode, calculation_context,
#         set_point_df, Q_heat_cap, Q_cool_cap) -> the chunk with the
#       itinerary simulated.
#   - comfort: the comfort term of the asset in the reward, weighed
#       with the comfort weight of the asset.
#       f(period_chunk, asset) -> one value per row.
#   - window_feasible: whether the flexibility windows of one leg are
#       a service the asset can render, by the technical rules of its
#       type. The reward penalizes each asset and leg that breaks them.
#       f(period_chunk, leg, parameters, asset) -> logical scalar.
#   - slot_offer: whether the asset may have something to offer on a
#       new flexibility window of one leg that starts in a market
#       interval; a cheap check made before any simulation, so that
#       the search skips the intervals where no asset has anything to
#       offer.
#       f(period_chunk, leg, slot_rows, parameters, asset) -> logical
#       scalar.
#   - window_draft: drafts the contribution of the asset to a
#       flexibility window of the system, of one leg, over the rows,
#       phases and fractions of flexibility the system fixed
#       (system_flex_window()), before the commitment margin: what it
#       would draw in the Commitment Phase, and its margin data.
#       f(leg, period_chunk, window, parameters, asset) ->
#       list(drawn, ..., margin): drawn FALSE when the asset has
#       nothing to offer on the window, with accepted TRUE when the
#       window restates a commitment already sold and the asset
#       accepts it with no energy instead of refusing it (what it does
#       not reach is then bought again). margin is NULL when no row is
#       in the guard zone, and otherwise holds plan and profile, named
#       lists of numeric vectors with the quantities the asset moves,
#       which the system scales, and limit_energy, the electricity of
#       each row at the limit of the leg.
#   - margin_fit: fits the margin data of the asset alone inside the
#       band of the system (commitment_margin_bound()), when it is the
#       only asset that contributes to the window.
#       f(margin, band, leg, parameters, asset) -> the quantities the
#       asset moves after the margin, in the shape of the profile of
#       its margin data.
#   - margin_energy: the electricity the asset draws on each row of
#       its margin data, for given quantities.
#       f(margin, control, asset) -> numeric vector (kWh).
#   - window_contribution: draws the contribution of the asset to a
#       flexibility window of the system, with its draft and with the
#       quantities the commitment margin of the set left
#       (system_commitment_margin()), and applies the technical rules
#       of its type to it.
#       f(leg, period_chunk, window, draft, margined, parameters,
#         asset) ->
#       list(chunk, refusal, drawn): the chunk with the itinerary of
#       the leg of the asset drawn, or untouched when the asset has
#       nothing to offer or refuses the window, with the reason. When
#       the asset has nothing to offer on a restated window and accepts
#       it with no energy, the list also holds accepted TRUE.
#       The window the system hands to the draft and to the
#       contribution holds rows, phase, commitment, delta_t_h,
#       guard_row, fraction_row, restating, hvac_up and i_end_control,
#       the row where the control horizon closes. When the Recovery
#       Phase of the asset can be drawn in more than one way, the
#       window also holds recovery, the alternative it is drawn with.
#   - recovery_choices: the alternatives with which the asset may draw
#       the Recovery Phase of a flexibility window, a tail or a hold,
#       in the order they are tried. The system draws the Recovery
#       Phase with each of them and keeps the one with the best
#       reward (choose_recovery()). NULL when the asset has none.
#       f(asset) -> NULL, or character vector. The assets that offer
#       alternatives offer the same ones.
#   - restate_systems: says with which alternatives the asset may
#       redraw a window already sold when it cannot redraw it as it
#       would sell it; for a building, the systems of an upward window
#       the prudence rule leaves undecided.
#       f(period_chunk, leg, i_flex, parameters, asset) -> NULL, or
#       list(candidates, preferred): the alternatives, in the order
#       they are tried, and the one preferred when several deliver
#       all that was sold.
#   - hold_room: the most electricity the asset can hold, on each row,
#       of a window already sold that it does not redraw, within the
#       limits of its equipment.
#       f(period_chunk, leg, window_rows, parameters, asset) -> numeric
#       vector (kWh), one value per row of window_rows.
#   - window_hold: holds, on the electricity itinerary of the leg of
#       the asset, a commitment already sold that it does not redraw,
#       within the limits of its equipment. hold is the window held:
#       the phase of each row of the chunk (phase), the row where the
#       control horizon closes (i_end_control) and, for an asset that
#       offers alternatives for the Recovery Phase, the one to draw it
#       with (recovery, NULL for the first). An asset that stores
#       energy leaves its leg realizable until the close of the control
#       horizon, correcting the Recovery Phase of the window. The rows
#       held are marked as Commitment Phase by the system.
#       f(period_chunk, leg, window_rows, standing, hold, parameters,
#         asset) -> the chunk.
#   - continue_window_tail: continues, over the plan of a chunk, the
#       Neutral and Recovery Phases of a window whose Commitment
#       Phase ended before the chunk. tail is the view of the asset:
#       the rows and the phases of the window, the state and the
#       system of this asset, the row where the control horizon
#       closes (i_end_control), the halvings and the tolerance of a
#       bisection (bisection_steps and tolerance) and, for an asset
#       that offers alternatives for the Recovery Phase, the one to
#       draw it with (recovery, NULL for the first). An asset that
#       stores energy leaves its leg realizable until the close of the
#       control horizon, correcting the Recovery Phase of the tail.
#       f(period_chunk, leg, tail, asset) -> the chunk.
#   - tail_state: the state a window left in the itinerary of its
#       leg at the start of the horizon, and the system that
#       provides it, so that the tail can be continued from there.
#       f(stretch_chunk, i_begin_horizon, leg, asset) ->
#       list(state, system).
#   - reads_rest_net: whether the asset reads the net electricity of
#       the rest of the system. An asset that does is simulated after
#       those that do not (asset_simulation_order()), and its view
#       holds Elec_rest_<itinerary>: on each row, the net electricity
#       of the assets simulated before it (write_rest_net()).
#       f(asset) -> logical scalar.
#   - stored_energy_change: the change of the energy the asset stores
#       on each row of one itinerary, on the side of the system (kWh,
#       positive when it stores), which the reward values as stored
#       energy. NULL for a type that stores none. asset_df is the
#       table of the asset, not its view.
#       f(asset_df, itinerary, asset) -> numeric vector, one value
#       per row of asset_df, or NULL. itinerary is plan,
#       plan_flex_down or plan_flex_up.
#   - check_input: checks the block of the asset in the input of a
#       call, beyond the general rules every block meets: for a
#       building, its state at i0 and its climate season; for a
#       battery, its stored energy at i0 and its modes.
#       f(asset_input, parameters, asset) -> asset_input, as it comes
#       or cleaned. The call stops if the block is invalid.
#   - spread_input: turns the block of the asset in the input of a
#       call, given per market interval, into its table on the
#       internal time steps of the call.
#       f(asset_input, grid, asset) -> data frame, one row per
#       internal step. grid is the time grid of the call: time,
#       slot_of_row, row_at_slot_start and steps_per_slot.
#   - slot_output: turns the table of the asset back into its three
#       itineraries, one value per market interval, from the start of
#       the horizon to the closing interval.
#       f(asset_df, slots, asset) -> named list with plan,
#       plan_flex_down and plan_flex_up, each a data frame. slots is
#       the output intervals of the call: out_time, n_out,
#       row_at_start, first_row and slot_rows.
# -------------------------------------------------------------
# The types
#   - Building: the thermal model of a building with a heat pump.
#     Its genes are setpoint modes, and its itineraries are simulated
#     by the RC model of period_calculation(). Its contract is given
#     by building_model_contract(), in the folder of the type,
#     31_Standalone_code/05_Models/01_Building/03_Functions/.
#   - Photovoltaic: a photovoltaic installation. It has no control:
#     it produces electricity from the solar radiation and the
#     outdoor temperature, it has no genes and no comfort, and it
#     cannot move its electricity in time. Its contract is given by
#     photovoltaic_model_contract(), in the folder of the type,
#     31_Standalone_code/05_Models/02_Photovoltaic/03_Functions/.
#   - Battery: an electric battery. It charges from the system and
#     discharges into it, and is operated in one of five modes on each
#     market interval. Its genes are its modes, and it reads the net
#     electricity of the rest of the system. Its contract is given by
#     battery_model_contract(), in the folder of the type,
#     31_Standalone_code/05_Models/03_Battery/03_Functions/.
# The type of each asset is read from the asset registry and checked
# there against the types of the parameter catalogue. This function
# dispatches on the type and calls the function that gives the
# contract of that type. Adding a type means a folder in
# 31_Standalone_code/05_Models/ with its own function that gives its
# contract, and one branch here. A type with no contract here stops
# the run.
# -------------------------------------------------------------
# Inputs
#   asset_type : Character scalar. The asset_type of an asset of the
#                asset registry (parameters$assets[[asset_id]]).
# -------------------------------------------------------------
# Outputs
#   Named list of functions, one per operation above.
# -------------------------------------------------------------
# Code outline
# 1. Check the type
# 2. The contract of each type
# -------------------------------------------------------------
# Usage instructions
# asset <- parameters$assets[[1]]
# model <- model_type_contract(asset$asset_type)
# period_chunk <- model$simulate_itinerary(
#   period_chunk        = period_chunk,
#   asset               = asset,
#   calculation_mode    = 1,
#   calculation_context = "plan"
# )
# -------------------------------------------------------------

model_type_contract <- function(asset_type) {

  # -------------------------------------------------------------
  # 1. Check the type
  # -------------------------------------------------------------
  {
    if (!is.character(asset_type) || length(asset_type) != 1 ||
        is.na(asset_type)) {
      stop("model_type_contract: asset_type must be a single text ",
           "value, the asset_type of an asset of the asset registry")
    }
  }

  # -------------------------------------------------------------
  # 2. The contract of each type
  # Each type gives its table of functions: they are named, not
  # called, and the caller calls the operation it needs.
  # -------------------------------------------------------------
  {
    if (asset_type == "Building") {
      # building_model_contract is called to get the table of the
      # operations of the type Building, which lives with the code
      # of the type.
      contract <- building_model_contract()
    } else if (asset_type == "Photovoltaic") {
      # photovoltaic_model_contract is called to get the table of the
      # operations of the type Photovoltaic, which lives with the
      # code of the type.
      contract <- photovoltaic_model_contract()
    } else if (asset_type == "Battery") {
      # battery_model_contract is called to get the table of the
      # operations of the type Battery, which lives with the code of
      # the type.
      contract <- battery_model_contract()
    } else {
      stop("model_type_contract: there is no contract for the type of ",
           "model '", asset_type, "'")
    }
  }

  return(contract)
}
