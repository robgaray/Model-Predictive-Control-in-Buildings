# -------------------------------------------------------------
# Function: flush_table_edits.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Applies the last cell edit of each of the two editable tables of
# the system (the two market schedules) to the reactive state, so a
# save never misses an edit the browser has not yet reported. The
# tables of the assets are brought up to date by
# update_asset_from_inputs().
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
# 1. Apply the last edit of each table of the system with
#    apply_text_table_edit().
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   flush_table_edits(rv, input)
# -------------------------------------------------------------

flush_table_edits <- function(rv, input) {

  # -------------------------------------------------------------
  # 1. Apply the pending edits of the tables of the system
  # -------------------------------------------------------------
  {
    rv$sched <- apply_text_table_edit(
      rv$sched,
      input$sched_cell_text_edit
    )
    rv$pilot <- apply_text_table_edit(
      rv$pilot,
      input$pilot_cell_text_edit
    )
  }

  return(invisible(NULL))
}
