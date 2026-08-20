# -------------------------------------------------------------
# Function: initialize_plan_flex_columns.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function initializes the *_plan_flex baseline columns from
# the corresponding *_plan columns in a period_chunk data frame.
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame. Must contain *_plan columns that
#                  represent the baseline planning simulation.
# -------------------------------------------------------------
# Outputs
#   period_chunk : Data frame. Input data frame with matching
#                  *_plan_flex columns initialized from *_plan.
# -------------------------------------------------------------
# Code outline
# 1. Find *_plan columns
# 2. Copy each *_plan column to *_plan_flex
# 3. Return updated period_chunk
# -------------------------------------------------------------
# Usage instructions
# period_chunk <- initialize_plan_flex_columns(period_chunk)
# -------------------------------------------------------------
# Where this function/script is used
# Called by evaluate_control.R after period_calculation(..., "plan").
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------
initialize_plan_flex_columns <- function(period_chunk) {

  plan_cols <- grep("_plan$", names(period_chunk), value = TRUE)
  for (CONT_001 in plan_cols) {
    period_chunk[[paste0(CONT_001, "_flex")]] <- period_chunk[[CONT_001]]
  }
  rm(plan_cols, CONT_001)

  return(period_chunk)
}
