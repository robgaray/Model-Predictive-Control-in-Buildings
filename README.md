# Model Predictive Control for Buildings

This project is a test environment for Model Predictive Control in Buildings. Much more could be written here, but it is easier to explore each subsection below to understand the project and see if it is useful for a given case.

### Version 6 note:
This is an early release of Version 6, while the code is ready for release, the documentation is yet to be fully verified.

The current documentation has been machine-updated.

The user should expect a v6.1 release soon with a better documented readme.

## Index

1. [Content of this repository](#1-content-of-this-repository)
2. [Context](#2-context)
3. [Components](#3-components)
4. [Model](#4-model)
5. [Control modes & setpoints](#5-control-modes--setpoints)
6. [Policy](#6-policy)
7. [Market Structure](#7-market-structure)
8. [Decision making processes and optimization aims](#8-decision-making-processes-and-optimization-aims)
9. [Marginal cost in the evaluation of solutions](#9-marginal-cost-in-the-evaluation-of-solutions)
10. [Genetic algorithm](#10-genetic-algorithm)
11. [Optimization and control horizons](#11-optimization-and-control-horizons)
12. [Flexibility events](#12-flexibility-events)
13. [Parametrization and Graphic User Interface](#13-parametrization-and-graphic-user-interface)
14. [Input-Output files](#14-input-output-files)
15. [Economic data structures](#15-economic-data-structures)
16. [Notes on code usage](#16-notes-on-code-usage)
17. [Standalone optimizer for third-party use](#17-standalone-optimizer-for-third-party-use)
18. [Changes and version control](#18-changes-and-version-control)
19. [Known Issues](#19-known-issues)
20. [Discontinued items](#20-discontinued-items)
21. [Authors & contributors](#21-authors--contributors)
22. [Future works](#22-future-works)
23. [Acknowledgements](#23-acknowledgements)

# 1. Content of this repository

In this repository, a model predictive control for building is tested. A full-year simulation is performed and the most optimal action path is decided periodically.

The optimal action path considers the following:

- Ensuring optimal comfort during occupancy periods

- Minimizing the cost of energy

- Committing in the flexibility market (optional)

The specific interest of this repository is that the optimal action is defined in a decision-making process structured and syncronized with day-ahead, intra-day and continuous intra-day markets.

Some output:

<img src="99_Readme/reward_vs_run_number.jpeg" width="600" />

<img src="99_Readme/week_52.jpg" width="600" />

It should be noted that figures correspond to an earlier version of the code. Although the code allows for a more complex decision-making process, these figures represent a basic approach where at each midnight, the action path for the following day is decided.

The code is fully parametrized, and tested for parametric simulations in supercomputers. Auxiliary scripts and graphic interfaces are provided. (all this is better explained below)

[back to top](#model-predictive-control-for-buildings)

# 2. Context

Buildings are inertial systems. Conditioning these for human use also implies that a large share of energy is used to heat-up/cool-down building structures. These structures have a relevant inertia, with associated transient processes. There is some time between starting to heat a building and reaching a comfortable status. Equally, if heating is turned off, temperature variations will be slow, allowing to keep comfort for some time.

There is an increasing number of houses heated/cooled with electric systems, commonly heat pumps. These systems present a number of particularities that should be considered for their operation:

- Relatively low installed capacity. Due to large equipment costs, heat pump sizing is quite sharp, and complemented with backup electric resistances.

- Heat pump performance is very dependent on outdoor temperature.

- The cost of heating with heat pumps is linked to the cost of electricity, which is increasingly variable due to increasing shares of renewable energy in the electricity production mix.

These systems would benefit from a predictive control to activate heat pumps during low cost periods while ensuring occupant comfort. Model Predictive Control (MPC) is an increasingly common approach for this.

Additionally, electric networks are increasingly populated with renewable energy sources, and many energy-using systems are switching to electric energy (i.e. Electric Vehicles, or Heat Pumps). This imposes increasing constraints and stress to the electric network. Due to the specificities of the electric system, it must react to any deviation (i.e. failure of one power plant,...) by adapting load profiles and/or replacing the energy generation. Systems that are willing to help the stability of the electric system are rewarded based on their availability, as well as the execution of commitments.

Again, the thermal inertia in buildings seems to be a good source of flexibility. Once heated, the building will remain hot/warm for some time, even if Heat Pumps are stopped/operated at lower load for some time.

[back to top](#model-predictive-control-for-buildings)

# 3. Components

The Model Predictive Control system consists of the following:

- A full year worth of meteorological data and electricity prices `30_Simulation/01_Data/Meteo_df.rds` and `30_Simulation/01_Data/Energy_Prices_df.rds` (or .csv)

- A semi physical (RC) building energy model linked to a heat pump model `30_Simulation/02_Config/20_Assets/Building_001/11_Model_parameters.csv`

- A photovoltaic generation model, with no control, for the photovoltaic installations of the system `30_Simulation/02_Config/20_Assets/<asset_id>/17_Photovoltaic_parameters.csv`

- An electric battery model, for the batteries of the system, which charge from the system and discharge into it `30_Simulation/02_Config/20_Assets/<asset_id>/19_Battery_parameters.csv`

- A genetic algorithm to perform the predictive optimization

- A policy to assess the goodness of a particular solution

- A large set of configuration files allowing for the parametrization of the simulation `30_Simulation/02_Config/`, with a folder for each asset of the system in `30_Simulation/02_Config/20_Assets/`

[back to top](#model-predictive-control-for-buildings)

# 4. Model

The energy model is based on a reduced order (RC) building model with integrated HVAC and heat pump models. The details of the model, including the building physics, thermostat, heating and cooling systems, ventilation, shading, and occupancy are described in [Model](99_Readme/Model.md).

A system can also hold photovoltaic installations. They have no control: they produce electricity from the solar radiation and the outdoor temperature of the weather file, with the tilt and the orientation of their modules and the position of the sun, and the optimizer takes no decision on them. Their production is part of the net electricity of the system, which is what the markets buy and sell. Their model is described in [Model](99_Readme/Model.md#photovoltaic-installation).

A system can also hold electric batteries. A battery takes electricity from the system to charge, and gives it back to the system when it discharges. On each market interval the optimizer chooses one of five modes for it: charge only with the electricity the rest of the system would give to the grid, charge as much as it can, discharge only to cover the electricity the rest of the system takes from the grid, discharge as much as it can, or stop. The battery always stays within its limits: its lowest and highest state of charge, and its largest charge and discharge power. When the simulation runs the real operation, the battery keeps the mode of the plan, so the electricity it exchanges follows the real consumption and production of the other assets, which may differ from the plan. Its model is described in [Model](99_Readme/Model.md#battery).

[back to top](#model-predictive-control-for-buildings)

# 5. Control modes & setpoints

The control is mode based: the optimizer decides, for every market period, one mode from a pre-defined set of modes in the `13_Modes_setpoints.csv` file of the building (`30_Simulation/02_Config/20_Assets/Building_001/13_Modes_setpoints.csv`). Each mode has pre-set heating and cooling setpoints. The same file sets `Deadband` [degC], the width of the hysteresis band of the thermostat around each setpoint.

A battery is controlled by modes too, but its five modes are fixed and need no file: they are described in [Model](99_Readme/Model.md#battery).

Even if simulations are performed at shorter timesteps, modes are defined in agreement with a market resolution (typically 15 minutes or one hour).

The setpoint-based control, in which the optimizer set the heating and cooling setpoints freely within a range, is no longer part of the repository - see [Discontinued items](#20-discontinued-items).

[back to top](#model-predictive-control-for-buildings)

# 6. Policy

A policy that incorporates heating costs and comfort is used. The reward it produces is dimensionless, and it is built from two terms that are each brought to a pure number by their own weight.

- Comfort: System temperature is compared with reference temperatures at every time step. If the building is outside its comfort band, a penalty is given for every hour spent that way, weighted by the `alpha_comfort` [1/h] parameter of the building, which each building sets in its own `18_Comfort_parameters.csv`. The plan is measured against the more restrictive of two bands: the occupancy band (the service band of `18_Comfort_parameters.csv` while occupied, the setback band otherwise) and the scheduling band (the service band tightened before occupancy and according to the season by the corrections of `10_Operational_temperature_corrections.csv`). Inside a flexibility window, from the Commitment Phase to the end of the Recovery Phase, the flexibility itineraries are measured against the occupancy band. Outside occupancy, the temperature is checked against the setback band. The setback band is not a comfort target. It is defined to keep the building out of regions of undesired behavior, for the integrity of the system.

- Energy (and flexibility): The cost of Energy is aimed to be minimized. Accordingly, the cost of heating is considered as a negative reward. Every economic term is weighted by the `alpha_cost` [1/€] parameter. Shall there be a revenue, (i.e. by selling energy to the grid, or trading flexibility), this is incorporated in the same way with a possitive value.

Then both terms are added.

## Trade offs

It should be stated that the cost of energy is typically in the range of 0,0X. This implies that the cost of energy is typically 2-3 orders of magnitude below the penalty for being out of comfort. Accordingly, this reward is highly biased towards prioritizing occupant comfort. Additionally, `alpha_comfort` is typically one order of magnitude above `alpha_cost`to enhance this behavior.

## Revenue discount

A decision should be cautious about money it expects to earn far into the future. for that reason, any future income (i.e. by flexibility) is discounted to account for the associated uncertainty. THe following  formula is used: `discount = (1 - Revenue_discount_per_hour/100) ^ n`, with `n` being the number of hours from the instant the market is optimized to that interval.

Expense is never discounted, and neither is the comfort term. The asymmetry is deliberate: discounting a cost would make distant operation look cheaper than it is and would invite the optimizer to push spending towards the end of the horizon, which is the opposite of prudence.

The discount belongs to the decision and stops there. It changes which candidate the optimizer picks, never the volume or the price at which the winning candidate is then settled, so no commitment carries it into the accounts.

## Reward definition in the context of flexibilized behavior

The reward has the same terms whatever the optimization aim. The flexibility terms are 0 when nothing is committed. With the energy aim no new flexibility is sold, but the flexibility already sold is valued: a plan that cannot hold it pays for buying part of it back. Inside the control horizon that is what the market settles. After it, the commitment cannot change yet, so the reward counts the buyback a later market will have to make, and never counts more flexibility than was sold. Every economic term values only the change against what earlier markets already committed, so an itinerary identical to the committed one is valued 0. The terms are:

- Comfort is assessed for the three itineraries: baseline operation, the extreme case where all the downward flexibility is activated, and the extreme case where all the upward flexibility is activated.

- The revenues for flexibility commitments are incorporated, and they are split in two. The commitment itself is paid for whether or not the service is ever called, so it is valued at the commitment price alone. The activation is conditional, so it is valued at the execution price weighted by the likelihood of activation. It also carries the cost of the energy the assets would have to move while returning to their planned state, valued as the change against the cost of the itineraries already committed.

- When the system holds a battery, the energy it leaves stored has a value, because it is energy that will not have to be bought later. It is valued at the mean price at which the market buys energy over its horizon, after the losses of discharging it. For the plan, the energy left stored at the end of the optimization horizon is valued: a plan that leaves more energy stored than the plan already committed earns the value of the difference, and one that leaves less pays it. For each flexibility itinerary, the energy the battery is left with above or below the plan is valued in the same way, weighted by the likelihood of activation, together with the cost of its return. When the change is a gain, it is discounted as a future income, with the discount of the last interval of the horizon.

- Both directions of the service are searched for: reducing the load (downward flexibility) and increasing it (upward flexibility). Once a flexibility event is over, the system that did not provide the service may hold or reduce its power, but never increase it, which is an interpretation of the legal regulation of HVAC systems.

More information on this is available in [Flexibility_Events](99_Readme/Flexibility_Events.md).

[back to top](#model-predictive-control-for-buildings)

# 7. Market Structure

In this work, energy flows are defined in a 3-level market:

1. Scheduling
2. Piloting
3. Execution

Quite in line with how markets operate in Western Europe.

- Scheduling markets correspond with day-ahead and intra-day markets. In these markets the base programme for energy production and use is defined, quite in advance (i.e. day-ahead markets close 12h before the actually-traded day). Given this anticipation, it is common to have poor accuracy in load prediction, particularly for small and non-industrial loads. There is one day-ahead and 3 intra-day markets per day.

- Piloting markets are scheduled every hour and allow to adapt loads starting \~one hour after market closure. This allows to substantially adapt the base energy use programme with better and shorter load forecasts.

- Execution is not a market per se. This is just real-life energy delivery. It is common to have some deviations in this delivery when compared with the energy traded in the previous markets.

The following picture shows the structure of Day Ahead (DA), Intra Day (ID) and Continuous Intra Day (cID) in Spain.

![](99_Readme/OMIE.jpg)

Source: [OMIE, Mercado de Electricidad (2026/06/13)](https://www.omie.es/es/mercado-de-electricidad)

Currently, the code develops a dummy market price signal dataset based on simplified data. But the user can bypass it by adapting the behavior of the following blocks of code of `run_simulation()`, in `30_Simulation/03_Functions/run_simulation.R`:

7. Initialise market columns in Main_df, and the table of the market events

8. Flexibility generation (conditional)

9. Energy/flexibility price signals (buy/sell derivation)
    
    

[back to top](#model-predictive-control-for-buildings)

# 8. Decision making processes and optimization aims

Decision-making process occurs in two steps:

- Scheduling. A long-term setpoint/operational mode schedule is defined. This is commonly linked to day-ahead and/or intra-day markets, where schedules up to \~ 36h ahead are defined.

- Piloting. Here, the already-defined overall schedule is "piloted" and potentially adapted for changes in the price of energy or potential short-term flexibility needs

In these cases the following optimization aims are considered:

- Energy: System setpoints/modes are optimized so that the energy cost is minimized (or revenues maximized).

- Energy+Flexibility: System setpoints/modes are optimized, for minimal energy costs/maximal energy revenues, but also leaving some space to commit flexibility services to the market.

- Operation: This mode is only possible when a previous Energy (or Energy+Flexibility) optimization has been executed. It is used in Piloting decision processes, where setpoints are already pre-defined, but the volumes of purchased energy can be modified due to closer forecasting of the behavior of the building.

- Operation+Flexibility: This mode is similar to the previous one, but allows for the commitment in the flexibility market on short notice.

In all cases, the [policy](#6-policy) weights economic costs/revenues and comfort levels.

Every market, Scheduling and Piloting alike, plans against the same comfort band (`Scheduling_T_*`): the more restrictive of the occupancy band (`Service_T_*`) and the scheduling band, which is the service band of `30_Simulation/02_Config/20_Assets/Building_001/18_Comfort_parameters.csv` tightened while the building is prepared for occupancy and according to the season, as set in `30_Simulation/02_Config/20_Assets/Building_001/10_Operational_temperature_corrections.csv`. Inside a flexibility window the flexibility itineraries are measured against the occupancy band. The executed operation is checked against the occupancy band (`Service_T_*`).

More information on the flexibility market, revenues and how to consider this in the policy is available in [Flexibility_Events](99_Readme/Flexibility_Events.md).

[back to top](#model-predictive-control-for-buildings)

# 9. Marginal cost in the evaluation of solutions

In agreement with the process explained in the preceding sections, for each moment in time, energy flows are traded several times throughout the preceding scheduling and piloting markets.

In each of these trades (except in the first one), the optimizer must define a course of action, considering previously committed energy/flexibility trades. For instance, in IDA2, there might be X kWh already purchased for H07Q2.

The optimizer shall define if X is sufficient, too much or too few energy. And then define if more energy must be purchased or sold. This is what we call Marginal operation. An Energy purchase/sell that would adapt existing commitments to meet the desired net energy flow. Say that one option states that X+Y kWh are needed for H07Q2. In this case Y kWh must be purchased.

At IDA2, only Y needs to be purchased. Accordinly, it is only Y that needs to be introduced into the energy cost terms in the [Policy](#6-policy) (together with distribution costs, etc.).

As a result, the formula defined in the [Policy](#6-policy) considers:

- All the confort terms within the optimization horizon

- Only marginal costs/revenues within the optimization horizon

[back to top](#model-predictive-control-for-buildings)

# 10. Genetic algorithm

The MPC system optimizes the performance of HVAC systems in the building by considering different setpoints/operation modes in the future and their effect in the system. A Genetic Algorithm is used for this, particularly the ga() function in the GA library.

In this function, the modes of the prediction/optimization are encoded as the vector X. Operation modes are a set of pre-defined modes, so vector X directly contains integer mode indices (1 to n_modes) for each market period. The GA uses real-type encoding with custom population, crossover, and mutation operators that maintain integer constraints throughout the optimization, avoiding one-hot encoding or rounding artifacts.

The genetic algorithm performs a large number of simulations with different values of X in batches. Each batch is a "generation". From each batch to the following one, the values of X evolve in a process that resembles human evolution. That is the reason for the name of "genetic algorithm".

Genetic algorithms in this work are parametrized with the following parameters:

- Population size: Number of individual simulation in each generation.

- Maximum iterations: Maximum number of generations in the genetic algorithm

- Runs without improvement: the algorithm stops after this many consecutive generations with no improvement of the best solution (`run_number`)

- Crossover probability: probability that two solutions are combined (`pcrossover`)

- Mutation probability: probability that a value of a solution is changed at random (`pmutation`)

They are set in `30_Simulation/02_Config/01_Optimization_parameters.csv`.

The genetic algorithm decides only the assets that take decisions: the buildings, with one mode of their `13_Modes_setpoints.csv` for each market period, and the batteries, with one of their five modes for each market period. When the system has several of them, they are decided together: the vector X holds the modes of all of them. When the system has none, for example when it holds photovoltaic installations only, the genetic algorithm does not run: every market simulates the plan with the forecast of the weather, as a market with the Operation aim does.

[back to top](#model-predictive-control-for-buildings)

# 11. Optimization and control horizons

The MPC optimizes a system considering its performance over a given time. In this case, two timeframes are considered:

- Optimization horizon: The MPC optimizes the performance of the building, considering its performance over the optimization horizon timeframe.

- Control horizon: The optimal setpoints/modes arising from the MPC are implemented for the control horizon.

The control horizon must be strictly equal or smaller than the optimization horizon.

Differentiating between these two variables allows for the MPC to consider longer periods when defining optimal criteria, but then re-evaluate the best future option at the end of each control cycle. This is particularly relevant for simulations with imperfect forecasts, and to ensure that the optimum also considers the transition between subsequent control horizons.

Considering how energy markets operate, there is a need to forecast energy/flexibility in buildings with some anticipation, so that bids can be properly placed in the market. For this purpose, this code allows to perform an anticipated optimization. To do so, the building is simulated (with operation criteria defined in the previous optimization/control loop) until the beginning of the optimization horizon, and then the optimization process is initiated.

This is illustrated in the figure below.

<img src="99_Readme/optimizer_horizons.jpg" width="800" />

As a result of this process:

- The optimizer considers the optimal result of the confort levels, energy flows flexibility commitments and expected economic flows over the **Optimization Horizon**.

- The energy flows and flexibilty commitments are fixed, also in economic terms for the **Control horizon**

[back to top](#model-predictive-control-for-buildings)

# 12. Flexibility events

When operating in flexibility mode, the system receives incentives to flexibilize its behavior. It is allowed to commit upwards and downwards flexibility. Thus, three linked paths are assessed together:

- Standard path (no flexibility)

- Modification for upward path

- Modification for downward path

Flexibility commitments are defined through an event-like approach, with threee phases:

- Commitment. Initially, the system modifies its behavior

- Neutral. Once the commited flexibility is executed, some time is provided where loads equal the standard path. This time is defined to allow for trading in continuous-intra-day markets for the recovery phase.

- Recovery. Here, a recovery path is defined (through the above-mentioned trading) to recover the standard path. A battery only has to recover when it could not otherwise go on with its plan until the end of the control horizon. When the recovery is optional, the market chooses the option that pays more (see [Flexibility_Events](99_Readme/Flexibility_Events.md#batteries)).

More details on how the flexibility price signals are generated is available in [Flexibility_Events](99_Readme/Flexibility_Events.md).

[back to top](#model-predictive-control-for-buildings)

# 13. Parametrization and Graphic User Interface

This computational code has many parameters that can be modified to adapt the model to different buildings, contexts, and simulation settings. Parameters can be edited directly in the CSV files located under `30_Simulation/02_Config/`, or through the Graphic User Interface provided in `20_GUI/01_Configure_Simulation/GUI_config.R`, which offers an intuitive way to modify the configuration files without manual CSV editing. The files of `00_Inner_parameters/`, which hold internal settings of the simulation engine, are edited by hand.

The configuration has two levels. The files directly under `30_Simulation/02_Config/` configure the system as a whole, and their values are common to every asset: the optimizer, the markets, the prices, the flexibility events, the reward, the forecast and the run. The reward file (`09_Reward_parameters.csv`) holds the weight of cost and the discount of future revenue, which are common to every asset. The comfort weight and the comfort bands are not in it: each building has its own. The assets of the system are listed in `12_Asset_registry.csv`, and each asset has its own folder, `30_Simulation/02_Config/20_Assets/<asset_id>/`, with the files that describe it. For a building, these are the corrections of its reference temperatures (`10_Operational_temperature_corrections.csv`), its thermal model and heat pump (`11_Model_parameters.csv`), its modes and the deadband of its hysteresis (`13_Modes_setpoints.csv`), its occupancy (`14_Use_Patterns.csv`) and its comfort, that is its comfort weight and its comfort bands (`18_Comfort_parameters.csv`). For a photovoltaic installation, its folder holds one file, `17_Photovoltaic_parameters.csv`, with its location, the treatment of the solar radiation, the orientation of its modules, the area and efficiency of its modules and their losses, its temperature coefficient, its NOCT and the efficiency and power of its inverter. For a battery, its folder holds one file, `19_Battery_parameters.csv`, with its capacity, its lowest, highest and initial state of charge, its largest charge and discharge power, its charge and discharge efficiencies and its self-discharge. The shipped configuration has one building, `Building_001`. To add a building, raise the number of buildings in the Graphic User Interface. To do it by hand, add a row to `12_Asset_registry.csv` with its id and its type, for example `Building_002,Building`, and create its folder, `30_Simulation/02_Config/20_Assets/Building_002/`, with the same five files. A photovoltaic installation or a battery is added in the same way, for example `Photovoltaic_001,Photovoltaic` or `Battery_001,Battery`, with its one file. A system needs at least one asset, of any type. All the buildings of a system share the weather, the markets and the prices. The markets buy and sell the net electricity of the whole system, and they sell its flexibility as one. The distribution cost is paid on all the energy the system exchanges with the grid, in both directions: when the system exports, the energy it sells pays it too.

The Graphic User Interface edits every asset of the system. Its first tab, `Assets`, has one selector per type of model, for example `Building assets [count]`, with the number of assets of that type. Each asset has its own tab, named by its asset id, with one tab inside it for each file of its folder. Every value shows its unit in square brackets, and a value with no unit shows `[-]`. When a number is raised, each new asset takes the name of its type and the lowest free number, for example `Building_002`. The `Reward Function` tab shows the weight of cost and the discount of future revenue, and below them one `alpha_comfort` box for each building, labelled with its asset id, for example `Building_001 [1/h]`. Each box is saved in the comfort file (`18_Comfort_parameters.csv`) of its building, so the boxes appear and disappear as buildings are added and removed. The tab inside each building named `Comfort parameters` holds only its comfort bands. Changing a number never moves you to another tab, and the tab of a new asset is not opened by itself. If its folder already exists, the asset takes the values of that folder. If not, it takes the default values of the repository, which are shown in red until they are saved. A tab is titled in red while it has something pending: values that took a default, or changes that are not saved yet. The tab of an asset is also red while the asset is not in the registry on disk. The red goes when the configuration is saved, and also when a changed value is typed back to the saved one. When a number is lowered, the assets with the highest numbers leave the simulation, after a confirmation. Their folders stay on disk, and the simulation does not read them. The interface writes nothing until a save button is pressed. Every save button checks and writes the whole configuration at once: the files of the system, the asset registry and the files of every asset. If any value is wrong, nothing is written, and the interface lists what must be corrected, with the values each one accepts.

The files of `30_Simulation/02_Config/00_Inner_parameters/` are the inner parameters of the code rather than of a study: the libraries it loads, its computing parameters, the columns the simulation data must hold (those of `Main_df` and those of the table of each type of asset), the physical properties of air, the reference conditions of photovoltaic modules, the solar constant and the paths of every configuration file, of the system and of each asset.

[back to top](#model-predictive-control-for-buildings)

# 14. Input-Output files

The simulation reads two input data files (weather and energy prices) and writes a set of CSV/RDS output files per run:

- Full timestep-by-timestep results of the whole system

- Full timestep-by-timestep results of each asset of the system, one file per asset

- A simulation summary

- Three economic analysis tables.

File locations, the general content and purpose of each file, and a full documentation is available in [Input-Output files](99_Readme/Input_Output_Files.md).

[back to top](#model-predictive-control-for-buildings)

# 15. Economic data structures

Three objects are used to document economic operations:

- `full_market_information`: Prices for all Energy and Flexibility flows in each market along the simulation.

- `market_commitments`: Commitments made by the system in each market.

- `economic_analysis`: Information on economic flows associated to the commitments. Aggregated by market or by market slot.

These are each a grouped of several independent data frames . Detailed documentation of these is available in [Economic data structures](99_Readme/Economic_Data_Structures.md).

[back to top](#model-predictive-control-for-buildings)

# 16. Notes on code usage

Main.R is the main script, allowing to execute the simulation.

This code is developed in R 4.5.0.

## Code structure

The simulation is built out of one entry point, `Main.R`, a set of scripts that it sources in order, and a set of functions that those scripts call. `Main.R` sources a large number of scripts, one after another: first the initialization and the parameters, then the climate priority, the period subset, the occupancy and scheduling profiles and the reference temperatures, then the market timeline, the flexibility events and the price signals, then the price matrices, the commitments and the economic accumulators, then the simulation loop itself, and finally the economic analysis and the output files.

The code that models one type of asset is in a folder of its own: the building is in `30_Simulation/05_Models/01_Building/`, the photovoltaic installation in `30_Simulation/05_Models/02_Photovoltaic/` and the battery in `30_Simulation/05_Models/03_Battery/`. The rest of the code operates the system as a whole, whatever its assets.

Every piece of code the simulation reaches has its own page, with what it does, what calls it, what it calls in order of appearance, what it receives, what it sends out, and a block diagram. The whole map, and how to read it, is in [Code structure](99_Readme/Code_Structure.md).

This repository is currently under development, with a rapid evolution in features, and associated changes in code structure, and data formats. Regretfully, this is not properly documented. Sorry.

The user should expect a **very long execution time**. Depending on the hyperparameter selection for the GA function, execution time is somewhere in between 1h and several days.

Hyperparameter tuning for the GA function is unfeasible on a personal computer. This used to be performed by means of parametric simulations in a supercomputer facility. Given that the code is rapidly evolving, this part of the code was discontinued - see [Discontinued items](#20-discontinued-items) below - but it should be easy to redefine a similar code based on the examples from V2.

[back to top](#model-predictive-control-for-buildings)

# 17. Standalone optimizer for third-party use

The simulation in `30_Simulation/` runs a whole year of markets. But this is not suitable for third parties to execute the optimizer externally.

For this, a standalone version of the optimizer is provided. Here energy and flexibility commitments are optimized for one market, for a system of one or more assets: buildings, photovoltaic installations and electric batteries. Each call names the assets it operates. And the third-party is free to call the optimizer with the most appropriate context information, store its output, etc.

`31_Standalone_code/` holds that program. The code is mostly written in R and shall be executed with Rscript, but it is meant to be called by other tools, in R or in any other language. 

How it works, the full list of inputs and outputs, and how to call it from other tools are explained in [Standalone code](99_Readme/Standalone_Code.md).

## Examples

`50_Examples/` holds example analyses. Each one is a self-contained folder that simulates a building, draws figures and writes a report. It carries its own copy of the simulator, so you can copy it out of the repository and run it.

The first example studies how the building is operated in the day-ahead, intra-day and continuous intra-day markets. It is explained in [Market operation analysis](50_Examples/01_Market_Operation/README.md).

[back to top](#model-predictive-control-for-buildings)

# 18. Changes and version control

The current version of this work is Version v5.1. It has the following changes from previous versions:

### Overall

- Relevant code re-structurations. The code is far from being stable and bugs are solved on the run (sorry for this).

### V6

- Development of a multi-asset environment, the current environment allows to consider multiple assets of the same type as well as different asset types.
- Incorporation of a PV model
- Incorporation of a Battery model

### V5.1

- A new standalone version of the optimizer is incorporated. To be used by third-party callers.

### V5

- Integration of both upward and downward flexibility

- Explicit blocking of physically unfeasible paths from the optimization (i.e. negative energy flows in assets not producing electric energy)

- Estimation of energy prices in the optimization horizon (not known in real-life) based on past market prices.

### V4

- Optimization approach considering Marginal costs (see section 9 above).

- Definition of complex economic data structures and outputs (see sections 14 and 15 above).

- Formal discontinuation of some auxiliary tools & code (not even updated in V3).

### V3

- Re-structuration of market to resemble market structures

- New approach with scheduling and piloting optimizations

- New coding approach to Mode-based optimization in ga(), now with modes encoded as interger values instead of one-hot encoding(in V2).

### V2

- Mode-based optimization

- Joint optimization of energy consumption and flexibility commitments

- Incorporation of weather forecasting errors

### V1

- First load optimization MPC, setpoint-based

See [Discontinued items](#20-discontinued-items) below for functionality that used to exist but is no longer part of the repository.

[back to top](#model-predictive-control-for-buildings)

# 19. Known Issues

## Documentation

The current documentation is a machine updated set of documents over V5.1 texts. It is yet to be checked and improved.

## Calibration of the price estimate

Each market process optimizes over a horizon, and it trades a set of market intervals inside that horizon. For those intervals it has a published price. The optimizer, however, values the whole optimization horizon, which is longer, so for the stretch beyond the control horizon it needs a price that has not been published yet.

With `price_forecast_type = inaccurate`, that price is estimated from what the markets already know (`price_estimate_sources()`). The price of an interval is the one the last earlier market that traded it had. If no earlier market traded it, it is the price of the same interval one day before, from the market itself or from the last earlier market that traded it. If neither exists, it is the mean of the market's own published prices.

What is not settled is how good that estimate is. Whether its error is realistic, in the sense of being corrected by subsequent markets rather than accumulating, has not been measured.

[back to top](#model-predictive-control-for-buildings)

# 20. Discontinued items

The following components were part of earlier versions of this repository but have been removed. Their full source and documentation remain recoverable from the repository's git history.

- **Supercomputer execution scripts** (`31_SCC_Simulation/`) - the adapted `Main_SCC.R` and SLURM job-array scripts used to run parametric simulations on the DIPC supercomputing facility. Present through V2.
- **Post-processing / analysis scripts** (`40_PostProcess/`) - hyperparameter-analysis and flexibility/time-series plotting scripts for reviewing parametric simulation batches (`01_Hyperparameter_Analysis`, `02_Flexibility_Analysis`). Present through V2.
- **Parametric-simulation GUI** (`20_GUI/02_Configure_Parametric_Simulations/`) - a Shiny application (`GUI_parametric.R`) to define and deploy parametric simulation batches on the supercomputer described above. Present through V2.
- **Setpoint-based control** - the optimization in which the GA set the heating and cooling setpoints of every market period freely, as real values within the ranges of `12_Temperature_Setpoints.csv`, selected with `control_type = setpoints` in `02_Control.csv` (`optimize_setpoints()`, `fitness_funct_optimize_setpoint()`, `convert_setpoints()` and the loading of that file). Mode-based control, faster and better in the tests, is the only control left. Present through V5.1.
- **Setpoint padding** - the setpoints `pad_heating` and `pad_cooling` of `02_Control.csv`, given to the market periods that had no mode. Every market period now needs a mode, and the simulation stops if one is missing. The file `02_Control.csv` was removed with them. Present through V5.1.

[back to top](#model-predictive-control-for-buildings)

# 21. Authors & contributors

The main author of this code is [Dr. Roberto Garay-Martinez](https://robertogaray.com/).

The following contributions are acknowledged:

- [Mr Rubén Mulero](https://www.linkedin.com/in/rubenmulero/). Contributed in a better understanding of Genetic Optimizers.
- [Mr. Noe Fontier](https://www.linkedin.com/in/noe-fontier/). Contributed with the development of model formulae (under the guidance of Dr. Garay-Martinez).
- [Ms. Ane Oleaga Cano](https://www.linkedin.com/in/ane-oleaga-cano-74166a225). Contributed with the compilation of time series on energy prices.

[back to top](#model-predictive-control-for-buildings)

# 22. Future works

This is V6 of an ongoing work. The aim and complexity of this work are expected to increase, particularly with regards to the following topics:

- Incorporate the execution of flexibility to the simulation. Currently load profile is optimized considering flexibility commitments, but these are not executed.

- Incorporate the execution of flexibility to the simulation, considering imperfect forecasts. This will lead to side works on how to define the level of commitment so that it is executable even with imperfect forecasts

- "Improve" imperfect forecasts. Different possibilities are being considered, such as non-controlled heat sources/sinks, or using different models for forecasts and simulation, among others. Also, self-identification of hidden states in the models for forecasting (although this is known in the simulator, the forecast should self-define this state).

- Generalize the MPC approach to other systems (i.e. swimming pool heating). Buildings, photovoltaic installations and electric batteries can already be combined in one system.

- ...

All of the above will take some time (it is not clear whether all of them will be carried out), and is a potential source of new ideas.

[back to top](#model-predictive-control-for-buildings)

# 23. Acknowledgements

The DIPC Supercomputing Center has been used to test the code, and run the simulations (probably now in the range of \>1exp4 simulations or \>1exp5 hours of computational time). The technical and human support provided by the [DIPC Supercomputing Center](https://dipc.ehu.eus/en/supercomputing-center) is acknowledged.

[back to top](#model-predictive-control-for-buildings)
