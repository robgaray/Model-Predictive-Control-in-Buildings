# Flexibility, Revenues and Events

Real-life markets provide incentives (revenues) for stakeholders to support grid stability. These consist on separate payments for commitments to flexibilize loads (either/both upwards and downwards), and for the execution of these commitments upon short-notice orders by the grid operator.

Flexibility bids and commitments operate in a similar way to energy trading. Except that in this case, the commitment is not the consumption/injection of energy, but the willingness to adapt load profiles as requested by the grid operator. The same market horizons and resolutions apply.

## Certainty & Dual Path

Although the Energy market seeks certainty in energy delivery, the Flexibility market seeks adaptability to unexpected deviations/events. Accordingly, the load profile of a builiding is no longer certain, and it can deviate anyway in the folllowing range.

Final Load (t) = Base Load (t) +- Activation likelyhood (t) \* Flexibility Comitment (t)

Accordingly, there is a need to ensure that the building remains within comfort levels whichever the Final Load (t) is.

To do so, a **dual path approach** is performed in the assessment. The performance of the building shall satisfy confort conditions for the following two paths:

-   Base load, without activation of the flexibility requests

-   Flexibilized load, with full activation of the flexibility requests

Any real situation is expected to lie somewhere in between these cases. With either shorter-timespan, or partial-load activation of the flexibility commitment.

## Flexibility Events & Model in this repository

The flexibility market is equal to the energy market in terms of market horizon and resolution, but the activation of flexibility commitments are not expected to be continuous. Activation will be discontinuous and partial, linked to the operational needs of the energy grid.

To define this, we have defined a simplified model in `price_emulation.R` . This model creates fictive flexibility events, where the price of flexibility commitments and commitment execution, as well as the execution probability is defined as follows:

-   A maximum number of events per day are defined. Then for each day in the simulation the actual number of events is obtained based on a random number.

-   The maximum price for flexibility commitments and executions is defined. Then for each day in the simulation the actual price for these is obtained based on a random number.

-   The maximum length of a flexibility event is defined. Then for each day in the simulation the actual price for event length is obtained based on a random number.

-   The events are placed in the time series. For each day, the initiation timestep of each events is obtained based on a random numbers.

-   The maximum likelyhood of a flexibility event is defined. And then the likelyhood of flexibility for any given day is obtained based on a random number.

Altogether this provides an economic context for the simulations to be performed.

## Revenues

Within the decision-making process, and the reward formulae, Economic balances with the network are assessed as follows:

-   Cost/Revenue of Energy Flow is considered with 100% certainty

-   Revenues for flexibility commitments are considered with 100% certainty

-   Revenues associated for the execution of flexibility commitments are considered with the likelyhood defined in the section above

------------------------------------------------------------------------

[Back to README](../README.md)
