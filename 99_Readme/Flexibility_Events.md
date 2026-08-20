# Flexibility, Revenues and Events

Real-life markets provide incentives (revenues) for stakeholders to support grid stability. These consist on separate payments for commitments to flexibilize loads (either/both upwards and downwards), and for the execution of these commitments upon short-notice orders by the grid operator.

Flexibility bids and commitments operate in a similar way to energy trading. Except that in this case, the commitment is not the consumption/injection of energy, but the willingness to adapt load profiles as requested by the grid operator. The same market horizons and resolutions apply.

## Certainty & Dual Path

Although the Energy market seeks certainty in energy delivery, the Flexibility market seeks adaptability to unexpected deviations/events. Accordingly, the load profile of a builiding is no longer certain, and it can deviate anyway in the folllowing range.

Final Load (t) is within Base Load (t) +- Flexibility Comitment (t)

Accordingly, there is a need to ensure that the building remains within comfort levels whichever the Final Load (t) is.

To do so, a **dual path approach** is performed in the assessment. The performance of the building shall satisfy confort conditions for the following two paths:

- Base load, without activation of the flexibility requests

- Flexibilized load, with full activation of the flexibility requests

Any real situation is expected to lie somewhere in between these cases. With either shorter-timespan, or partial-load activation of the flexibility commitment.

## Flexibility Events & Model in this repository

The flexibility market is equal to the energy market in terms of market horizon and resolution, but the activation of flexibility commitments are not expected to be continuous. Activation will be discontinuous and partial, linked to the operational needs of the energy grid.

To define this, a model was defined in `flexibility_generation.R`. This model creates fictive flexibility events, where the price of flexibility commitments and commitment execution, as well as the execution probability, are defined. Two modes exist, controlled by `Complex_Market_Config` in `15_Market_config.csv`:

- **Basic** (`Complex_Market_Config == "no"`): a maximum number of events per day, their maximum commitment/execution price, maximum event length and maximum activation likelihood are defined (`15_Market_config.csv`). For each day in the simulation, the actual number of events, prices, event lengths and likelihood are obtained based on random numbers, and each event is placed at a random slot-aligned position within the day.

- **Market-aware** (`Complex_Market_Config == "yes"`): events generated in intra-day are linked. See [Market-aware flexibility generation in detail](#market-aware-flexibility-generation-in-detail) below.

Altogether this provides an economic context for the simulations to be performed.

## Market-aware flexibility generation in detail

Flexibility events are processed in cascade in`generate_flexibility_events.R` as follows:

- Initially, events are defined in scheduling markets.

- As there might be several scheduling markets operationg over the same time span. Any new scheduling market checks for pre-existing events, and defines an exclusion zone of 3h around previously defined events. And then generates new events in the remaining area.

- Additionally, existing events may be slightly shifted (anticipated or delayed) in scheduling markets.

- During piloting, new flexibility events are randomly generated. These are assumed to arise either from unanticipated grid stability needs, or from balancing markets. These events are more frequent in the short-term. 

### Scheduling

A Scheduling market plans flexibility events well ahead of time, the same way a day-ahead or intraday energy market plans purchases well before delivery. Each Scheduling market covers a fixed period of time, called its horizon (for example, the next 24 hours). Its goal is to decide, in advance, when the building could offer flexibility during that horizon.

For a specific day, the very first Scheduling market does not have any pre-existing definition: no flexibility events exist yet anywhere in the simulation. In this case, the market simply creates a small number of new candidate events (up to a configured maximum per day) at random positions inside its own horizon. Each candidate gets a random start time, a random duration, and its own commitment price, execution price, and probability of being activated.

Every later Scheduling market does not start blank. By the time it runs, earlier Scheduling markets may already have placed events, and some of those events may fall close to, or inside, this new market's horizon.

Every existing event keeps a 3-hour exclusion zone before and after it - a period of time reserved just for that event. This exists because after the building offers flexibility once, it needs time to recover before it can safely offer flexibility again. A new event can never be placed inside another event's exclusion zone.

So, before placing any new candidate, a new Scheduling market first checks whether any existing event's exclusion zone reaches into its own horizon.

For each pre-existing event, there is a possbility to slightly displace the event. This is only allowed once: a random draw decides whether the event should try to move earlier, move later, or not move at all. If a move is attempted, the event shifts by a random amount (up to a configured maximum hours), but only if the new position does not land inside any other event's exclusion zone. If it does not fit, the event simply stays exactly where it was. Either way, this is that event's only chance to move - no later market will ever offer it another one.

Only after this step does the market place its own new candidate events - and only in whatever parts of its horizon are still free of every event's exclusion zone.

### Piloting

A Piloting market reacts much closer to real time than a Scheduling market. Its goal is to represent flexibility that becomes available on short notice - for example, because the grid needs help right now, or because a short-term balancing market has just opened close to the delivery time.

A Piloting market places its candidate events the same simple way a blank-slate Scheduling market does: it draws a small number of new candidate events (up to a configured maximum per day), each with a random start time and duration inside the market's own horizon.

Unlike Scheduling, a Piloting market never checks for an exclusion zone, and never tries to move any existing event out of the way. A Piloting candidate can be placed at any time inside its horizon, even if that time is already used by a Scheduling event.

Instead, every Piloting candidate goes through a different check: the closer the start time is to the moment the market opened (its `Bid_time`), the more likely it is for a flexibility event to occur. The further into the future , the less likely it is to occur. This is meant to represent how, in a real short-term market, deviations are more frequent in the short-term.

If a Piloting event ends up covering the same time as an existing Scheduling event, the Piloting event replaces it there. This is because every Piloting market is processed only after all Scheduling markets are done, and it represents the most up-to-date decision for that moment in time.

## Revenues

Within the decision-making process, and the reward formulae, Economic balances with the network are assessed as follows:

- Cost/Revenue of Energy Flow is considered with 100% certainty

- Revenues for flexibility commitments are considered with 100% certainty

- Revenues associated for the execution of flexibility commitments are considered with the likelyhood defined in the section above

------------------------------------------------------------------------

[Back to README](../README.md)
