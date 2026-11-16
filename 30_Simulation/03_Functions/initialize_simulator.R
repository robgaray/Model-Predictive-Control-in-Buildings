# -------------------------------------------------------------
# Function: initialize_simulator.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads the simulator into an environment of its own, sim, and
# returns it. sim holds:
#   - every function of 30_Simulation/03_Functions/ and of the
#     03_Functions/ folder of every type of model of
#     30_Simulation/05_Models/
#   - the compiled C++ modules of the types of model
#   - paths, the list of every file the simulation reads or writes
# Nothing is created in, or removed from, the global environment,
# so the simulator can be loaded into an R session that already
# holds other objects, and loaded again, without losing them.
# -------------------------------------------------------------
# The environment of the simulator
# The functions are defined in sim, so they call each other inside
# it. The parent of sim is the global environment, so they also see
# the attached packages. Configuration and data are not loaded here:
# they are read later, by run_simulation().
# -------------------------------------------------------------
# Inputs
#   simulation_path : Character. Path of the 30_Simulation/ folder
#                     to load, with the folders:
#                       - 01_Data
#                       - 02_Config
#                       - 03_Functions
#                       - 05_Models, with one folder per type of
#                         model (for example 01_Building), each with
#                         its 03_Functions and 03_1_Functions_Cpp
# -------------------------------------------------------------
# Outputs
#   Environment (sim), whose parent is the global environment. It
#   holds:
#     - every function of 03_Functions/ and of the 03_Functions/
#       folder of every type of model
#     - period_simulation_cpp(), heat_pump_cop_cpp(),
#       heat_pump_electricity_cpp() and
#       apply_commitment_margin_cpp(): exposed by
#       Rcpp::sourceCpp() from period_simulation_cpp.cpp, in
#       05_Models/01_Building/03_1_Functions_Cpp/, and the headers
#       it includes
#     - battery_trajectory_cpp(), battery_free_trajectory_cpp(),
#       battery_recovery_correction_cpp() and
#       battery_factor_search_cpp(): exposed by
#       Rcpp::sourceCpp() from battery_trajectory_cpp.cpp, in
#       05_Models/03_Battery/03_1_Functions_Cpp/, and the headers it
#       includes
#     - paths : List. One path per system key of 04_File_paths.csv,
#               plus:
#         - config_path        : the configuration folder, 02_Config
#         - output_path        : the output folder, 90_Output
#         - meteo_file         : 01_Data/Meteo_df.rds
#         - energy_prices_file : 01_Data/Energy_Prices_df.rds
#         - cpp_source_path    : Character vector. The C++ modules
#                                of the types of model, one .cpp
#                                file each, normalized
#   Two LOAD lines are written to the console when all goes well:
#   the libraries and functions loaded, and the C++ modules
#   compiled.
# -------------------------------------------------------------
# Code outline
# 1. Global configuration
# 2. Build the paths
# 3. Validate the folders and the files
# 4. Load the libraries and the functions into sim
# 5. Compile the C++ modules into sim
# 6. Keep the paths in sim
# -------------------------------------------------------------
# Usage instructions
# source(file.path("30_Simulation", "03_Functions",
#                  "initialize_simulator.R"))
# sim <- initialize_simulator(
#   simulation_path = file.path(getwd(), "30_Simulation")
# )
# sim$paths$reward_file
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - The data files (Meteo_df.rds and Energy_Prices_df.rds) are
#     not required here: they are checked when they are read, so
#     the simulator can be loaded without any input series.
#   - The libraries are attached to the search path of the R
#     session, because the functions call them by name.
# -------------------------------------------------------------

initialize_simulator <- function(simulation_path) {

  # -------------------------------------------------------------
  # 1. Global configuration
  # -------------------------------------------------------------
  {
    options(stringsAsFactors = FALSE)
  }

  # -------------------------------------------------------------
  # 2. Build the paths
  # The configuration files are named in
  # 00_Inner_parameters/04_File_paths.csv, the one list of file
  # names the simulation, the GUI and the verification battery
  # share. The data files, the output folder and the code of the
  # types of model are not configuration and are named here. Each
  # type of model has a folder in 05_Models/ with its functions
  # and its C++ module, found here, so that a new type needs no
  # change in this function.
  # -------------------------------------------------------------
  {
    data_path      <- file.path(simulation_path, "01_Data")
    config_path    <- file.path(simulation_path, "02_Config")
    functions_path <- file.path(simulation_path, "03_Functions")
    models_path    <- file.path(simulation_path, "05_Models")

    paths <- list(
      output_path        = file.path(simulation_path, "90_Output"),
      meteo_file         = file.path(data_path, "Meteo_df.rds"),
      energy_prices_file = file.path(data_path, "Energy_Prices_df.rds")
    )

    # build_config_paths.R and read_file_paths_table.R are sourced
    # into this function's own environment, so that the functions are
    # available to call before sim holds any function.
    source(file.path(functions_path, "read_file_paths_table.R"),
           local = environment())
    source(file.path(functions_path, "build_config_paths.R"),
           local = environment())
    # build_config_paths is called to read the file names of
    # 04_File_paths.csv and join each to the configuration folder.
    config_paths <- build_config_paths(config_path = config_path)
    paths        <- c(paths, config_paths)

    model_paths <- sort(list.dirs(
      models_path,
      full.names = TRUE,
      recursive  = FALSE
    ))
    function_paths <- c(
      functions_path,
      file.path(model_paths, "03_Functions")
    )
    paths$cpp_source_path <- list.files(
      file.path(model_paths, "03_1_Functions_Cpp"),
      pattern    = "\\.cpp$",
      full.names = TRUE
    )

    rm(list = c("read_file_paths_table", "build_config_paths", "config_paths",
                "model_paths"))
  }

  # -------------------------------------------------------------
  # 3. Validate the folders and the files
  # Every file must exist, except the output folder, which the
  # export creates, and the data files, which are checked when they
  # are read.
  # -------------------------------------------------------------
  {
    required_paths <- c(data_path, config_path, models_path,
                        function_paths)
    missing_paths  <- required_paths[!dir.exists(required_paths)]

    if (length(missing_paths) > 0) {
      stop("Missing required directories:\n",
           paste(missing_paths, collapse = "\n"))
    }

    not_required   <- c("output_path", "meteo_file", "energy_prices_file")
    required_files <- unlist(paths[!names(paths) %in% not_required],
                             use.names = FALSE)
    missing_files  <- required_files[!file.exists(required_files)]

    if (length(missing_files) > 0) {
      stop("Missing required files:\n", paste(missing_files, collapse = "\n"))
    }

    if (length(paths$cpp_source_path) == 0) {
      stop("No C++ module found in the types of model of ", models_path)
    }
    paths$cpp_source_path <- normalizePath(paths$cpp_source_path,
                                           mustWork = TRUE)

    rm(list = c("required_paths", "missing_paths", "not_required",
                "required_files", "missing_files", "data_path", "config_path",
                "models_path"))
  }

  # -------------------------------------------------------------
  # 4. Load the libraries and the functions into sim
  # -------------------------------------------------------------
  {
    sim <- new.env(parent = globalenv())

    # initialization.R is sourced into this function's own
    # environment, so that initialization() is available to call
    # before sim holds any function.
    source(file.path(functions_path, "initialization.R"), local = environment())
    # initialization() is called to load the libraries listed in
    # paths$library_file and to source every function file of
    # function_paths into sim.
    initialization(
      library_file   = paths$library_file,
      function_paths = function_paths,
      envir          = sim
    )

    rm(list = c("initialization", "functions_path", "function_paths"))
  }

  # -------------------------------------------------------------
  # 5. Compile the C++ modules into sim
  # -------------------------------------------------------------
  {
    for (CONT_001 in seq_along(paths$cpp_source_path)) {
      # Rcpp::sourceCpp compiles and loads one C++ module, with the
      # headers it includes, so that its functions are callable as R
      # functions of sim. For the building, period_simulation_cpp.cpp
      # gives period_simulation_cpp() and the electrical model of
      # the heat pump. For the battery, battery_trajectory_cpp.cpp
      # gives the physics of its stored energy.
      Rcpp::sourceCpp(paths$cpp_source_path[CONT_001], env = sim)
    }
    rm(list = "CONT_001")

    # console_message, the one defined in sim, is called to write the
    # only line of this function: the number of C++ modules compiled.
    console_message <- sim$console_message
    console_message(
      label = "LOAD",
      text  = paste0("C++ modules: ", length(paths$cpp_source_path),
                     " compiled")
    )
    rm(list = "console_message")
  }

  # -------------------------------------------------------------
  # 6. Keep the paths in sim
  # -------------------------------------------------------------
  {
    sim$paths <- paths
    rm(list = "paths")
  }

  return(sim)
}
