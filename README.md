# Model Predictive Control for Buildings

## Context

Buildings are inertial systems. Conditioning these for human use also implies that a large share of energy is used to heat-up building structures. As these structures have a relevant inertia, there are relevant transient processes to consider in heating buildings. There is some time in between we start heating-up buildings until these get to a comfortable status. Equally, if heating is turned off, temperature variations will be slow, allowing to keep comfort for some time.

There is an increasing number of houses heated with electric systems, commonly heat pumps. These systems present a number of particularities that should be considered for their operation:

-   Relatively low installed capacity. Due to large equipment costs, heat pump sizing is quite sharp, and complemented with backup electric resistances.

-   Heat pump performance is very dependent on outdoor temperature.

-   The cost of heating with heat pumps is linked to the cost of electricity, which is increasingly variable due to increasing shares of renewables in the electricity production mix.

These kind of systems would benefit from a predictive control, that would activate heat pumps during low cost periods while ensuring occupant comfort. Model Predictive Control (MPC) is an increasingly common approach for this.

## Content of this repository

In this repository, a model predictive control for building is tested. A full-year simulation is performed and the most optimal action path is decided periodically.

Although some variants are also possible through the code, the main approach is that each midnight, the action path for the following day is decided.

## MPC components, data and parameters

The Model Predictive Control system consists of the following:

-   A full year worth of meteorological data and electricity prices

-   A semi physical (RC) building energy model linked to a heat pump model

-   A genetic algorithm to perform the predictive optimization

-   A policy to assess the goodness of a particular solution

### Model

The energy model is based on a previous work by Peder Bacher et Al. [1], where a reduced order model of a building was developed. This model was extended by ourselves in Ruben Mulero et Al. [2], where we integrated models for internal loads, radiators and heat pumps.

In this work, we perform an adaptation of [1] and [2] as per the descriptions below.

We admit that many of the decisions taken in the development of this model are quite simple approaches to how Heat Transfer in buildings and Heating Ventilation and Air Conditioning (HVAC) systems work. But feel that this is still a valid approach to illustrate a MPC case.

#### Building

A 2-state model is used with the following states:

-   Indoor temperature (Ti)

-   Envelope temperature (Te)

The following heat transfer and gains are considered:

-   Solar gains are introduced both to Ti and Te

-   Ventilation loop between Ti and outdoor temperature

-   Heating gain into Ti, linked to the activation of the thermostat and the heat output from the heat pump.

-   The following heat transfers

    -   Ti - Te

    -   Te - environment

#### Heat Pump & thermostat

Heating systems are activated by a thermostat. An hysteresis thermostat is defined. In these systems, two thresholds are used:

-   Lower Temperature threshold: If indoor temperature is below this value, the thermostat activates the heating system

-   Upper Temperature threshold: If indoor temperature is above this value, the thermostat deactivates the heating system

In none of these occur (this means that indoor temperature is between these thresholds), the activation state remains constant.

If the thermostat activates, Heat pump power is defined by the temperature difference between the Upper Temperature threshold and the actual indoor temperature (Delta_temp).

Heat Pump power is constrained by a minimum (Q_hp1) for small Delta_temp values (Heat pumps can not operate at ver low part-loads). and a maximum (Q_hp2) for large Delta_temp values (maximum installed power). a linear interpolation is performed in between. A similar approach is used to calculate the COP.

#### Ventilation

Mechanical ventilation is assumed in the building.

When the building is active (see the following section), the building is ventilated at a 2 ACH / 6.36K/kW rate.

during non-occupied hours, a lower ventilation rate of 0.1 ACH / 127.15K/kW is considered. As an exception to this, in very hot periods, larger ventilation rates of 1ACH / 12.75K/kW are used in agreement with a night ventilation strategy.

It should be considered that this approach seems to be OK for a heating-only HVAC system in a cold climate. potentially more advanced approaches would be required in a milder or even hot climate.

### Shading

As a baseline. a 0.7 shading coefficient is used except for very hot periods, where a full shading coefficient of 1 is adopted.

### Occupancy & Internal loads

The building is set as occupied everyday between 7AM and 7PM (actually 6:50PM). This occupancy is used to set ventilation rates, as well as influence comfort-related policies.

No internal loads are used. Although these could be added to the model, they are considered not to be extremely relevant in a low-density building.

### Policy

A policy that incorporates heating costs and comfort is used.

For comfort: If the building is occupied, but not in comfort, a high penalty is given (-1)

For energy: The cost of heating is considered as a negative reward

Then both terms are added.

It should be stated that the cost of energy is typically in the range of 0,0X. That is, 2 orders of magnitude below the penalty for being out of comfort. Accordingly, this reward is highly biased towards prioritizing occupant comfort.

### Genetic algorithm for MPC

The MPC system is programmed with a Genetic Algorithm, by using the ga() function in the GA library.

In this function, the setpoints in the prediction/optimization are encoded as the vector X, and limited with the upper and lower bounds. These bounds are linked to the limits established in the setpoint dataframe. (see in the section below).

The genetic algorithm performs a large number of simulations with different values of X in batches. Each batch is a "generation". From each batch to the following one, the values of X evolve in a process that resembles human evolution. That is the reason for the name of "genetic algorithm".

Genetic algorithms in this work are parametrized with the following parameters:

-   Population size: Number of individual simulation in each generation.

-   Maximum iterations: Maximum number of generations in the genetic algorithm

-   Number of runs: Number of times where the full process is executed

### Data

Data for Denmark is used. In particular, the following signals are obtained from [OpenMeteo](https://open-meteo.com/) and [NordPool](https://www.nordpoolgroup.com/):

-   Environmental air temperature [ºC]

-   Global Horzontal Irradiation [W/m2]

-   Spot Price of Electricity [€/MWh]

Data for the 2019 is available. Although data is exported from the mentioned data sources with hourly resolution, it is resampled for use at 10' resoultion.

Climate data for any location in the world can be sourced from [OpenMeteo](https://open-meteo.com/)

Electricity data for any country in Europe can be sourced from <https://ember-energy.org/data/european-wholesale-electricity-price-data/>

The input data file is available at /01_Data/Main_df.rds (the same data is also available in a csv file).

### Setpoints

The Heat Pump is activated by means of a room thermostat. The MPC optimizes the value of setpoints in the thermostat, so that comfort is achieved whenever the building is occupied.

An auxiliary file is used to define all the possible setpoint values. These are defined considering the following:

-   When the building is occupied, setpoints should always be within the comfort area.

-   Outside occupied periods, this can be done differently, but a minimum temperature should be guaranteed to avoid frosting of the building (about 5ºC).

-   Even if simulations are performed with 10' resolution, setpoints are defined with hourly intervals.

The setpoint file is available at /01_Data/set_point_df.rds (the same data is also available in a csv file).

## Notes on code usage

This code is developed in R 4.5.0.

Main.R is the main script, allowing to parametrize and execute the simulation.

The user should expect a **very long execution time**. Depending on the hyperparameter selection for the GA function, execution time is somewhere in between 1h and several days.

Hyperparamter tuning for the GA function is unfeasible in a personal computer. We performed this by means of parametric simulations in a supercomputer facility. The code used for this activity is referred to in the following section.

## Auxiliary code

### Parametric simulations

It should be considered that MPC requires to run an optimization process periodically (i.e. for every 24 simulated hours). Each of this processes takes several minutes. As a result, running this code in a personal computer is somewhere between impractical and unfeasible.

For that reason, an adapted version of the code was written for its use in a supercomputer. this consists of the following:

-   Main_SCC.R, an adapted version of the simulation.

-   Install_libraries.R, a specific script so that libraries are installed only once and made available for all simulation batches.

-   Job_array_r.sh, a job file for a SLURM queue management system.

-   Console_code.txt, the code to be introduced in the console to run de above.

-   A file that lists all the parametric simulations: /02_Parametric_table/Optim_parameters.csv

NOTES:

-   You should enter your own e-mail in the job array configuration file and edit other slurm parameters based on the specific characterstics of your supercomputer

The current configuration considers variations in the following parameters:

-   Populatio Size in the Genetic Algorithm

-   Iteration Number / Generations in the Genetic Algorithm

-   Number of runs in the Genetic Algorithm

-   Optimization horizon (in hours)

-   Frequency of optimization (in hours)

-   Month

## Repository index

-   Root folder: All scripts are provided:

    -   Main.R & Main_SCC.R are the scripts allowing for the MPC simulation.

    -   console_code.txt, Install_libraries.R, job_array_r.sh and Main_SCC.R are provided as an example to port the code to supercomputers.

    -   Write_parametric_table.R and Postprocess.R are auxliary codes to make parametric simulations and (quite-simple) postprocessing of these.

-   Folders

    -   /01_Data/

        -   Main_df provides the context data for the simulation, and is later used as a file structure to save the output

        -   set_point_df defines the upper and lower values of the acceptable setpoints (in both cases csv and rdf versions of this data is provided)

    -   /02_Parametric_table/

        -   Optim_parameters.csv provides all the configurations to be tested in parametric simulations (only for the \_SCC code)

    -   /03_Functions/

        -   Stores functions

    -   /04_Output/

        -   folder to store outputs, automatically created

    -   /05_Postprocess/

        -   Side folder to store postprocessing outputs, automatically created

Full repository outline:

¦Cconsole_code.txt\
¦ Install_libraries.R\
¦ Job_array_r.sh\
¦ LICENSE\
¦ Main.R\
¦ Main_SCC.R\
¦ Postprocess.R\
¦ README.md\
¦ Write_parametric_table.R\
¦\
+---01_Data\
¦ Main_df.csv\
¦ Main_df.rds\
¦ set_point_df.csv\
¦ set_point_df.rds\
¦\
+---02_Parametric_table\
¦ Optim_parameters.csv\
¦\
+---03_Functions\
¦ F1_timestep_calculation.R\
¦ F2_reward_function.R\
¦ F3_period_calculation.R\
¦ F4_period_calculation_adapted.R\
¦ F5_optimize_setpoints_24.R\
¦\
+---04_Output\
¦ Main_df_X1_X2_X3_X4_X5_X6.csv\
¦ Main_df_X1_X2_X3_X4_X5_X6.rds\
¦ Sinthetized_df_X1_X2_X3_X4_X5_X6.csv\
¦ Sinthetized_df_X1_X2_X3_X4_X5_X6.rds\
¦ (here, all the outputs are stored. Due to file size these are not stored in the repository and only a few of them are provided as an example)\
¦\
+---05_Postprocess\
¦ parametric_simulation_output.csv\
¦ parametric_simulation_output.rds\
¦ reward_vs_run_number.jpg

## Authors & contributors

The main author of this code is Dr. Roberto Garay-Martinez.

The following contributions are acknowledged:

-   Mr. Noe Fontier. Contributed with the extraction of climate and energy price time series; and with the development of model formulae (under the guidance of Dr. Garay-Martinez).

## Acknowledgements

We have used the DIPC Supercomputing Center to test our code, and run our simulations. We acknowledge the technical and human support provided by the DIPC Supercomputing Center.

## References

[1] Peder Bacher, Henrik Madsen, Identifying suitable models for the heat dynamics of buildings, Energy and Buildings, 2011, <https://doi.org/10.1016/j.enbuild.2011.02.005>.

[2] Mulero R, Garay-Martinez R, Mendialdua I, Arregi B. A training workbench based on transient building models for creating intelligent energy operators, Data-Centric Engineering, 2025, <https://doi.org/10.1017/dce.2025.10016>
