# battery_margin_fit.R

**Function** &nbsp;·&nbsp; `30_Simulation/05_Models/03_Battery/03_Functions/battery_margin_fit.R`

## Function

Fits the margin data of a battery inside the band of the system, when it is the only asset that contributes to a flexibility window. It is the operation margin_fit of the type of model Battery (model_type_contract()). The quantity a battery moves is its electricity, and its electricity is linear in the share of its departure from the plan that the margin leaves. So the rule of system_commitment_margin() for a set of assets has a closed form here. In each market interval of the band, with P the electricity of the plan and F the electricity of the itinerary drawn before the margin, both added over the rows of the interval, and with the band bound by the limit of the leg and the margin:

- if F is inside the band, the share is 1;
- if P is outside the band, the share is 0: the interval has no service to offer and the battery keeps its plan;
- otherwise the share is (bound - P) / (F - P), between 0 and 1.

Each row of the interval then takes its plan plus the share of its departure. A row that belongs to no interval keeps the itinerary as it was drawn.

## Called by

- [battery_model_contract.R](battery_model_contract.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- margin     : Named list. The margin data of the battery, as battery_window_draft() gives it: plan and profile, lists with the vector Elec (kWh), one entry per row of the guard zone.
- band       : Named list. The band of the set, as commitment_margin_bound() gives it: slot_id, the interval of each row of the guard zone (0 when it has none), and bound, the electricity the interval may reach (kWh).
- leg        : Character scalar, "down" or "up".
- parameters : Named list. Not read.
- asset      : Named list. The parameters of the battery. Not read.

## Output data

- Named list with the vector Elec (kWh): the electricity of each row of the guard zone after the margin.

## Other notes from the file header

### Code outline

1. Check the inputs
2. Fit each market interval

### Usage instructions

```r
fitted <- battery_margin_fit(margin     = draft$margin,
  band       = band,
  leg        = "down",
  parameters = parameters,
  asset      = asset)
```

## Diagram

![Block diagram of battery_margin_fit.R](battery_margin_fit.jpg)

Also available as [battery_margin_fit.svg](battery_margin_fit.svg).

---

[Back to the code structure index](../Code_Structure.md)
