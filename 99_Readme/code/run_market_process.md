# run_market_process.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/run_market_process.R`

## Function

Executes one market optimization process (Scheduling or Piloting) over a sliced simulation period. The market works on a piece (build_market_piece()): the table of the system and one table per asset. Each asset starts its plan from the state it has actually reached at i0, its executed state, and the plan is then simulated with the forecast of this market, asset by asset, on the view of each one (piece_asset_view()). Between i0 and i_begin_horizon the plan is simulated as it stands, and both flexibility itineraries are projected over it: the windows committed from i0 onwards are drawn as the new plan allows, without judging them and without changing any commitment. When a window whose Commitment Phase starts there runs into the optimization horizon, that period is extended to the end of its Recovery Phase, and what the optimization needs to continue the tail is handed over in simulation_control$flexibility$pre_horizon_tail (the rows and the phases of the tail, and the state and the system of every asset): the optimization continues it over the plan of each candidate and starts no window of the same leg on it. Every function this process calls works on the piece: the valuation of the committed recovery, the projection and the derivation of the itineraries, the hand-over of the tail, the reward, the optimization and the evaluation of a candidate. The plan of each asset is simulated in its view, the assets that read the net electricity of the rest of the system (operation reads_rest_net of their type of model) after the others (asset_simulation_order()), with the electricity of the plan of those in their view (write_rest_net()). The aim of the market is read from the market parameters and travels down the call chain with the control metadata and as an argument: parameters is only read during the simulation. Whatever the aim, the optimization keeps the commitments of the market interval inside the commitment margin: the part the new plan no longer holds is given back (see derive_flex_itineraries()). That is the only flexibility a market with the "operation" aim trades. When an asset offers alternatives for the Recovery Phase of a window (a battery), the windows it restates are drawn with the one that has the best reward (build_recovery_valuation()). The valuation of the committed recovery draws the committed flexibility over the committed plan. The "operation" and "operationflex" aims keep that plan, so they take that derivation when the plan they simulate and their control are identical to the ones it was drawn with, instead of drawing it a second time.

## Called by

- [run_market_role.R](run_market_role.md)

## What it calls, in order of appearance

- [map_optimization_aim.R](map_optimization_aim.md)
- [model_type_contract.R](model_type_contract.md) &nbsp;(5 call sites)
- [piece_asset_view.R](piece_asset_view.md) &nbsp;(5 call sites)
- [piece_absorb_asset.R](piece_absorb_asset.md) &nbsp;(5 call sites)
- [pre_horizon_window_tails.R](pre_horizon_window_tails.md)
- [piece_rows.R](piece_rows.md) &nbsp;(3 call sites)
- [asset_simulation_order.R](asset_simulation_order.md) &nbsp;(2 call sites)
- [write_rest_net.R](write_rest_net.md) &nbsp;(2 call sites)
- [itinerary_columns.R](itinerary_columns.md) &nbsp;(4 call sites)
- [piece_write_rows.R](piece_write_rows.md) &nbsp;(3 call sites)
- [derive_flex_itineraries.R](derive_flex_itineraries.md) &nbsp;(2 call sites)
- [hand_over_window_tail.R](hand_over_window_tail.md)
- [committed_recovery_cost.R](committed_recovery_cost.md)
- [optimize_control_step.R](optimize_control_step.md)
- [build_recovery_valuation.R](build_recovery_valuation.md)
- [reward_function.R](reward_function.md)
- [evaluate_control.R](evaluate_control.md)
- [console_message.R](console_message.md)
- [console_time.R](console_time.md) &nbsp;(2 call sites)

## Blocks

The piece calls 19 items, so it is documented in blocks:

- [Called items, block 1 of 4](run_market_process__1.md)
- [Called items, block 2 of 4](run_market_process__2.md)
- [Called items, block 3 of 4](run_market_process__3.md)
- [Called items, block 4 of 4](run_market_process__4.md)

## Input data

- prefix             : Character. "Sched" or "Pilot".
- row_index          : Integer. Current simulation row index.
- piece              : List. The period to process, as build_market_piece() returns it: the rows of Main_df as the table of the system, and the rows of the table of each asset.
- market_parameters  : List. Market fields for the current row.
- simulation_control : List. Control metadata (indexes, evaluation, flexibility, calculation_mode).
- timestamps         : List. Timestamp metadata for the piece.
- parameters         : List. Simulation parameters. Its asset registry (parameters$assets) gives the type of model of each asset, whose operations simulate it (model_type_contract()), and joined_cols the columns of the view of an asset.
- marginal_context   : Named list or NULL (default NULL). As returned by resolve_marginal_context(), computed by run_market_role() from Main_df before this market's optimization. Passed through to optimize_control_step() (for "energy"/ "flexibility" aims) and evaluate_control() (for "operationflex"); unused for "operation".
- worker_cluster     : Cluster of worker processes of the simulation (start_worker_cluster()) when parallel = 1, NULL otherwise. Passed through to optimize_control_step().
- market_name_width  : Integer. Width the name of the market is padded to in the console line of the market, the width of the longest market name.
- Callers must guard the call with is_market_active() on the relevant *_Market_Name field; this function assumes the market is active and does not re-check it.

## Output data

- List. The piece with the plan, the flexibility itineraries and the commitments injected over the control horizon, and Reward over the optimization horizon.

## Other notes from the file header

### Usage instructions

```r
run_market_process(prefix, row_index, piece, ...)
```

### Code outline

0. Error management
1. Ranges of the market
2. Aim of the market
3. Start of the plan
4. Initialization period
    - 4.1. Subset
    - 4.2. Fill the setpoints
    - 4.3. Simulation
    - 4.4. Injection
    - 4.5. Windows that run into the horizon
5. Optimization
    - 5.1. Subset, missing control and committed recovery
    - 5.2. Optimization
    - 5.3. Injection

## Diagram

![Block diagram of run_market_process.R](run_market_process.jpg)

Also available as [run_market_process.svg](run_market_process.svg).

---

[Back to the code structure index](../Code_Structure.md)
