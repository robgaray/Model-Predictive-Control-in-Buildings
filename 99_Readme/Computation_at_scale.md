---
editor_options: 
  markdown: 
    wrap: 72
---

# Computation at Scale

## Introduction

This is a computational code that may require very long execution times.
A full-year Model Predictive Control simulation involves running a
genetic algorithm optimization for every control period (e.g., every 24
simulated hours), with each optimization taking several minutes. As a
result, running a single simulation on a personal computer can take
anywhere from one hour to several days, depending on the hyperparameter
selection.

Additionally, parametric simulations are often required to explore the
parameter space and understand the behavior of the model under different
conditions — for instance, tuning the population size, number of
iterations, optimization horizon, or comparing different control
strategies. In these cases, hundreds or thousands of simulations need to
be executed, making the use of high-performance computing resources
essential.

For these reasons, it is necessary to use supercomputers to run the
simulations in a reasonable time frame. This section describes how to
run the simulations at scale using the [DIPC SCC
supercomputer](https://dipc.ehu.eus/en/supercomputing-center), and how
to manage the jobs and tasks in this environment.

## Adaptations for Running in a Supercomputer

Some adaptations have been made to the code to allow it to run in a
supercomputer environment, such as the DIPC SCC. These adaptations are
described in the following subsections.

### File Management

Supercomputers typically have multiple storage filesystems with
different performance characteristics. User home directories may reside
on network-attached storage, while compute nodes have access to fast
local scratch filesystems optimized for I/O-intensive workloads.

In the DIPC SCC, user home directories are located at
`/dipc/<USERNAME>`. The code in this repository manages file transfers
by syncing the project directory from `/dipc/<USERNAME>/<JOB_NAME>` to
the fast scratch filesystem at `/scratch/<USERNAME>/<JOB_NAME>` using
`rsync -a --delete` before execution. All simulation work runs from
`/scratch` to maximize I/O performance. Subsequent runs only transfer
changed files, making the sync process efficient.

### Library Management

Supercomputers commonly have pre-installed, standardized versions of
software environments. Specific R libraries beyond the base installation
need to be installed for this code to run. However, users commonly do
not have administrative rights to install libraries system-wide, which
means that libraries must be installed to a local directory as part of
the code deployment process. This can be quite a time-consuming process,
particularly the first time the code is deployed.

Additionally, if several instances of the same code (e.g., for a
parametric study) are run simultaneously, there may be conflicts when
multiple instances try to install libraries at the same time,
potentially corrupting the library directory or producing errors such as
"package installation lock" failures.

For all the above reasons, the code is split into two scripts:

1.  **`02_SCC_simulation/Install_libraries.R`**: Handles the management
    and installation of R libraries. This script is executed once,
    before any simulation instances are launched. It reads the required
    package list from `01_Simulation/02_Config/libraries.txt`, checks
    which packages are already installed in the local `00_Libraries`
    directory, and only installs those that are missing. This approach
    avoids redundant re-installation on every run.

2.  **`02_SCC_simulation/Main_SCC.R`**: The actual simulation script,
    which is executed as individual tasks within Slurm job arrays.

### Job Management

The DIPC SCC uses the [SLURM](https://slurm.schedmd.com/) workload
manager for job scheduling. In SLURM, users submit jobs to a queue, and
the scheduler allocates compute resources based on the requested
partition, Quality of Service (QoS), and available capacity.

There are commonly limits to the number of jobs (or job array tasks)
that can be submitted to the cluster at the same time. This can be a
problem when running a large number of simulations, as exceeding the
queue limit would require manual intervention to submit additional jobs
after earlier ones complete.

The code in this repository addresses this challenge through the
following mechanisms:

-   **Tasks per job grouping**: Users can define how many simulation
    configurations (tasks) are assigned to each Slurm job array. The
    code automatically groups the configurations from
    `02_SCC_simulation/Optim_parameters.csv` into jobs based on this
    definition. For example, if there are 500 configurations and
    `TASKS_PER_JOB` is set to 100, the code will create 5 jobs.

-   **Job submission**: The `02_SCC_simulation/Console_code.txt` script
    handles the submission of all jobs. It accepts an optional
    positional argument to select a single job:\
    `bash     bash "02_SCC_simulation/Console_code.txt"        # submit ALL jobs     bash "02_SCC_simulation/Console_code.txt" 2      # submit only the 2nd job`

-   **Automatic job persistence**: A `job_tracker.csv` file is created
    in `02_SCC_simulation/` at launch time. It tracks the status of
    every job (pending, launched, completed, failed). When a Slurm job
    array finishes its last task, the job script (`Job_array_r.sh`)
    automatically checks the tracker and submits the next pending job.
    This ensures that all jobs complete without the need for human
    intervention, even if the number of jobs exceeds the cluster queue
    limit.

### Instructions for Running Simulations on the DIPC SCC

> **Note**: The instructions below are specific to the DIPC SCC
> environment and the author's approach to managing jobs. They may need
> to be adapted for other supercomputing environments or job management
> systems.

1.  **Copy the project to the supercomputer**: Transfer the full
    repository to the DIPC SCC, typically using SFTP. Place it under
    your home directory, e.g., `/dipc/<USERNAME>/<JOB_NAME>/`.

2.  **Navigate to the project directory**:
    `bash     cd /dipc/<USERNAME>/<JOB_NAME>`

3.  **Execute the simulation script**:
    `bash     bash "02_SCC_simulation/Console_code.txt"` This script
    will:

    -   Sync the project to the fast scratch filesystem.
    -   Load the R module.
    -   Install any missing R libraries.
    -   Initialize the job tracker.
    -   Submit all jobs to the Slurm queue.

### Instructions for Managing Jobs and Tasks

> **Note**: The instructions below are specific to the DIPC SCC
> environment and the author's approach to managing jobs. They may need
> to be adapted for other supercomputing environments or job management
> systems.

-   **Define tasks per job**: Set the `TASKS_PER_JOB` variable through
    the GUI
    (`40_GUI/02_Configure_Parametric_Simulations/GUI_parametric.R`) or
    directly in `02_SCC_simulation/scc_settings.sh`. A typical value is
    100–500 tasks per job, depending on the cluster's array size limits.

-   **Submit specific jobs**: Use the positional argument to submit only
    a particular job:\
    `bash     bash "02_SCC_simulation/Console_code.txt" 2   # submit only the 2nd job`

-   **Monitor job execution**: Use the standard Slurm commands to
    monitor: `bash     squeue -u <USERNAME>`

-   **Check the job tracker**: The `02_SCC_simulation/job_tracker.csv`
    file records the status of each job (pending, launched, completed,
    failed). Review this file to confirm that all jobs have completed
    successfully.

-   **Review logs**: Job output and error logs are stored in the `logs/`
    directory with the naming pattern
    `<JOB_NAME>_<JOB_ID>_<TASK_ID>.out` and `.err`.

### Verifying Simulation Results

Once all Slurm jobs have completed, use the verification script to
confirm that all simulation outputs were produced correctly:

``` bash
cd /scratch/<USERNAME>/<JOB_NAME>
bash "02_SCC_simulation/Verification_code.txt"
```

The verification script performs the following checks for every
configuration in `02_SCC_simulation/Optim_parameters.csv`:

1.  **File existence**: Confirms that the expected output files
    (Sinthetized_df_computed and/or Main_df_computed, in CSV and/or RDS
    format as configured in `scc_settings.sh`) are present in
    `01_Simulation/90_Output/`.

2.  **Content validation**: Opens each output file with R and verifies:

    -   The file contains a valid data.frame with at least one row.
    -   All expected columns are present.
    -   Key result columns (`Elec_total`, `Elec_Cost`, `Comfort`,
        `reward`, `process_time`) are numeric.
    -   No NaN or NA values exist in numeric columns.

3.  **Automatic backup**: Before modifying anything, the script creates
    a timestamped backup of `Optim_parameters.csv` as
    `Optim_parameters_backup_<YYYYMMDD_HHMMSS>.csv`.

4.  **Update for re-execution**: After verification,
    `Optim_parameters.csv` is updated to contain only the configurations
    that failed verification. This means the user can simply re-run
    `Console_code.txt` to re-execute only the failed simulations. If all
    configurations pass, `Optim_parameters.csv` remains unchanged.

### Extracting Results to Persistent Storage

After verification, copy the simulation results from the fast scratch
filesystem back to the persistent DIPC home directory:

``` bash
bash "02_SCC_simulation/Extraction_code.txt"
```

This script:

-   Works regardless of the user's current working directory (it
    resolves the project root from the script's own location).
-   Reads `scc_settings.sh` to determine `JOB_NAME` and `SCC_USERNAME`.
-   Copies logs (`logs/`), simulation outputs
    (`01_Simulation/90_Output/`), the job tracker
    (`02_SCC_simulation/job_tracker.csv`), and any verification backup
    files from `/scratch/<USERNAME>/<JOB_NAME>` to
    `/dipc/<USERNAME>/<JOB_NAME>`.

The `Extraction_code.txt` script is automatically generated by the
parametric simulation GUI alongside `Optim_parameters.csv` and
`scc_settings.sh`.

## Adapted Code and Configuration Files

The adapted code for supercomputer execution is located under
`02_SCC_simulation/`, and includes:

-   `Console_code.txt` — The main console script to submit jobs.
-   `Verification_code.txt` — Verification script for simulation results
    (run after all jobs complete).
-   `Extraction_code.txt` — Extraction script to copy results from
    `/scratch` to `/dipc` (generated by the GUI).
-   `Job_array_r.sh` — The Slurm job array script.
-   `Main_SCC.R` — The adapted R simulation script for SCC execution.
-   `Install_libraries.R` — Library installation script.
-   `scc_settings.sh` — Cluster settings (partition, QoS, job name,
    etc.).
-   `Optim_parameters.csv` — The parametric simulation configuration
    file.

This code is designed to be flexible and adaptable to different
supercomputing environments. Users may need to make adjustments to run
it in their specific environment, such as modifying the partition name,
QoS, module loading commands, or file paths.

## Graphic User Interface for Supercomputer Simulations

A Shiny-based Graphic User Interface is provided in
`40_GUI/02_Configure_Parametric_Simulations/GUI_parametric.R` to define
the parametric simulations for the supercomputer. This GUI is
particularly useful for users who are not familiar with supercomputers,
as it provides an intuitive and user-friendly way to define the
simulations and generate the necessary files for running them in the
supercomputer environment.

### Features

The GUI allows users to:

-   **Define parameter ranges**: For each numeric parameter (population
    size, iteration number, optimization horizon, etc.), set minimum,
    maximum, and step values to define the range of values to explore.

-   **Select categorical options**: Choose control types
    (modes/setpoint), optimization aims (energy/flexibility), and month
    subsets through checkboxes.

-   **Configure sampling strategies**:

    -   **Full Factorial**: Generate all possible combinations of
        parameter values. Can also append new combinations to an
        existing configuration file.
    -   **Latin Hypercube Sampling (LHS)**: Generate a space-filling
        design with a specified number of samples for more efficient
        exploration of the parameter space.

-   **Configure SLURM settings**: Set the job name, Slurm partition,
    Quality of Service, user email for notifications, cluster username,
    tasks per job, and output file formats.

-   **Generate configuration files**: Click "Generate Configuration
    File" to write:

    -   `02_SCC_simulation/Optim_parameters.csv` — The parametric
        configuration matrix.
    -   `02_SCC_simulation/scc_settings.sh` — The cluster settings file.
    -   `02_SCC_simulation/Extraction_code.txt` — The extraction script
        to copy results from `/scratch` to `/dipc`.

### How to Launch the GUI

From the repository root directory, run:

``` r
shiny::runApp("40_GUI/02_Configure_Parametric_Simulations")
```

Alternatively, open
`40_GUI/02_Configure_Parametric_Simulations/GUI_parametric.R` in RStudio
and click the "Run App" button.

### Screenshot

```{=html}
<!-- TODO: Insert a screenshot of the Parametric Simulation GUI here.
     To generate the screenshot:
     1. Launch the GUI with shiny::runApp("40_GUI/02_Configure_Parametric_Simulations")
     2. Take a screenshot of the application window
     3. Save the screenshot as 99_Readme/GUI_parametric_screenshot.png
     4. Replace this comment block with:
        ![Parametric Simulation GUI](GUI_parametric_screenshot.png)
-->
```

*A screenshot of the Parametric Simulation GUI should be placed here.
See the instructions above to generate it.*

## Execution Process in the Supercomputer

The overall process for running parametric simulations in a
supercomputer is as follows:

1.  **Configure simulations locally**: Use the GUI
    (`40_GUI/02_Configure_Parametric_Simulations/GUI_parametric.R`) on
    your local machine to define the parameter ranges, sampling
    strategy, and SLURM settings. Generate the configuration files.

2.  **Transfer the repository to the supercomputer**: Migrate the full
    repository to the supercomputer, commonly through SFTP file
    transfer.

3.  **Connect to the supercomputer**: Log in via SSH:
    `bash     ssh <USERNAME>@<SCC_HOST>`

4.  **Navigate to the project directory**:
    `bash     cd /dipc/<USERNAME>/<JOB_NAME>`

5.  **Execute the console code**:
    `bash     bash "02_SCC_simulation/Console_code.txt"`

6.  **Monitor execution**: Use `squeue -u <USERNAME>` and check
    `02_SCC_simulation/job_tracker.csv` to monitor progress.

7.  **Verify results**: Once all jobs have completed, run the
    verification script:
    `bash     bash "02_SCC_simulation/Verification_code.txt"` If any
    configurations failed, re-run `Console_code.txt` to re-execute only
    the failed ones. Repeat until all configurations pass.

8.  **Extract results to persistent storage**: Copy the simulation
    results from scratch to the DIPC home directory:
    `bash     bash "02_SCC_simulation/Extraction_code.txt"`

## Acknowledgements

The author acknowledges the technical and human support provided by the
[DIPC Supercomputing
Center](https://dipc.ehu.eus/en/supercomputing-center) for supporting
this research with access to their supercomputing resources, and for
providing the necessary infrastructure and support to run the
simulations at scale.

------------------------------------------------------------------------

[Back to README](../README.md)
