# -------------------------------------------------------------
# Function: photovoltaic_execute_step.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Runs a photovoltaic installation over a step of the simulation. It
# is the operation execute_step of the contract of the type
# Photovoltaic (see model_type_contract()). The installation holds no
# control, so the step is its production over the rows of the chunk,
# computed with the weather of the calculation context: the measured
# weather for "execution", and the forecast for "plan".
# It is the asset side of the step, like the one of any other type:
# it writes no money and no column of the system.
# -------------------------------------------------------------
# Inputs
#   period_chunk        : Data frame. The rows of the step, with time,
#                         the weather and the columns Elec_PV and
#                         Elec_total of the context.
#   simulation_control  : Named list. Not read.
#   timestamps          : Named list. Not read.
#   parameters          : Named list. Not read.
#   asset               : Named list. The parameters of the
#                         installation, its entry of
#                         parameters$assets.
#   calculation_context : Character. "execution" or "plan".
#   Every operation execute_step of the contract receives the same
#   arguments (see model_type_contract()).
# -------------------------------------------------------------
# Outputs
#   Data frame. period_chunk with the production of the step written.
# -------------------------------------------------------------
# Code outline
# 1. Compute the production of the step
# -------------------------------------------------------------
# Usage instructions
# period_chunk <- photovoltaic_execute_step(
#   period_chunk        = period_chunk,
#   simulation_control  = simulation_control,
#   timestamps          = timestamps,
#   parameters          = parameters,
#   asset               = asset,
#   calculation_context = "execution"
# )
# -------------------------------------------------------------

photovoltaic_execute_step <- function(period_chunk,
                                      simulation_control,
                                      timestamps,
                                      parameters,
                                      asset,
                                      calculation_context) {

  # -------------------------------------------------------------
  # 1. Compute the production of the step
  # -------------------------------------------------------------
  {
    # photovoltaic_generation is called to compute the production of
    # the installation over the rows of the step, with the weather
    # of the calculation context.
    period_chunk <- photovoltaic_generation(
      period_chunk        = period_chunk,
      asset               = asset,
      calculation_context = calculation_context
    )
  }

  return(period_chunk)
}
