# compute_available_segments.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/compute_available_segments.R`

## Function

Generic interval arithmetic: given a horizon [horizon_begin, horizon_end] (numeric, seconds since epoch) and a list of forbidden intervals (each a length-2 numeric vector c(lo, hi), in the same units), returns the free segments of the horizon once every forbidden interval has been clipped to the horizon and merged. Makes no assumption about how many forbidden intervals there are, whether they overlap each other, or how they relate to any particular market configuration.

## Called by

- [generate_flexibility_events.R](generate_flexibility_events.md)
- [try_flex_echo.R](try_flex_echo.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- horizon_begin       : Numeric scalar. Start of the horizon (seconds).
- horizon_end         : Numeric scalar. End of the horizon (seconds).
- forbidden_intervals : List of length-2 numeric vectors c(lo, hi). May be empty (list()).

## Output data

- Data frame with columns start, end (numeric, seconds): the free segments within [horizon_begin, horizon_end], in ascending order.
- Zero rows if the whole horizon is forbidden or horizon_end <= horizon_begin.

## Other notes from the file header

### Usage instructions

```r
compute_available_segments(horizon_begin, horizon_end,
  list(c(lo1, hi1), c(lo2, hi2)))
```

### Code outline

1. Return nothing when the horizon is empty or inverted, and the whole horizon when nothing is forbidden.
2. Clip every forbidden interval to the horizon and drop the ones that fall outside it.
3. Merge what overlaps and return the gaps left between them.

## Diagram

![Block diagram of compute_available_segments.R](compute_available_segments.jpg)

Also available as [compute_available_segments.svg](compute_available_segments.svg).

---

[Back to the code structure index](../Code_Structure.md)
