# -------------------------------------------------------------
# Function: battery_execute_step.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Runs a battery over a step of the simulation. It is the operation
# execute_step of the contract of the type Battery (see
# model_type_contract()). The step is what the battery stores, takes
# and gives over the rows of the chunk, in the calculation context:
# "execution" for the step that the simulation really runs, with the
# mode of the plan and the net electricity that the rest of the
# system has had, and "plan" for the rows between the last executed
# one and the start of the optimization.
# It is the asset side of the step, like the one of any other type:
# it writes no money and no column of the system.
# -------------------------------------------------------------
# Inputs
#   period_chunk        : Data frame. The rows of the step, with the
#                         columns of the battery of the context.
#   simulation_control  : Named list. Not read.
#   timestamps          : Named list. Not read.
#   parameters          : Named list. Not read.
#   asset               : Named list. The parameters of the battery,
#                         its entry of parameters$assets.
#   calculation_context : Character. "execution" or "plan".
#   Every operation execute_step of the contract receives the same
#   arguments (see model_type_contract()).
# -------------------------------------------------------------
# Outputs
#   Data frame. period_chunk with the step of the battery written.
# -------------------------------------------------------------
# Code outline
# 1. Run the step of the battery
# -------------------------------------------------------------
# Usage instructions
# period_chunk <- battery_execute_step(
#   period_chunk        = period_chunk,
#   simulation_control  = simulation_control,
#   timestamps          = timestamps,
#   parameters          = parameters,
#   asset               = asset,
#   calculation_context = "execution"
# )
# -------------------------------------------------------------

battery_execute_step <- function(period_chunk,
                                 simulation_control,
                                 timestamps,
                                 parameters,
                                 asset,
                                 calculation_context) {

  # -------------------------------------------------------------
  # 1. Run the step of the battery
  # -------------------------------------------------------------
  {
    # battery_simulate_itinerary is called to compute what the
    # battery stores, takes and gives over the rows of the step, in
    # the calculation context.
    period_chunk <- battery_simulate_itinerary(
      period_chunk        = period_chunk,
      asset               = asset,
      calculation_context = calculation_context
    )
  }

  return(period_chunk)
}
