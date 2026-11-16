# price_variation_at_lead.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/price_variation_at_lead.R`

## Function

Returns the variation of the energy price, in per cent, that applies to a price quoted a given number of hours ahead.

The four bands
The energy price moves with how far ahead it is quoted, in four bands, each with its own variation in 06_Energy_price_parameters.csv:

- lead >= price_lead_day_ahead_h          Price_variation_day_ahead
- lead >= price_lead_5h_h                 Price_variation_5h
- lead >  price_lead_1h_h                 Price_variation_1_5h
- otherwise                               Price_variation_below_1h

The edges (24, 5 and 1 h in production) live in 01_computing_parameters.csv. They have to decrease in that order, or a band would be empty; a relation of Validation_parameter_relations.csv checks it when the parameters are loaded.

## Called by

- [prepare_market_information.R](prepare_market_information.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- lead_h       : Numeric scalar. Hours between the market event and the interval the price is quoted for.
- energy_price : Named list. parameters$energy_price, for the four Price_variation_* values [%].
- computing    : Named list. parameters$computing, for the three price_lead_* edges [h].

## Output data

- Numeric scalar. The variation of the band the lead falls in [%].

## Other notes from the file header

### Code outline

1. Return the variation of the band the lead falls in.

### Usage instructions

```r
tau <- price_variation_at_lead(lead_h       = 6,
  energy_price = parameters$energy_price,
  computing    = parameters$computing)
```

## Diagram

![Block diagram of price_variation_at_lead.R](price_variation_at_lead.jpg)

Also available as [price_variation_at_lead.svg](price_variation_at_lead.svg).

---

[Back to the code structure index](../Code_Structure.md)
