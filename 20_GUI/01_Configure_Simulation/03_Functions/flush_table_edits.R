# -------------------------------------------------------------
# Function: flush_table_edits.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Applies the last cell edit of each of the five editable tables
# (modes, the two occupancy tables, and the two market tables) to
# the reactive state, so a save never misses an edit the browser
# has not yet reported.
# -------------------------------------------------------------
# Inputs
#   rv               : The reactiveValues object holding the
#                      state of the app.
#   input            : The Shiny input object of the session.
# -------------------------------------------------------------
# Outputs
#   None; rv is updated in place.
# -------------------------------------------------------------
# Code outline
# 1. Apply the last edit of each table with
#    apply_text_table_edit().
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   flush_table_edits(rv, input)
# -------------------------------------------------------------
# Where this function/script is used
# GUI_config.R
# -------------------------------------------------------------
# functions/scripts called
# apply_text_table_edit()
# -------------------------------------------------------------

flush_table_edits <- function(rv, input) {
  rv$modes <- apply_text_table_edit(
    rv$modes,
    input$modes_cell_text_edit
  )
  rv$occupancy_type <- apply_text_table_edit(
    rv$occupancy_type,
    input$occupancy_type_cell_text_edit
  )
  rv$occupancy_month <- apply_text_table_edit(
    rv$occupancy_month,
    input$occupancy_month_cell_text_edit
  )
  rv$sched <- apply_text_table_edit(
    rv$sched,
    input$sched_cell_text_edit
  )
  rv$pilot <- apply_text_table_edit(
    rv$pilot,
    input$pilot_cell_text_edit
  )
}
