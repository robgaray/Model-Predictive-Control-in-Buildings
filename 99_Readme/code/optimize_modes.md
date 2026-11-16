# optimize_modes.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/optimize_modes.R`

## Function

This function optimizes the control modes over a particular period using a Genetic Algorithm (GA) approach with real-type genes that are constrained to integer values through custom population, crossover, and mutation operators. It performs the following steps:

1. Lays out the chromosome (chromosome_layout()): one block per asset with genes, one block after the other, each with one gene per market period of the target period, bounded by the number of options of the genes of its asset. It also sizes the elitism against the number of distinct chromosomes the space holds, because ga()'s own default can exceed it and inject an NA row into the population. It also adds to the table of the system the working columns every evaluation writes (piece_working_columns()), and lays out the view of each asset of the piece (piece_layout()), once, so that every evaluation of the genetic algorithm reuses it and adds no column.
2. Sends the data of this optimization to the worker cluster of the simulation, when parallel = 1.
3. Calls the GA optimizer with custom integer-handling operators to find the optimal control mode sequence that maximizes the reward function.
4. Post-processes the optimization results: the best chromosome is decoded into the control of each asset (decode_chromosome()).

When no asset of the registry has genes (for example a system of photovoltaic installations only), the chromosome is empty: there is nothing to search, the genetic algorithm is not called, and the function returns an empty control list.

## Called by

- [optimize_control_step.R](optimize_control_step.md)

## What it calls, in order of appearance

- [chromosome_layout.R](chromosome_layout.md)
- [piece_working_columns.R](piece_working_columns.md)
- [piece_layout.R](piece_layout.md)
- [fitness_funct_optimize_mode.R](fitness_funct_optimize_mode.md)
- [ga_population_int.R](ga_population_int.md)
- [ga_crossover_int.R](ga_crossover_int.md)
- [ga_mutation_int.R](ga_mutation_int.md)
- [decode_chromosome.R](decode_chromosome.md)

## Blocks

The piece calls 8 items, so it is documented in blocks:

- [Called items, block 1 of 2](optimize_modes__1.md)
- [Called items, block 2 of 2](optimize_modes__2.md)

## Input data

- piece          : List. The piece of the optimization horizon, as build_market_piece() gives it: the table of the system and the table of each asset. The table of the system holds a 'MarketUTC' column used to derive the set of target periods. Together the tables hold the columns required by period_calculation() (called inside evaluate_control()). Its working columns are added and it is laid out (piece_layout()) once, before the genetic algorithm.
- timestamps     : Named list. Timestamp metadata. Must contain: timestamps$target_periods : POSIXct vector of market period timestamps.
- parameters     : Named list. Model parameters passed through to period_calculation() and reward_function(). The following sub-elements are extracted internally: parameters$assets, the asset registry: each asset with genes takes a block of the chromosome (for a building, its setpoint_modes and its control$Deadband) parameters$optimization, as loaded from 01_Optimization_parameters.csv:
    - population_size
    - iteration_number
    - run_number
    - pcrossover
    - pmutation
    - parallel
- simulation_control : Named list. Index/step metadata (passed through for interface consistency).
- marginal_context : Named list or NULL. Passed through to the fitness function and, via clusterExport(), to worker processes.
- worker_cluster : Cluster of worker processes, as returned by start_worker_cluster(), when parallel = 1; NULL otherwise. It is used, not stopped.

## Output data

- controls : Named list, one element per asset with genes, named by its asset_id (an empty list when no asset has genes): the control of the asset for the best chromosome, as returned by the operation decode_genes of its type of model (for a Building, the setpoint columns with their hysteresis deadbands, from convert_modes_to_setpoints()).

## Other notes from the file header

### Code outline

1. Lay out the chromosome and the views of the piece

1a. Leave when the chromosome is empty 1b. Size the elitism against the search space

2. Configure genetic algorithm parameters with custom operators
3. Initialize parallelization
4. Run GA optimization with mode fitness function
5. Release the cluster reference
6. Post-process: decode the best chromosome into the control of each asset

### Usage instructions

```r
controls <- optimize_modes(piece, timestamps, parameters,
  simulation_control, marginal_context,
  worker_cluster)
```

### Exceptions and special cases

- With parallel = 1, the GA runs on worker_cluster, created once for the whole simulation by start_worker_cluster(). This function only sends it the data of this optimization, and does not stop it.
- ga() always receives a cluster, so that it always evaluates its population through doRNG's %dorng%, which draws one random number of the main process per generation. In series it is an empty object of class "cluster", with the sequential foreach backend registered. The result is then the same in series and in parallel, whatever the number of workers.
- Worker processes (PSOCK clusters) do not inherit the global environment: start_worker_cluster() exports every function of the simulator, and this function the data of this optimization by name, via clusterExport(). With parallel = 1 the fitness function is given the global environment as its own, so that the workers find both there.
- The GA uses real-type encoding with custom integer operators: one block of genes per asset with genes, each gene a whole number from 1 to the number of options of its asset (for a building, a mode index from 1 to its number of modes). The operators read the bounds of each gene separately, so blocks with different bounds need nothing of them.
- The custom operators read the selected parent chromosomes from the current GA population to keep the representation valid from the start.
- Only the first solution row of the GA result (ga_result@solution[1,]) is used if multiple equally-fit solutions exist.

## Diagram

![Block diagram of optimize_modes.R](optimize_modes.jpg)

Also available as [optimize_modes.svg](optimize_modes.svg).

---

[Back to the code structure index](../Code_Structure.md)
