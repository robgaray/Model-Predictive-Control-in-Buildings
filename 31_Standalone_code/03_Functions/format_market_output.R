# -------------------------------------------------------------
# Function: format_market_output.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Turns the result of optimize_market() into plain named lists of
# vectors, ready to be written as JSON or handed to another language:
#   - every data frame becomes a named list of its columns
#   - every time becomes ISO 8601 UTC text (2024-01-15T12:00:00Z)
# The structure follows the input of the script: a system block and
# an assets block, each with its itineraries (plan, plan_flex_down and
# plan_flex_up), and an operations block.
# -------------------------------------------------------------
# Inputs
#   result : Named list, as returned by optimize_market().
# -------------------------------------------------------------
# Outputs
#   Named list:
#     - system     : list with itineraries, a list of plan,
#                    plan_flex_down and plan_flex_up, each a named
#                    list of vectors
#     - assets     : list with one entry per asset of the call, each
#                    with itineraries, as for the system
#     - operations : named list of vectors
# -------------------------------------------------------------
# Code outline
# 1. Conversion of one data frame
# 2. Conversion of the result
# -------------------------------------------------------------
# Usage instructions
# output <- format_market_output(optimize_market(inputs, paths))
# -------------------------------------------------------------

format_market_output <- function(result) {

  # -------------------------------------------------------------
  # 1. Conversion of one data frame
  # -------------------------------------------------------------
  {
    as_vector_list <- function(block) {
      block_list <- as.list(block)
      for (CONT_001 in names(block_list)) {
        if (inherits(block_list[[CONT_001]], "POSIXct")) {
          block_list[[CONT_001]] <- format(block_list[[CONT_001]],
                                           "%Y-%m-%dT%H:%M:%SZ",
                                           tz = "UTC")
        }
      }
      return(block_list)
    }
  }

  # -------------------------------------------------------------
  # 2. Conversion of the result
  # -------------------------------------------------------------
  {
    output <- list(
      system     = list(
        itineraries = lapply(result$system$itineraries, as_vector_list)
      ),
      assets     = lapply(result$assets, function(CONT_002) {
        list(itineraries = lapply(CONT_002$itineraries, as_vector_list))
      }),
      operations = as_vector_list(result$operations)
    )
  }

  rm(list = "as_vector_list")

  return(output)
}
