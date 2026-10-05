# place_flex_candidate.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/place_flex_candidate.R`

## Function

Draws one flexibility event candidate (start + duration), both discretized to the market_resolution grid: duration is an integer number of slots (>= 1, up to max_duration_hours/slot), and the start is a slot-aligned position within one of the given available segments, chosen so the candidate fits entirely inside it. Used identically for:

- Scheduling candidates: segments = Available_m, with forbidden zones already removed
- Piloting candidates: segments = the market's own full horizon, no forbidden zones
- basic-mode per-day candidates: segments = the day's [0, 24h) window

Returns NULL whenever no candidate can be placed (max_duration_hours shorter than one slot, or no segment long enough) - a silent, no-error outcome by design: the market then places no event.

## Called by

- [09_flexibility_price_emulation.R](09_flexibility_price_emulation.md)
- [generate_flexibility_events.R](generate_flexibility_events.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- available_segments  : Data frame with columns start, end (numeric, seconds). May have zero rows.
- market_resolution_sec : Numeric scalar. Slot length, in seconds.
- max_duration_hours    : Numeric scalar. Max_flex_period_duration (or equivalent), in hours.

## Output data

- List with two numeric elements, in seconds, or NULL if no candidate could be placed:
    - t_start_sec
    - duration_sec

## Other notes from the file header

### Usage instructions

```r
place_flex_candidate(available_segments, market_resolution_sec = 900,
  max_duration_hours = 2)
```

### Code outline

1. Draw a duration, in whole market slots, up to the maximum.
2. Keep the segments long enough to hold it.
3. Draw one of them, and a start inside it on the slot grid.

## Diagram

![Block diagram of place_flex_candidate.R](place_flex_candidate.jpg)

Also available as [place_flex_candidate.svg](place_flex_candidate.svg).

---

[Back to the code structure index](../Code_Structure.md)
