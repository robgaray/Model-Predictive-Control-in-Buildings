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
#      Rscript, on 01_Input/example_first_call.json, and reads the
#      output JSON file.
#   3. Call in memory: it prepares the R session with
#      initialize_standalone() and calls optimize_market() directly,
#      first on a first market, then on a chained one. The plan
#      returned by the first market, a day-ahead market, becomes the
#      plan of a later market with the "O+F" aim, which keeps the
#      plan and only searches flexibility over it.
# -------------------------------------------------------------
# Inputs
#   01_Input/example_first_call.json
#   01_Input/example_chained_call.json: prices of the chained market
# -------------------------------------------------------------
# Outputs
#   90_Output/call_script_from_R_console_output.json: the output of
#   the call through the console.
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
# Where this function/script is used
#   - Run by hand, as an example.
# -------------------------------------------------------------
# functions/scripts called
#   - setup.R: run with Rscript, through system2()
#   - call_script_console.R: run with Rscript, through system2()
#   - initialize_standalone(): prepares the session
#   - optimize_market(): optimizes each market
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

  rm(source_files, script_argument)
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
  rm(setup_status)
}

# -------------------------------------------------------------
# 3. Call through the console
# -------------------------------------------------------------
# The same call any other language makes: input JSON file in, output
# JSON file out, exit status 0 on success and 1 on any error.
# -------------------------------------------------------------
{
  console_input  <- file.path(standalone_path, "01_Input", "example_first_call.json")
  console_output <- file.path(standalone_path, "90_Output",
                              "call_script_from_R_console_output.json")

  # call_script_console.R is run to optimize the market of the input
  # file and write the result to the output file.
  console_status <- system2(rscript,
                            shQuote(c(file.path(standalone_path, "call_script_console.R"),
                                      console_input,
                                      console_output)))
  if (console_status != 0) {
    stop("call_script_console.R failed. Read its messages above.")
  }

  console_result <- jsonlite::read_json(console_output, simplifyVector = TRUE)
  cat("Console call: ", length(console_result$operations$time),
      " committed intervals\n", sep = "")

  rm(console_input, console_output, console_status, console_result)
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
    file.path(standalone_path, "01_Input", "example_first_call.json"),
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
# from 06:00 to 18:00 and commits from 06:00 to 12:00. Its inputs are
# those of the first market over its own intervals, except the prices,
# read from 01_Input/example_chained_call.json, and the plan, which is
# the one the first market returned.
# -------------------------------------------------------------
{
  # The prices of the chained market are its own: they are read from
  # 01_Input/example_chained_call.json, which offers a downward
  # flexibility signal the first market did not have.
  chained_prices <- jsonlite::read_json(
    file.path(standalone_path, "01_Input", "example_chained_call.json"),
    simplifyVector = TRUE
  )$prices

  i0       <- as.POSIXct("2024-01-16 05:00:00", tz = "UTC")
  slot_sec <- 15 * 60
  slots    <- seq(i0, as.POSIXct("2024-01-16 18:00:00", tz = "UTC") - slot_sec, by = slot_sec)
  as_text  <- function(x) format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

  take <- function(block, columns) {
    rows <- match(as_text(slots), as_text(as.POSIXct(block$time, tz = "UTC",
                                                     format = "%Y-%m-%dT%H:%M:%SZ")))
    c(list(time = as_text(slots)), lapply(block[columns], function(v) v[rows]))
  }
  take_output <- function(block, columns) {
    rows <- match(as.numeric(slots), as.numeric(block$time))
    c(list(time = as_text(slots)), lapply(block[columns], function(v) v[rows]))
  }

  itinerary_columns <- c("Ti", "Te",
                         "STP_heat", "STP_heat_low", "STP_heat_high",
                         "STP_cool", "STP_cool_low", "STP_cool_high",
                         "Elec_total")

  chained_inputs <- list(
    market = list(aim             = "O+F",
                  i0              = as_text(i0),
                  i_begin_horizon = "2024-01-16T06:00:00Z",
                  i_end_control   = "2024-01-16T12:00:00Z",
                  i_end_horizon   = "2024-01-16T18:00:00Z",
                  T_ext_24h       = first_inputs$market$T_ext_24h,
                  Overall_Climate = first_inputs$market$Overall_Climate,
                  random_seed     = 2),
    context = take(first_inputs$context, c("Text", "SolarR", "Occupancy")),
    prices  = chained_prices,
    itineraries = list(
      plan           = take_output(first_result$itineraries$plan,
                                   c(itinerary_columns, "Elec_flex_down", "Elec_flex_up")),
      plan_flex_down = take_output(first_result$itineraries$plan_flex_down, itinerary_columns),
      plan_flex_up   = take_output(first_result$itineraries$plan_flex_up, itinerary_columns)
    )
  )

  # optimize_market is called again, now for the chained later
  # market, which keeps the plan and searches flexibility over it.
  chained_result <- optimize_market(chained_inputs, paths)

  cat("Chained market (", chained_inputs$market$aim, "):\n", sep = "")
  print(colSums(chained_result$operations[, -1]))

  saveRDS(list(first = first_result, chained = chained_result),
          file.path(standalone_path, "90_Output", "call_script_from_R_output.rds"))
}
