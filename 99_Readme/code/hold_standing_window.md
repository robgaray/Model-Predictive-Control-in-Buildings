# hold_standing_window.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/hold_standing_window.R`

## Function

Keeps a standing flexibility commitment that the builder would not rebuild, by writing it straight onto the electricity itinerary of the leg and marking its Commitment Phase.

## Called by

- [derive_flex_itineraries.R](derive_flex_itineraries.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- period_chunk : Data frame. The chunk being derived.
- leg          : Character scalar, "down" or "up".
- window_rows  : Integer vector. Rows of the standing Commitment Phase.
- standing     : Numeric vector as long as period_chunk has rows. The committed energy of the leg, in kWh, as the previous market left it.

## Output data

- The chunk with Elec_total_plan_flex_<leg> carrying the standing commitment over window_rows and Flex_phase_<leg>_plan set to 1 there.

## Other notes from the file header

### Why it exists

A refusal of the builder says that it would not draw the window over this plan, not that the commitment is gone. If a window the builder refused were simply dropped, the market would buy the commitment back and re-issue nothing, so the energy would leave the books with no counterpart.

### What it does and does not do

reward_function() recomputes the committed energy as the difference between the plan and the leg's itinerary over the Commitment Phase, so writing that difference is what preserves the commitment exactly. The THERMAL columns of the itinerary are left as the plan's, and the next market tries to rebuild the window in full. Holding the commitment with an approximate thermal itinerary is worth more than losing the commitment, which is the alternative.

### Code outline

1. The rows worth holding
2. Impose the commitment on the electricity itinerary

### Usage instructions

```r
period_chunk <- hold_standing_window(period_chunk, "down", rows, standing)
```

## Diagram

![Block diagram of hold_standing_window.R](hold_standing_window.jpg)

Also available as [hold_standing_window.svg](hold_standing_window.svg).

---

[Back to the code structure index](../Code_Structure.md)
