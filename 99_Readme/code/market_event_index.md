# market_event_index.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/market_event_index.R`

## Function

Builds the index of market events of one role: one entry per market event, with its own market interval, its name and the period it trades, sorted by market interval.

## Called by

- [imperfect_price_forecast.R](imperfect_price_forecast.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- Main_df : Data frame. Must carry the market timeline columns <role>_Market_Name, <role>_Market_Period_Begin and <role>_Market_Period_End, plus MarketUTC.
- role    : Character scalar, "Sched" or "Pilot". Which of the two market families the index is built for.

## Output data

- Data frame with one row per market event of the role, sorted by market_utc, and the columns:
    - market_utc
    - market_num
    - name
    - begins_num
    - ends_num The three "_num" columns are seconds since the epoch:
- the caller compares them against instants inside its own loop, and doing that arithmetic on numbers rather than on POSIXct is what keeps the lookup cheap. market_utc stays POSIXct because it is matched against the time column of the price matrices. Zero rows when the role has no active market at all, which callers treat as "no history available" rather than as an error.

## Other notes from the file header

### Why it is a function of its own

The index depends only on Main_df and the role, never on the instant being forecast nor on the price signal being read. market_price_history() used to rebuild it on every call, and it is called once per instant and once per price signal, so the same scan of Main_df was repeated thousands of times per market execution. Building it once per forecast and passing it down is what makes the price forecast affordable; it is the same change imperfect_forecast() got for the weather history.

### Code outline

1. Resolve the role's timeline columns
2. Keep the rows where a market of that role is active
3. One row per market event, sorted

### Usage instructions

```r
events <- market_event_index(Main_df, role)
```

### Exceptions and special cases

- An inactive market is written as 0 in the name column, so the filter tests against "0" and 0 rather than calling is_market_active(): this runs inside the optimizer's inner loop and a vectorised test on the raw column is enough.

## Diagram

![Block diagram of market_event_index.R](market_event_index.jpg)

Also available as [market_event_index.svg](market_event_index.svg).

---

[Back to the code structure index](../Code_Structure.md)
