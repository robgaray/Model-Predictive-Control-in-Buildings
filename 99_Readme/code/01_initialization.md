# 01_initialization.R

**Script** &nbsp;·&nbsp; `30_Simulation/04_Scripts/01_initialization.R`

## Function

This script performs the initialization phase of the MPC simulation. It is sourced from Main.R and performs the following steps:

1. Cleans and resets the environment
2. Sets global configuration options
3. Initialises file directory paths
4. Validates required files and directories
5. Loads libraries and functions
6. Compiles the C++ simulation module

## Called by

- [Main.R](Main.md)

## What it calls, in order of appearance

- [initialization.R](initialization.md) &nbsp;(2 call sites)

## Input data

- (none) - this script initializes the environment from scratch.

## Output data

- paths : List. Paths to all required data/config files used by Main.R and sourced scripts (e.g., paths$control_file, paths$output_path).
- (functions_path is created and used internally to source 03_Functions/*.R via initialization(), then rm()'d before this script ends - it does not persist in the environment.)
- period_simulation_cpp() : Function. Exposed by Rcpp::sourceCpp() from 30_Simulation/03_1_Functions_Cpp/period_simulation_cpp.cpp.

## Other notes from the file header

### Code outline

1. Clean environment
2. Set global configuration
3. Initialize file paths
4. Validate required files and directories
5. Load libraries and functions
6. Compile the C++ simulation module

### Usage instructions

```r
source(file.path("30_Simulation", "04_Scripts", "01_initialization.R"))
```

Not called: sourced by Main.R as its first step. It resolves the paths, loads the libraries and sources the functions.

## Diagram

![Block diagram of 01_initialization.R](01_initialization.jpg)

Also available as [01_initialization.svg](01_initialization.svg).

---

[Back to the code structure index](../Code_Structure.md)
