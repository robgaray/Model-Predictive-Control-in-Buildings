# 04_subset_main_df.R

**Script** &nbsp;·&nbsp; `30_Simulation/04_Scripts/04_subset_main_df.R`

## Function

Cuts Main_df down to the period to simulate, so that a short run (for testing or diagnosis) needs no change to the data files. Two parameters of parameters$debug_and_config select the period:

- month_subset: 0 keeps the whole year; a value from 1 to 12 keeps only the rows of that month
- period_subset: 0 keeps every remaining row; any other value keeps only that many rows, counted from the start, or all of them if there are fewer

The month is applied first, then the number of rows. It runs after 03_climate_priority.R, which needs the whole year to tag the first days of the period.

## Called by

- [Main.R](Main.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- Main_df, with its time column, still covering the whole year.
- parameters$debug_and_config : month_subset and period_subset.

## Output data

- Main_df, cut to the selected month and number of rows. Nothing else is modified.

## Other notes from the file header

### Code outline

1. Keep the rows of the selected month, if one is selected.
2. Keep the first period_subset rows, if a number is set.

### Usage instructions

```r
source(file.path("30_Simulation", "04_Scripts", "04_subset_main_df.R"))
```

Not called: sourced by Main.R (step 5), after the climate priority and before the profiles.

## Diagram

![Block diagram of 04_subset_main_df.R](04_subset_main_df.jpg)

Also available as [04_subset_main_df.svg](04_subset_main_df.svg).

---

[Back to the code structure index](../Code_Structure.md)
