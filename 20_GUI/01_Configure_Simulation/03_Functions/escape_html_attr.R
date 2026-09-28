# -------------------------------------------------------------
# Function: escape_html_attr.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Escapes a value so it can be placed inside an HTML attribute:
# &, ", < and >.
# -------------------------------------------------------------
# Inputs
#   value            : The value to check or escape.
# -------------------------------------------------------------
# Outputs
#   Character vector: the escaped values.
# -------------------------------------------------------------
# Code outline
# 1. Replace the four characters by their entities.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   escape_html_attr(value)
# -------------------------------------------------------------
# Where this function/script is used
# build_table_cell_inputs()
# -------------------------------------------------------------
# functions/scripts called
# None of this app; base R and shiny only.
# -------------------------------------------------------------

escape_html_attr <- function(value) {
  value <- as.character(value)
  value <- gsub("&", "&amp;", value, fixed = TRUE)
  value <- gsub("\"", "&quot;", value, fixed = TRUE)
  value <- gsub("<", "&lt;", value, fixed = TRUE)
  value <- gsub(">", "&gt;", value, fixed = TRUE)
  value
}
