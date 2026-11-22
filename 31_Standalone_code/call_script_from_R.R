# -------------------------------------------------------------
# Script: call_script_from_R.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Example of how an R program uses the standalone market script.
# It shows the three steps a caller goes through:
#   1. Setup: it runs setup.R in a separate R process, which installs
#      the R packages and the C++ compiler the script needs. Only the
#      first time is it really needed; later runs find everything in
#      place and end quickly.
#   2. Call through the console: it runs call_script_console.R with
#      Rscript, on 01_Input/example_building_first_call.json (a
#      building) and on
#      01_Input/example_building_photovoltaic_first_call.json (a
#      building and a photovoltaic installation), and reads the
#      output JSON files.
#   3. Call in memory: it prepares the R session with
#      initialize_standalone() and calls optimize_market() directly,
#      first on a first market, then on a chained one. The plan
#      returned by the first market, a day-ahead market, becomes the
#      plan of a later market with the "O+F" aim, which keeps the
#      plan and only searches flexibility over it. The chained call
#      is built from the "system" block (net energy of the plan and
#      of its flexibility itineraries) and the "assets" block (the
#      itineraries of every asset) of the first output.
# -------------------------------------------------------------
# Inputs
#   01_Input/example_building_first_call.json
#   01_Input/example_building_photovoltaic_first_call.json
#   01_Input/example_building_chained_call.json: prices of the
#   chained market
# -------------------------------------------------------------
# Outputs
#   90_Output/call_script_from_R_console_output.json: the output of
#   the call through the console on the first example.
#   90_Output/call_script_from_R_console_pv_output.json: the output
#   of the call through the console on the building and photovoltaic
#   example.
#   90_Output/call_script_from_R_output.rds: the results of both
#   markets of the call in memory.
#   Printed summaries of every market.
# -------------------------------------------------------------
# Code outline
# 1. Paths
# 2. Setup
# 3. Call through the console
# 4. Call in memory
#    4.1. Session
#    4.2. First market
#    4.3. Chained market
# -------------------------------------------------------------
# Usage instructions
# From any folder:
#   Rscript 31_Standalone_code/call_script_from_R.R
# or source it from RStudio.
# -------------------------------------------------------------

# -------------------------------------------------------------
# 1. Paths
# -------------------------------------------------------------
# The folder of this script is found whether it is run with Rscript
# or sourced. Rscript is the one of the R installation running this
# script.
# -------------------------------------------------------------
{
  source_files    <- unlist(lapply(sys.frames(), function(frame) frame$ofile))
  script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(source_files) > 0) {
    standalone_path <- dirname(normalizePath(source_files[length(source_files)]))
  } else if (length(script_argument) > 0) {
    standalone_path <- dirname(normalizePath(sub("^--file=", "", script_argument[1])))
  } else {
    standalone_path <- normalizePath(getwd())
  }

  rscript <- file.path(R.home("bin"), "Rscript")

  rm(list = c("source_files", "script_argument"))
}

# -------------------------------------------------------------
# 2. Setup
# -------------------------------------------------------------
# setup.R ends with exit status 0 when every package is installed and
# a C++ file compiles, and with exit status 1 otherwise.
# -------------------------------------------------------------
{
  # setup.R is run to install the R packages and the C++ compiler the
  # script needs, if they are not there yet.
  setup_status <- system2(rscript, shQuote(file.path(standalone_path, "setup.R")))
  if (setup_status != 0) {
    stop("setup.R failed. Read its messages above.")
  }
  rm(list = "setup_status")
}

# -------------------------------------------------------------
# 3. Call through the console
# -------------------------------------------------------------
# The same call any other language makes: input JSON file in, output
# JSON file out, exit status 0 on success and 1 on any error.
# -------------------------------------------------------------
{
  console_inputs  <- c(
    file.path(standalone_path, "01_Input",
              "example_building_first_call.json"),
    file.path(standalone_path, "01_Input",
              "example_building_photovoltaic_first_call.json")
  )
  console_outputs <- c(file.path(standalone_path, "90_Output",
                                 "call_script_from_R_console_output.json"),
                       file.path(standalone_path, "90_Output",
                                 "call_script_from_R_console_pv_output.json"))

  for (CONT_001 in seq_along(console_inputs)) {
    {
      # call_script_console.R is run to optimize the market of the
      # input file and write the result to the output file.
      console_status <- system2(rscript,
                                shQuote(c(file.path(standalone_path, "call_script_console.R"),
                                          console_inputs[CONT_001],
                                          console_outputs[CONT_001])))
      if (console_status != 0) {
        stop("call_script_console.R failed. Read its messages above.")
      }

      console_result <- jsonlite::read_json(console_outputs[CONT_001], simplifyVector = TRUE)
      cat("Console call ", basename(console_inputs[CONT_001]), ": ",
          length(console_result$operations$time),
          " committed intervals, assets: ",
          paste(names(console_result$assets), collapse = ", "), "\n", sep = "")

      rm(list = c("console_status", "console_result"))
    }
  }

  rm(list = c("console_inputs", "console_outputs", "CONT_001"))
}

# -------------------------------------------------------------
# 4. Call in memory
# -------------------------------------------------------------
# Faster when many markets are run in a row: the libraries are loaded
# and the C++ module is compiled once per R session.
# -------------------------------------------------------------

# -------------------------------------------------------------
# 4.1. Session
# -------------------------------------------------------------
{
  # initialize_standalone is called to load the libraries, the
  # functions and the C++ module of the script.
  source(file.path(standalone_path, "03_Functions", "initialize_standalone.R"))
  paths <- initialize_standalone(standalone_path, NULL)
}

# -------------------------------------------------------------
# 4.2. First market
# -------------------------------------------------------------
{
  first_inputs <- jsonlite::read_json(
    file.path(standalone_path, "01_Input", "example_building_first_call.json"),
    simplifyVector = TRUE
  )

  # optimize_market is called to optimize the first market, a
  # day-ahead market that starts from scratch.
  first_result <- optimize_market(first_inputs, paths)

  cat("First market (", first_inputs$market$aim, "):\n", sep = "")
  print(colSums(first_result$operations[, -1]))
}

# -------------------------------------------------------------
# 4.3. Chained market
# -------------------------------------------------------------
# The second market is called at 05:00 of the committed day, optimizes
# from 06:00 to 18:00 and commits from 06:00 to 12:00. Its weather and
# building use are those of the first market over its own intervals.
# Its prices are its own. The system and the assets come from the
# output of the first market: the net energy of the system and the
# itineraries of every asset, cut to the intervals of the second
# market.
# -------------------------------------------------------------
{
  # The prices of the chained market are its own: they are read from
  # 01_Input/example_building_chained_call.json, which offers a
  # flexibility signal, downward and upward, that the first market
  # did not have.
  chained_prices <- jsonlite::read_json(
    file.path(standalone_path, "01_Input", "example_building_chained_call.json"),
    simplifyVector = TRUE
  )$prices

  i0       <- as.POSIXct("2024-01-16 05:00:00", tz = "UTC")
  slot_sec <- 15 * 60
  slots    <- seq(i0, as.POSIXct("2024-01-16 18:00:00", tz = "UTC") - slot_sec, by = slot_sec)
  as_text  <- function(x) format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

  # take cuts a block of the input of the first market to the
  # intervals of the chained market.
  take <- function(block, columns) {
    rows <- match(as_text(slots), as_text(as.POSIXct(block$time, tz = "UTC",
                                                     format = "%Y-%m-%dT%H:%M:%SZ")))
    c(list(time = as_text(slots)), lapply(block[columns], function(v) v[rows]))
  }

  # take_output cuts a block of the output of the first market to the
  # intervals of the chained market, with every column it holds.
  take_output <- function(block) {
    rows <- match(as.numeric(slots), as.numeric(block$time))
    columns <- setdiff(names(block), "time")
    c(list(time = as_text(slots)), lapply(block[columns], function(v) v[rows]))
  }

  take_itineraries <- function(itineraries) {
    lapply(itineraries, take_output)
  }

  # The asset blocks carry what each asset needs from the caller:
  # its itineraries from the first output and, for a building, its
  # use and its climate mode from the first input.
  chained_assets <- lapply(
    names(first_result$assets),
    function(asset_id) {
      asset <- list(itineraries = take_itineraries(first_result$assets[[asset_id]]$itineraries))
      first_asset <- first_inputs$assets[[asset_id]]
      if (!is.null(first_asset$Overall_Climate)) {
        asset$Overall_Climate <- first_asset$Overall_Climate
      }
      if (!is.null(first_asset$context)) {
        asset$context <- take(first_asset$context, setdiff(names(first_asset$context), "time"))
      }
      asset
    }
  )
  names(chained_assets) <- names(first_result$assets)

  chained_inputs <- list(
    market = list(aim             = "O+F",
                  i0              = as_text(i0),
                  i_begin_horizon = "2024-01-16T06:00:00Z",
                  i_end_control   = "2024-01-16T12:00:00Z",
                  i_end_horizon   = "2024-01-16T18:00:00Z",
                  T_ext_24h       = first_inputs$market$T_ext_24h,
                  random_seed     = 2),
    context = take(first_inputs$context, c("Text", "SolarR")),
    prices  = chained_prices,
    system  = list(itineraries = take_itineraries(first_result$system$itineraries)),
    assets  = chained_assets
  )

  # optimize_market is called again, now for the chained later
  # market, which keeps the plan and searches flexibility over it.
  chained_result <- optimize_market(chained_inputs, paths)

  cat("Chained market (", chained_inputs$market$aim, "):\n", sep = "")
  print(colSums(chained_result$operations[, -1]))

  saveRDS(list(first = first_result, chained = chained_result),
          file.path(standalone_path, "90_Output", "call_script_from_R_output.rds"))

  # close_standalone is called to stop the worker cluster of the
  # session, which both markets used when the optimizer runs in
  # parallel.
  close_standalone(paths)
}
