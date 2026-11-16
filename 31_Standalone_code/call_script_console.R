# -------------------------------------------------------------
# Script: call_script_console.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Command line entry point of the standalone market script. It reads
# the inputs of one market from a JSON file, optimizes the energy and
# flexibility commitments of the system of assets of the call for
# that market with optimize_market(), and writes the result to another
# JSON file.
# Any tool able to run a command and read and write JSON can use it,
# whatever its language.
# If anything fails, the error is printed on the console, no output
# file is written, and the script ends with exit status 1.
# -------------------------------------------------------------
# Inputs
#   Command line arguments:
#     1. Path of the input JSON file.
#     2. Path of the output JSON file.
#     3. Optional: configuration folder to use instead of 02_Config.
#   The structure of both files, variable by variable, is described
#   in the README of this folder.
# -------------------------------------------------------------
# Outputs
#   The output JSON file, with the blocks system, assets and
#   operations.
# -------------------------------------------------------------
# Code outline
# 1. Arguments and folder of the script
# 2. Initialization
# 3. Input, optimization and output
# -------------------------------------------------------------
# Usage instructions
#   Rscript 31_Standalone_code/call_script_console.R input.json output.json
#   Rscript 31_Standalone_code/call_script_console.R input.json output.json
#   my_config
# It can be run from any folder: the script finds its own folder.
# The R packages must be installed first, once, with setup.R.
# -------------------------------------------------------------

# -------------------------------------------------------------
# 1. Arguments and folder of the script
# -------------------------------------------------------------
{
  arguments <- commandArgs(trailingOnly = TRUE)
  if (length(arguments) < 2 || length(arguments) > 3) {
    cat("Usage: Rscript call_script_console.R input.json output.json [config_folder]\n")
    quit(status = 1)
  }

  input_file  <- arguments[1]
  output_file <- arguments[2]
  config_path <- if (length(arguments) == 3) arguments[3] else NULL

  script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  standalone_path <- dirname(normalizePath(sub("^--file=", "", script_argument[1])))

  rm(list = c("arguments", "script_argument"))
}

# -------------------------------------------------------------
# 2. Initialization
# -------------------------------------------------------------
{
  # initialize_standalone is called to load the libraries, the
  # functions and the C++ module of the script.
  source(file.path(standalone_path, "03_Functions", "initialize_standalone.R"))
  paths <- tryCatch(
    initialize_standalone(standalone_path, config_path),
    error = function(e) {
      cat("ERROR:", conditionMessage(e), "\n")
      quit(status = 1)
    }
  )
}

# -------------------------------------------------------------
# 3. Input, optimization and output
# -------------------------------------------------------------
# The JSON file is read with simplifyVector, so that every array
# becomes an R vector and every null a missing value.
# -------------------------------------------------------------
{
  tryCatch(
    {
      inputs <- jsonlite::read_json(input_file, simplifyVector = TRUE)

      # optimize_market is called to optimize the commitments of the
      # system of assets for the market described in the input file.
      result <- optimize_market(inputs, paths)

      # format_market_output is called to turn the result into plain
      # vectors with times as ISO 8601 text.
      jsonlite::write_json(format_market_output(result),
                           output_file,
                           auto_unbox = FALSE,
                           digits     = NA,
                           na         = "null",
                           pretty     = TRUE)
      cat("Output written to", output_file, "\n")

      # close_standalone is called to stop the worker cluster of
      # the session, when the optimizer ran in parallel.
      close_standalone(paths)
    },
    error = function(e) {
      cat("ERROR:", conditionMessage(e), "\n")
      quit(status = 1)
    }
  )
}
