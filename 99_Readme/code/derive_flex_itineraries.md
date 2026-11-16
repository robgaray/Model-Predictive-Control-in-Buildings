# derive_flex_itineraries.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/derive_flex_itineraries.R`

## Function

Builds the two flexibility itineraries of a candidate from its own _plan itinerary AND the flexibility already committed by earlier markets, instead of throwing that commitment away.
Why the standing commitment is the starting point If both flexibility itineraries started as a copy of _plan with the commitment set to zero, every market would begin its search as if nothing had ever been sold. The reward does know about the standing commitment, because resolve_marginal_context() reads it from Main_df before optimizing, so undoing it costs money. But the ITINERARY the search works on would start at zero, so the optimizer would have to pay its way back to where it already was. On a flat optimum that is enough for the answer to flip from one market to the next, selling and rebuying the same commitment again and again. Here the standing commitment is the starting point instead.

## Called by

- [committed_recovery_cost.R](committed_recovery_cost.md)
- [evaluate_control.R](evaluate_control.md)
- [run_market_process.R](run_market_process.md)

## What it calls, in order of appearance

- [itinerary_columns.R](itinerary_columns.md)
- [sum_asset_energy.R](sum_asset_energy.md)
- [piece_asset_view.R](piece_asset_view.md) &nbsp;(3 call sites)
- [piece_absorb_asset.R](piece_absorb_asset.md) &nbsp;(3 call sites)
- [piece_layout.R](piece_layout.md)
- [model_type_contract.R](model_type_contract.md)
- [system_flex_frame.R](system_flex_frame.md)
- [system_flex_window.R](system_flex_window.md)
- [system_flex_commitment.R](system_flex_commitment.md) &nbsp;(4 call sites)
- [choose_recovery.R](choose_recovery.md)
- [reconstruct_flex_phases.R](reconstruct_flex_phases.md)
- [system_hold_window.R](system_hold_window.md) &nbsp;(2 call sites)

## Blocks

The piece calls 12 items, so it is documented in blocks:

- [Called items, block 1 of 2](derive_flex_itineraries__1.md)
- [Called items, block 2 of 2](derive_flex_itineraries__2.md)

## Input data

- piece              : The piece of the market the derivation works on. The _plan itinerary of each asset is already simulated in its table. The standing commitment is in Elec_flex_down_plan / Elec_flex_up_plan of the table of the system, as it came from Main_df. The system side reads the table of the system: the standing commitment, the phases, the reconstruction of the standing windows, MarketUTC, and the commitment written in block 3. The asset side works on each asset: its plan copy in its own table, the state of its tail on row 1 of its table, restate_systems and continue_window_tail in its view. The window builder and the holding of a window (system_flex_window() and system_hold_window()) work on the piece: the window builder draws on it and returns a piece, and the holding of a window returns the piece with the share held.
- parameters         : Named list. Model and control parameters. Its asset registry (parameters$assets) gives the type of model of each asset, whose operations (model_type_contract()) choose the system of a restated window (restate_systems) and continue the tail of a window (continue_window_tail). The windows are drawn by system_flex_window(), and held by system_hold_window().
- simulation_control : Named list, as system_flex_window() expects. Reads: indexes_local$i_end_control - last row of the market interval in this piece. flexibility$restatement_mode - "guard" (default) or "projection", see above. flexibility$pre_horizon_tail - when present, one entry per leg (down, up) for a window whose Commitment Phase started before this piece, as run_market_process() builds it: rows   - rows of this piece it occupies. phases - its phase code on those rows. state  - list named by asset_id, each a one-row data frame. The state of the flexibility itinerary of the asset on row 1 of its table. system - list named by asset_id. The system of each asset that provides it.
- recovery_valuation : Named list or NULL (default NULL). build_recovery_valuation() gives it: the alternatives with which the assets that store energy may draw the Recovery Phase of a window, and what is needed to value them. With NULL, or with no asset of the window that offers alternatives, nothing changes.

## Output data

- Named list: piece        : the piece with both flexibility itineraries built in the table of each asset, and their phases marked and the commitment they carry written in Flex_phase_<leg>_plan and Elec_flex_<leg>_plan of the table of the system. held         : Data frame, one row per asset and leg that holds energy of a window with rows in the guard zone (see "Assets that refuse a standing window" above), with the columns asset_id and leg. The caller reports each of them as not technically feasible. feasible     : Logical. TRUE when held has no row.

## Other notes from the file header

### How a standing window is held over a new plan

The commitment is stored in kilowatt hours of electricity, and what the window builder takes is a thermal profile. Rather than invert the electrical model - which is piecewise and underdetermined, since one electricity figure does not say how much came from each machine - this function solves for the one number the window was built from. The window builder of the system, system_flex_window(), is parameterised, on both legs, by a flexibility fraction in (0, 1], and the electricity a window commits, on the net, grows monotonically with it. So for each standing window the fraction is found by bisection, calling the repository's own builder at each step, until the electricity it commits matches what was sold. The Neutral and Recovery Phases then come out built by the same code that built them originally, with the same power caps, and over the NEW plan.

### Projection and guard zone

Every row of a Commitment Phase is restated in one of two ways, depending on where it falls, whatever the aim of the market:

- Guard zone: rows inside the market interval, from the start of the piece to i_end_control, when the restatement mode is "guard". This market trades those rows, so the commitment margin is demanded of them. When the new plan cannot hold what was sold with the margin, the window is restated at the most the margin allows, and the difference shows up as a smaller commitment, which the economic chain books as a re-purchase. This is the only flexibility a market whose aim is operation alone ever trades.
- Projection: every other row, and every row when the restatement mode is "projection". No market trades those rows here: earlier markets did, and later markets or the execution will. The window is drawn as the new plan allows, with no margin and no judgement of its feasibility, and the commitment sold there is not changed. The reward values it at most at that commitment: what the plan can no longer hold there is the re-purchase a later market will have to make.

A window whose Commitment Phase crosses a limit of the market interval is split: each part takes its own fraction. The minimum flexibility does not apply to a restated window: it is a rule on what a market sells, and a restatement sells nothing new. A market interval of the guard zone that the new plan can only hold below the minimum keeps what it holds, and only the shortfall is re-purchased.

### The system of a standing upward window

Which system serves a standing upward window is not stored: only its energy is. Each building finds it again over the new plan, through the operation restate_systems of its type of model (building_restate_systems()). When the prudence rule of resolve_flex_up_hvac() names a system, the window is rebuilt with it, as it would be sold. When the rule is undecided, the window is not refused for that: the rule decides whether a NEW window is sold, and this one was already sold. The window is then built with heating and with cooling, at the largest fractions, and the system kept is the one with which the building contributes and the window reaches what was sold (a window that would raise both systems of the building over the plan is refused by it). When both reach it, the one that uses more electricity in the plan over the long horizon of the rule (flex_up_horizon_long) is kept. When neither reaches it, the system kept is the one that, with the building contributing, commits more of what was sold: in the guard zone and in the projection, the electricity the window commits on the net up to what was sold there. The window is then restated with it as with a system the rule names: at the most it allows, with the shortfall of the guard zone re-purchased. When both systems are refused, the building refuses the window. With several buildings whose rule is undecided, their systems are chosen one building at a time, in the order of the asset registry, with the systems already chosen for the buildings before.

### Assets that refuse a standing window

How the assets shared a window is not stored, so a restated window is drawn by the system (system_flex_window()) with every asset of the registry, at one fraction for the set. An asset may refuse to redraw it (for a building, because it would raise both systems, because the plan leaves it no room, or because both systems are refused for an upward window whose system the rule leaves undecided). An asset may also accept it with no energy: a battery never refuses a window already sold, and when it has nothing to offer on it, what it does not reach is bought again. It does not refuse the window, so it holds none of it. Then:

- the assets that redraw it cover what was sold with their common fraction, as far as they can;
- what they do not reach, in the guard zone or in the projection, is held by the assets that refuse it, within the limits of their equipment (system_hold_window());
- what is still missing is re-purchased.

When no asset redraws the window, every asset that can hold it does. With a single asset, the window is either redrawn or held whole. Holding is a physical capability of the equipment: the operation can_hold of the model of each asset says whether the asset can keep its electricity apart from its plan (model_type_contract()). The holders, and the assets counted in the penalty, are chosen among the assets that can, in the order of the registry. When a commitment stands and no asset can hold, the run stops with a message. The Recovery Phase of an asset that stores energy A window restated over the new plan, the tail of a window and a window that is held are drawn with the alternative of the Recovery Phase that has the best reward, as a new window is (see system_flex_window()), when the valuation is given. The fractions of a restated window are found without the valuation, because the commitment does not depend on the Recovery Phase, and the window is then built once more with the fractions kept and the valuation, which chooses the alternative. The tail of a window is continued by every asset with the first alternative; each asset that offers alternatives and has a state in the tail continues it again with each of the others, and choose_recovery() keeps the piece with the best reward. The window held is chosen in system_hold_window(). The window held is handed to the holders with the phase of each of its rows, rebuilt from the commitment that stands, and the row where the control horizon closes: an asset that stores energy, a battery, leaves its leg realizable until then, correcting the Recovery Phase of the window it holds (system_hold_window()). An asset that holds a window with rows in the guard zone cannot deliver it as sold, and it is reported, for that leg, as not technically feasible. Only the assets that actually hold energy in the window (more than flex_energy_tol, once it is held) are reported, with at least one asset per leg: when none of the holders keeps energy there, the first of them in the order of the registry is reported, so that a leg that cannot be delivered is never free.

### Code outline

1. Take the standing commitment and lay the baseline
2. Restate each standing window over the new plan
3. Write the commitment the itineraries carry

### Usage instructions

```r
derived <- derive_flex_itineraries(piece, parameters,
  simulation_control)
```

### Exceptions and special cases

- With no standing commitment both itineraries are equal to _plan, with phases and commitment at zero.
- The commitment is written here, from the itineraries just drawn, with the definition reward_function() uses: the difference between the net electricity of the system in the itinerary and in the plan (system_flex_commitment()), over the Commitment Phase. A market that places no new window, or whose aim does not value flexibility, therefore keeps the commitment it restated instead of losing it.
- Row 1 of every table of the piece is the initial state of the simulation and is never simulated, so it carries no commitment of its own and is left out of every window: a window starts at row 2 at the earliest, and system_flex_window() takes the row before its start as its initial condition.
- A window whose Commitment Phase ended before this piece has only its Neutral and Recovery Phases left in it. They are continued over the plan of this piece by the operation continue_window_tail of each asset (continue_standing_tail() for a building), from the state handed over on row 1. Each asset continues the tail with its own state and system. It is also given the row where the control horizon closes, and the halvings and the tolerance of a bisection, so that a battery corrects the Recovery Phase of the tail and leaves its leg realizable until that row.
- A window whose Commitment Phase started before this piece and runs into it is rebuilt from row 2, with row 1, where the state of its itinerary is handed over, as its initial condition, so it continues the part the earlier stretch projected.
- An asset may refuse a window: it would raise both systems, or the new plan leaves no room to draw it, for instance because it already runs the system at its bound. A refusal is no reason to throw away energy already sold: the commitment is held within the limits of the equipment, and the next market rebuilds it. A window with rows in the guard zone held by an asset is also reported through held, because the plan cannot deliver that window as sold.
- The bisection is bounded to flex_restatement_bisection_steps halvings. It is solving one monotone scalar equation, so a few tens of steps take it far below the energy tolerance of the model.

## Diagram

![Block diagram of derive_flex_itineraries.R](derive_flex_itineraries.jpg)

Also available as [derive_flex_itineraries.svg](derive_flex_itineraries.svg).

---

[Back to the code structure index](../Code_Structure.md)
