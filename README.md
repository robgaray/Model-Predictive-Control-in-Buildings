# Model Predictive Control for Buildings

This project is a test environment for Model Predictive Control in Buildings. I could write much more, but it is better that you explore each subsection below to better understand it and see if it is useful for you.

## Content of this repository

In this repository, a model predictive control for building is tested. A full-year simulation is performed and the most optimal action path is decided periodically.

The optimal action path considers the following:

-   Ensuring optimal comfort during occupancy periods

-   Minimizing the cost of energy

-   Committing in the flexibility market (optional)

Some output:

![](99_Readme/reward_vs_run_number.jpeg){width="600"}

![](99_Readme/week_52.jpg){width="600"}

(It should be noted that figures correspond to an earlier version of the code)

Although some variants are also possible through the code, the figures represent a basic approach where at each midnight, the action path for the following day is decided.

The code is fully parametrized, and tested for parametric simulations in supercomputers. Auxiliary scripts and graphic interfaces are provided. (all this is better explained below)

## Context

Buildings are inertial systems. Conditioning these for human use also implies that a large share of energy is used to heat-up building structures. As these structures have a relevant inertia, there are relevant transient processes to consider in heating buildings. There is some time in between we start heating-up buildings until these get to a comfortable status. Equally, if heating is turned off, temperature variations will be slow, allowing to keep comfort for some time.

There is an increasing number of houses heated with electric systems, commonly heat pumps. These systems present a number of particularities that should be considered for their operation:

-   Relatively low installed capacity. Due to large equipment costs, heat pump sizing is quite sharp, and complemented with backup electric resistances.

-   Heat pump performance is very dependent on outdoor temperature.

-   The cost of heating with heat pumps is linked to the cost of electricity, which is increasingly variable due to increasing shares of renewable energy in the electricity production mix.

These kind of systems would benefit from a predictive control, that would activate heat pumps during low cost periods while ensuring occupant comfort. Model Predictive Control (MPC) is an increasingly common approach for this.

Additionally, electric networks are increasingly populated with renewable energy sources, and many energy-using systems are switching to electric eneergy (i.e. Electric Vehicles, or Heat Pumps). This imposes increasing constraints and stress to the electric network. Due to the specificicities of the electric system, it must react to any deviation (i.e. failure of one power plant,...) by adapting load profileas and/or replacing the energy generation. Systems that are willing to help the stability of the electric system are rewarded based on their availability, as well as the execution of commitments.

Again, the thermal inertia in buildings seems to be a good source of flexibility. Once heated, the building will remain hot/warm for some time, even if Heat Pumps are stopped/operated at lower load for some time.

## Components, data and parameters

The Model Predictive Control system consists of the following:

-   A full year worth of meteorological data and electricity prices `/01_Simulation/01_Data/Main_df.csv` (or.rds)

-   A semi physical (RC) building energy model linked to a heat pump model `/01_Simulation/02_Config/Model_parameters.csv`

-   A genetic algorithm to perform the predictive optimization

-   A policy to assess the goodness of a particular solution

### Model

The energy model is based on a reduced order (RC) building model with integrated HVAC and heat pump models. The details of the model, including the building physics, thermostat, heating and cooling systems, ventilation, shading, and occupancy are described in [Model](99_Readme/Model.md).

### Control modes & setpoints

2 control modes are foreseen:

-   Setpoint based: Here, setpoints for heating and cooling are freely set by the optimized within a pre-defined range, as per the indications above.

-   Mode based: Here, the optimizer decide from a pre-defined set of modes in the `setpoint_modes.csv` file. Each mode has pre-set heating and cooling setpoints.

The control mode is flagged through the "control_type" variable in the main.R script.

Even if simulations are performed at a lower resolution, setpoints and modes are defined in agreement with a market resolution (typically 15 minutes or one hour).

Although still in early stages of research, it seems that Mode-based optimization is a faster and better approach.

### Optimization aims

Two optimization aims are considered:

-   Energy: System setpoints/modes are optimized so that the energy cost is minimized (or revenues maximized).

-   Flexibility: System setpoints/modes are optimized, for minimal energy costs/maximal energy revenues, but also leaving some space to commit flexibility services to the market.

In all cases, the [policy] weights economic costs/revenues and comfort levels.

More information on the flexibility market, revenues and how to consider this in the policy is available in [Flexibility_Events](99_Readme/Flexibility_Events.md).

### Policy

A policy that incorporates heating costs and comfort is used.

For comfort: If the building is occupied, but not in comfort, a high penalty is given (the negative of the `Alpha_confort` parameter, now set to 10)

For energy: The cost of heating is considered as a negative reward

Then both terms are added.

It should be stated that the cost of energy is typically in the range of 0,0X. That is, 2-3 orders of magnitude below the penalty for being out of comfort. Accordingly, this reward is highly biased towards prioritizing occupant comfort.

For the cases where the optimization aim is flexibility, a more complex reward formula definition is used:

-   Confort is assessed both for the case with baseline operation and for the extreme case where all the flexibility is activated.

-   Revenues associated to flexibility are incorporated.

More information on this is available in [Flexibility_Events](99_Readme/Flexibility_Events.md).

### Genetic algorithm for MPC

The MPC system optimizes the performance of HVAC systems in the building by considering different setpoints/operation modes in the future and their effect in the system. A Genetic Algorithm is used for this, particularly the ga() function in the GA library.

In this function, the setpoints/modes the prediction/optimization are encoded as the vector X. Depending on which operational mode is used, two different optimization processes are performed:

-   Setpoints are real-type values and theser are limited with upper and lower bounds. These bounds are linked to the limits established in the setpoint dataframe. (see in the section below). real-type optimization is performed.

-   Operation modes are a set of pre-defined modes. In these cases, vector X defines if a particular mode is active or not. Accordingly, a binary-type optimization is performed.

The genetic algorithm performs a large number of simulations with different values of X in batches. Each batch is a "generation". From each batch to the following one, the values of X evolve in a process that resembles human evolution. That is the reason for the name of "genetic algorithm".

Genetic algorithms in this work are parametrized with the following parameters:

-   Population size: Number of individual simulation in each generation.

-   Maximum iterations: Maximum number of generations in the genetic algorithm

-   Number of runs: Number of times where the full process is executed

### Optimization and control horizons

MPC optimizes a system considering its performance over a given time. In this case, two timeframes are considered:

-   Optimization horizon: The MPC optimizes the performance of the building, considering its performance over the optimization horizon timeframe.

-   Control horizon: The optimal setpoints/modes arising from the MPC are implemented for the control horizon.

The control horizon must be strictly equal or smaller than the optimization horizon.

Differentiating between these two variables allows for the MPC to consider longer periods when defining optimal criteria, but then re-evaluate the best future option at the end of each control cycle. This is particularly relevant for simulations with imperfect forecasts, and to ensure that the optimum also considers the transition between subsequent control horizons.

Considering how energy markets operate, there is a need to forecast energy/flexibility in buildings with some anticipation, so that bids can be properly placed in the market. For this purpose, this code allows to perform an anticipated optimization. To do so, the building is simulated (with operation criteria defined in the previous optimization/control loop) until the beginning of the optimization horizon, and then the optimization process is initiated.

This is illustrated in the figure below.

![](99_Readme/optimizer_horizons.jpg){width="800"}

### Data

#### Data used in the simulation

Sample (but not fully correct) data for the 2019 is available at `/01_Data/Main_df.rds` (the same data is also available in a csv file).

Some other data sources:

Climate data for any location in the world can be sourced from [OpenMeteo](https://open-meteo.com/)

Electricity data for any country in Europe can be sourced from <https://ember-energy.org/data/european-wholesale-electricity-price-data/>

#### Flexibility events

Flexibility events are defined synthetically, so that the simulation can show the result of a response to a flexibility price incentive. More details on how the flexibility price signals are generated is available in [Flexibility_Events](99_Readme/Flexibility_Events.md).

#### Utils to get data (incomplete)

Weather and electricity market data is required.

`/10_Utils_data/` has some scripts to get weather data from [OpenMeteo](https://open-meteo.com/) and energy prices from [EESIOS](https://www.esios.ree.es/es/pagina/api).

From there on, there is a need to adapt energy prices to get three signals:

-   Spot Price of Electricity [€/MWh]

-   Revenue for flexibility commitments [€/MWh]

-   Revenue for the execution of commitments [€/MWh]

This is performed with quite straightforward arithmetic operations, considering the above-indicated data sources, as well as fees for TSO/DSOs. This is not yet incorporated into the repository.

## Parametrization of simulations (Model, Optimizer,....)

This computational code has many parameters that can be modified to adapt the model to different buildings, contexts, and simulation settings. Parameters can be edited directly in the CSV files located under `/01_Simulation/02_Config/`, or through the Graphic User Interface provided in `/40_GUI/01_Configure_Simulation/GUI_config.R`, which offers an intuitive way to modify all configuration files without manual CSV editing.

For a detailed description of the available parameters, configuration files, and how to use the GUI, see [Model_Parametrization](99_Readme/Model_Parametrization.md).

## Code Architecture

For a detailed visual representation of the code structure, including the hierarchical relationships between scripts and functions, see the [Code Hierarchy Chart](90_Structure/Main_relations.md).

## Notes on code usage

This code is developed in R 4.5.0.

Main.R is the main script, allowing to execute the simulation.

The user should expect a **very long execution time**. Depending on the hyperparameter selection for the GA function, execution time is somewhere in between 1h and several days.

Hyperparamter tuning for the GA function is unfeasible in a personal computer. We performed this by means of parametric simulations in a supercomputer facility. The code used for this activity is referred to in the following section.

## Computation at Scale

Running full-year Model Predictive Control simulations and parametric studies can require very long execution times. High-performance computing resources, such as supercomputers, are often necessary to run these simulations in a reasonable time frame. This repository includes adapted code and a Graphic User Interface to define and deploy parametric simulations on SLURM-based supercomputer environments.

For a detailed description of how to run simulations at scale, manage jobs, and use the supercomputer GUI, see [Computation_at_scale](99_Readme/Computation_at_scale.md).

## Auxiliary code and Graphic User Interfaces

### Parametric simulations

Already presented under [Computation at Scale].

### Graphic User Interface

A few graphic user interfaces are available to parametrize simulations under 40_GUI:

-   `/01_Configure_Simulations/` allows to easily edit all configuration files under `/01_Simulation/02_Config/`

-   `/02_Configure_Parametric_Simulations/` allows to generate parametric simulations for supercomputers easily /see under [Computation at Scale]).

The reader/user should consider that these scripts have been fully written with generative AI, with minimal supervision. But they have been tested to work properly to execute their tasks.

### Analysis scripts

`/20_Postprocess/`

Auxiliary scripts are available for the evaluation of parametric simulations (`/20_Postprocess/01_Hyperparameter_Analysis`) and plotting the time series of a simulation (`/20_Postprocess/02_Flexibility_Analysis`).

These shall be considered as basic scripts for supervision of simulations and early-stage model output analysis. But they are useful.

The reader/user should consider that these scripts have been fully written with generative AI, with minimal supervision (as they are used for the generation of preliminary graphs).

## Changes and version control

The current version of this work is Version v2. It has the previous changes from previous versions:

-   Mode-based optimization

-   Joint optimization of energy consumption and flexibility commitments

-   Incorporation of weather forecasting errors

Additionally, the following non-scientific improvements are present:

-   Full re-structuration of code

-   Improvement of the genetic optimizer parametrization

-   Incorporation of auxiliary codes for pre-processing (utils) and postprocessing

-   Redefinition of code for operation with supercomputers

-   Development of Graphic User Interfaces for simulation parametrization and defintion of supercomputer codes

Previous releases (v1.X) were focused on performing load optimization, based only on energy (without considering flexibility).

## Authors & contributors

The main author of this code is [Dr. Roberto Garay-Martinez](https://robertogaray.com/).

The following contributions are acknowledged:

-   [Mr Rubén Mulero](https://www.linkedin.com/in/rubenmulero/). Contributed in a better understanding of Genetic Optimizers.
-   [Mr. Noe Fontier](https://www.linkedin.com/in/noe-fontier/). Contributed with the extraction of climate and energy price time series; and with the development of model formulae (under the guidance of Dr. Garay-Martinez).

## Future works

This is v2 of an ongoing work. I expect to increase the aim, and complexity of this work. Particularly with regards to the following topics:

-   Incorporate the execution of flexibility to the simulation. Currently load profile is optimized considering flexibility commitments, but these are not executed.

-   Incorporate the execution of flexibility to the simulation, considering imperfect forecasts. This will lead to side works on how to define the level of commitment so that it is executable even with imperfect forecasts

-   "Improve" imperfect forecasts. I´m thinking on different possibilities such as: non-controlled heat sources/sinks, or using different models for forecasts and simulation, among others. Also, self-identification of hidden states in the models for forecasting (Although this is known in the simulatior, the forecast should self-define this state).

-   Generalize the MPC approach to aggregated systems (i.e. building + PV) or other systems (i.e. swimming pool heating).

-   Adapt for a concurrent market structure, using Intra-Day and continuous Intra-Day markets to adapt comitments as time goes by.

-   ...

All of the above will take some time (it is not clear to me if I will perform all of them), and is a potential source of new ideas.

## Acknowledgements

I have used the DIPC Supercomputing Center to test our code, and run our simulations (probably now in the range of \>1exp4 simulations or \>1exp5 hours of computational time). I acknowledge the technical and human support provided by the [DIPC Supercomputing Center](https://dipc.ehu.eus/en/supercomputing-center).

## 
