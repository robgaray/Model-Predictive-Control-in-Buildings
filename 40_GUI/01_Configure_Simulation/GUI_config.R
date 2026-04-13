# -------------------------------------------------------------
# Script: GUI_config.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Location: 40_GUI/01_Configure_Simulation/GUI_config.R
# -------------------------------------------------------------
# This script launches a Shiny GUI to edit all configuration
# CSV files required by Main.R, without manually editing CSVs.
# Run this script before Main.R to set up all parameters.
# -------------------------------------------------------------
# Configuration files covered:
#   - model_parameters.csv       (building physics & HVAC)
#   - control_parameters.csv     (control type & flexibility)
#   - optimization_parameters.csv (GA & MPC horizon)
#   - forecast_parameters.csv    (forecast type & model)
#   - reward_parameters.csv      (comfort penalty weight)
#   - setpoint_modes.csv         (modes table: mode/heating/cooling)
#   - debug_and_config.csv       (debug/run flags & price emulation)
#   - flex_price_simulation.csv  (flexibility price simulation parameters)
# -------------------------------------------------------------

library(shiny)
library(shinyjs)
library(rhandsontable)

# -------------------------------------------------------------
# Path resolution
# Shiny sets getwd() to the app directory at launch.
# The app lives at 40_GUI/01_Configure_Simulation/ so the
# repo root is two levels up.
# -------------------------------------------------------------
{
  # --- Detect the directory where THIS script lives ----------
  # Works both when source()'d and when run as a Shiny app.
  .script_dir <- tryCatch(
    dirname(normalizePath(sys.frame(1)$ofile)),
    error = function(e) NULL
  )

  if (!is.null(.script_dir) && nzchar(.script_dir)) {
    app_dir <- .script_dir
  } else {
    app_dir <- getwd()
  }

  # If app_dir does not already point inside the expected subfolder,
  # append the known relative path so that all downstream paths work.
  if (!grepl("01_Configure_Simulation", app_dir, fixed = TRUE)) {
    candidate <- file.path(app_dir, "40_GUI", "01_Configure_Simulation")
    if (dir.exists(candidate)) {
      app_dir <- normalizePath(candidate)
    } else {
      stop(
        "GUI_config.R: cannot locate '40_GUI/01_Configure_Simulation' ",
        "under '", app_dir, "'.  ",
        "Please run this script from the repo root or from the app folder."
      )
    }
  }

  repo_root   <- normalizePath(file.path(app_dir, "..", ".."))
  config_path <- file.path(repo_root, "01_Simulation", "02_Config")
}

# -------------------------------------------------------------
# Source helper functions
# -------------------------------------------------------------
functions_path <- file.path(app_dir, "03_Functions")
source(file.path(functions_path, "read_param_csv.R"))
source(file.path(functions_path, "write_param_csv.R"))
source(file.path(functions_path, "get_val.R"))

# -------------------------------------------------------------
# Read all config files at startup
# -------------------------------------------------------------
model_df        <- read_param_csv("model_parameters.csv")
control_df      <- read_param_csv("control_parameters.csv")
optim_df        <- read_param_csv("optimization_parameters.csv")
forecast_df     <- read_param_csv("forecast_parameters.csv")
reward_df       <- read_param_csv("reward_parameters.csv")
debug_df        <- read_param_csv("debug_and_config.csv")
flex_price_df   <- read_param_csv("flex_price_simulation.csv")
setpoint_modes_df <- read.csv(
  file.path(config_path, "setpoint_modes.csv"),
  comment.char = "#", strip.white = TRUE, stringsAsFactors = FALSE
)

# -------------------------------------------------------------
# UI
# -------------------------------------------------------------
ui <- fluidPage(
  useShinyjs(),
  titlePanel("MPC in Buildings \u2013 Configuration Editor"),

  tabsetPanel(

    # ----------------------------------------------------------
    # Tab 1: Model parameters (building physics & HVAC)
    # ----------------------------------------------------------
    tabPanel("Model Parameters",
      h4("Building Physics"),
      fluidRow(
        column(4, numericInput("Ci",  "Ci \u2013 Internal thermal mass (MWh/K)",  value = get_val(model_df, "Ci"),  step = 0.01)),
        column(4, numericInput("Ce",  "Ce \u2013 External thermal mass (MWh/K)",  value = get_val(model_df, "Ce"),  step = 0.01)),
        column(4, numericInput("Rie", "Rie \u2013 Int-Ext resistance (K/kW)",     value = get_val(model_df, "Rie"), step = 0.001))
      ),
      fluidRow(
        column(4, numericInput("Rea", "Rea \u2013 Ext-Amb resistance (K/kW)",     value = get_val(model_df, "Rea"), step = 0.01)),
        column(4, numericInput("Aw",  "Aw \u2013 Window area (m2)",               value = get_val(model_df, "Aw"),  step = 0.01)),
        column(4, numericInput("Ae",  "Ae \u2013 Envelope area (m2)",             value = get_val(model_df, "Ae"),  step = 0.01))
      ),
      hr(),
      h4("Solar Control"),
      fluidRow(
        column(4, numericInput("Shading_0",        "Shading_0 \u2013 Shading factor (closed)",  value = get_val(model_df, "Shading_0"),        step = 0.01)),
        column(4, numericInput("Shading_1",        "Shading_1 \u2013 Shading factor (open)",    value = get_val(model_df, "Shading_1"),        step = 0.01)),
        column(4, numericInput("Setpoint_Shading1","Setpoint_Shading1 \u2013 Temp trigger (C)", value = get_val(model_df, "Setpoint_Shading1"), step = 0.5))
      ),
      hr(),
      h4("Heat Pump \u2013 Heating"),
      fluidRow(
        column(3, numericInput("AT_hp_heat_1",      "AT_hp_heat_1",       value = get_val(model_df, "AT_hp_heat_1"),      step = 0.1)),
        column(3, numericInput("AT_hp_heat_2",      "AT_hp_heat_2",       value = get_val(model_df, "AT_hp_heat_2"),      step = 0.1)),
        column(3, numericInput("Q_hp_heat_1",       "Q_hp_heat_1 (kW)",   value = get_val(model_df, "Q_hp_heat_1"),       step = 0.1)),
        column(3, numericInput("Q_hp_heat_2",       "Q_hp_heat_2 (kW)",   value = get_val(model_df, "Q_hp_heat_2"),       step = 0.1))
      ),
      fluidRow(
        column(3, numericInput("COP_hp_heat_1_coef1","COP coef1",         value = get_val(model_df, "COP_hp_heat_1_coef1"), step = 0.001)),
        column(3, numericInput("COP_hp_heat_1_coef2","COP coef2",         value = get_val(model_df, "COP_hp_heat_1_coef2"), step = 0.0001)),
        column(3, numericInput("COP_hp_heat_1_coef3","COP coef3",         value = get_val(model_df, "COP_hp_heat_1_coef3"), step = 0.0001)),
        column(3, numericInput("COP_hp_heat_2",     "COP_hp_heat_2",      value = get_val(model_df, "COP_hp_heat_2"),       step = 0.1))
      ),
      fluidRow(
        column(4, numericInput("Tsup_hp_heat","Tsup_hp_heat \u2013 Supply temp (C)", value = get_val(model_df, "Tsup_hp_heat"), step = 1))
      ),
      hr(),
      h4("Heat Pump \u2013 Cooling"),
      fluidRow(
        column(4, numericInput("AT_hp_cool", "AT_hp_cool",            value = get_val(model_df, "AT_hp_cool"), step = 0.1)),
        column(4, numericInput("Q_hp_cool",  "Q_hp_cool (kW)",        value = get_val(model_df, "Q_hp_cool"),  step = 0.1)),
        column(4, numericInput("COP_hp_cool","COP_hp_cool",           value = get_val(model_df, "COP_hp_cool"),step = 0.1))
      ),
      hr(),
      h4("Ventilation"),
      fluidRow(
        column(3, numericInput("Rvent01",        "Rvent01 (K/kW)",          value = get_val(model_df, "Rvent01"),        step = 0.01)),
        column(3, numericInput("Rvent1",         "Rvent1 (K/kW)",           value = get_val(model_df, "Rvent1"),         step = 0.01)),
        column(3, numericInput("Rvent2",         "Rvent2 (K/kW)",           value = get_val(model_df, "Rvent2"),         step = 0.01)),
        column(3, numericInput("Setpoint_Rvent1","Setpoint_Rvent1 (C)",     value = get_val(model_df, "Setpoint_Rvent1"),step = 0.5))
      ),
      hr(),
      h4("State Initialization"),
      fluidRow(
        column(3, numericInput("Ti_0","Ti_0 \u2013 Initial indoor temp (C)",    value = get_val(model_df, "Ti_0"), step = 0.5)),
        column(3, numericInput("Te_0","Te_0 \u2013 Initial envelope temp (C)",  value = get_val(model_df, "Te_0"), step = 0.5)),
        column(3, numericInput("Qh_0","Qh_0 \u2013 Initial heating power (kW)", value = get_val(model_df, "Qh_0"), step = 0.1)),
        column(3, numericInput("Qc_0","Qc_0 \u2013 Initial cooling power (kW)", value = get_val(model_df, "Qc_0"), step = 0.1))
      ),
      br(),
      actionButton("save_model", "Save model_parameters.csv", class = "btn-primary"),
      textOutput("msg_model")
    ),

    # ----------------------------------------------------------
    # Tab 2: Control parameters
    # ----------------------------------------------------------
    tabPanel("Control Parameters",
      h4("Setpoint Ranges"),
      fluidRow(
        column(3, numericInput("sp_heat_low", "Heating SP low (C)",  value = get_val(control_df, "set_point_range_heating_low"),  step = 0.5)),
        column(3, numericInput("sp_heat_high","Heating SP high (C)", value = get_val(control_df, "set_point_range_heating_high"), step = 0.5)),
        column(3, numericInput("sp_cool_low", "Cooling SP low (C)",  value = get_val(control_df, "set_point_range_cooling_low"),  step = 0.5)),
        column(3, numericInput("sp_cool_high","Cooling SP high (C)", value = get_val(control_df, "set_point_range_cooling_high"), step = 0.5))
      ),
      hr(),
      h4("Hysteresis & Defaults"),
      fluidRow(
        column(3, numericInput("Deadband",             "Deadband (K)",                  value = get_val(control_df, "Deadband"),               step = 0.1)),
        column(3, numericInput("sp_def_cool",          "Default cooling SP (C)",        value = get_val(control_df, "set_point_default_cooling"),step = 0.5)),
        column(3, numericInput("sp_def_heat",          "Default heating SP (C)",        value = get_val(control_df, "set_point_default_heating"),step = 0.5)),
        column(3, numericInput("mode_default",         "Default mode (integer)",        value = get_val(control_df, "mode_default"),            step = 1))
      ),
      hr(),
      h4("Control & Optimization Type"),
      fluidRow(
        column(4,
          selectInput("control_type", "Control type",
                      choices = c("Modes (1)" = 1, "Setpoints (2)" = 2),
                      selected = get_val(control_df, "control_type"))
        ),
        column(4,
          selectInput("optimization_aim", "Optimization aim",
                      choices = c("Energy (1)" = 1, "Flexibility (2)" = 2),
                      selected = get_val(control_df, "optimization_aim"))
        )
      ),
      hr(),
      h4("Flexibility Parameters"),
      fluidRow(
        column(4, numericInput("flex_event_length",   "Max event length (h)",       value = get_val(control_df, "flexibility_event_length_max"),  step = 0.5)),
        column(4, numericInput("flex_recover",        "Recover timespan (h)",       value = get_val(control_df, "flexibility_recover_timespan"),   step = 0.5)),
        column(4, numericInput("thermal_stab",        "Thermal stabilization (h)",  value = get_val(control_df, "thermal_stabilization_timespan"), step = 0.5))
      ),
      fluidRow(
        column(4, numericInput("flex_commitment",     "Flexibility commitment (-)",  value = get_val(control_df, "flexibility_commitment"),     step = 0.05)),
        column(4, numericInput("min_flexibility",     "Minimum flexibility (kW)",   value = get_val(control_df, "minimum_flexibility"),         step = 0.1)),
        column(4, numericInput("min_spare",           "Minimum spare capacity (kW)",value = get_val(control_df, "minimum_spare_capacity"),      step = 0.1))
      ),
      fluidRow(
        column(4, numericInput("flex_splits",         "Flexibility splits (-)",     value = get_val(control_df, "flexibility_splits"),          step = 1, min = 1))
      ),
      br(),
      actionButton("save_control", "Save control_parameters.csv", class = "btn-primary"),
      textOutput("msg_control")
    ),

    # ----------------------------------------------------------
    # Tab 3: Optimization parameters
    # ----------------------------------------------------------
    tabPanel("Optimization Parameters",
      h4("Genetic Algorithm"),
      fluidRow(
        column(4, numericInput("pop_size",   "Population size",      value = get_val(optim_df, "population_size"),  step = 1, min = 1)),
        column(4, numericInput("iter_num",   "Iteration number",     value = get_val(optim_df, "iteration_number"), step = 1, min = 1)),
        column(4, numericInput("run_num",    "Run number",           value = get_val(optim_df, "run_number"),       step = 1, min = 1))
      ),
      fluidRow(
        column(4, numericInput("pcrossover", "Crossover probability", value = get_val(optim_df, "pcrossover"), step = 0.01, min = 0, max = 1)),
        column(4, numericInput("pmutation",  "Mutation probability",  value = get_val(optim_df, "pmutation"),  step = 0.01, min = 0, max = 1))
      ),
      hr(),
      h4("MPC Horizon"),
      fluidRow(
        column(3, numericInput("opt_horizon",   "Optimization horizon (h)",     value = get_val(optim_df, "control_optimization_horizon"),     step = 1, min = 1)),
        column(3, numericInput("impl_horizon",  "Implementation horizon (h)",   value = get_val(optim_df, "control_implementation_horizon"),   step = 1, min = 1)),
        column(3, numericInput("anticipation",  "Anticipation (h)",             value = get_val(optim_df, "control_optimization_anticipation"), step = 1, min = 0)),
        column(3, numericInput("mkt_res",       "Market resolution (min)",      value = get_val(optim_df, "market_resolution"),                step = 1, min = 1))
      ),
      br(),
      actionButton("save_optim", "Save optimization_parameters.csv", class = "btn-primary"),
      textOutput("msg_optim")
    ),

    # ----------------------------------------------------------
    # Tab 4: Forecast parameters
    # ----------------------------------------------------------
    tabPanel("Forecast Parameters",
      h4("Forecast Type"),
      fluidRow(
        column(6,
          selectInput("forecast_type", "Forecast type",
                      choices = c("Inaccurate (1)" = 1, "Accurate (2)" = 2),
                      selected = get_val(forecast_df, "forecast_type"))
        )
      ),
      hr(),
      h4("Inaccurate Forecast Model"),
      fluidRow(
        column(4, numericInput("n_days_back",       "Days back for history",      value = get_val(forecast_df, "forecast_n_days_back"),    step = 1, min = 1)),
        column(4, numericInput("weight_history",    "Weight on history (0-1)",    value = get_val(forecast_df, "forecast_weight_history"), step = 0.05, min = 0, max = 1)),
        column(4, numericInput("t_ext_default",     "T_ext_24h default (C)",      value = get_val(forecast_df, "t_ext_24h_default"),       step = 0.5))
      ),
      br(),
      actionButton("save_forecast", "Save forecast_parameters.csv", class = "btn-primary"),
      textOutput("msg_forecast")
    ),

    # ----------------------------------------------------------
    # Tab 5: Reward parameters
    # ----------------------------------------------------------
    tabPanel("Reward Parameters",
      h4("Comfort Penalty Weight"),
      fluidRow(
        column(6,
          numericInput("Alpha_confort",
                       "Alpha_confort \u2013 Weight of comfort in reward function",
                       value = get_val(reward_df, "Alpha_confort"),
                       step = 0.5, min = 0)
        )
      ),
      hr(),
      h4("Comfort Bounds"),
      fluidRow(
        column(4, numericInput("confort_low", "confort_low (C)",  value = get_val(reward_df, "confort_low"),  step = 0.5)),
        column(4, numericInput("confort_high","confort_high (C)", value = get_val(reward_df, "confort_high"), step = 0.5))
      ),
      br(),
      actionButton("save_reward", "Save reward_parameters.csv", class = "btn-primary"),
      textOutput("msg_reward")
    ),

    # ----------------------------------------------------------
    # Tab 6: Setpoint modes
    # ----------------------------------------------------------
    tabPanel("Setpoint Modes",
      h4("Setpoint Modes Table"),
      p("Edit the table below. Each row defines a mode with its associated heating and cooling setpoints."),
      rHandsontableOutput("modes_table"),
      br(),
      fluidRow(
        column(3, actionButton("add_mode_row",    "Add row",         class = "btn-success")),
        column(3, actionButton("remove_mode_row", "Remove last row", class = "btn-warning"))
      ),
      br(),
      actionButton("save_modes", "Save setpoint_modes.csv", class = "btn-primary"),
      textOutput("msg_modes")
    ),

    # ----------------------------------------------------------
    # Tab 7: Debug & Configuration
    # ----------------------------------------------------------
    tabPanel("Debug & Config",
      h4("Simulation Scope (debugging / targeted runs)"),
      fluidRow(
        column(4,
          numericInput("month_subset",  "Month subset (0 = full year)",
                       value = get_val(debug_df, "month_subset"), step = 1, min = 0, max = 12)
        ),
        column(4,
          numericInput("period_subset", "Period subset in timesteps (0 = all)",
                       value = get_val(debug_df, "period_subset"), step = 1, min = 0)
        )
      ),
      hr(),
      h4("Execution"),
      fluidRow(
        column(4,
          checkboxInput("verbose",  "Verbose output", value = (get_val(debug_df, "verbose") == 1))
        ),
        column(4,
          checkboxInput("parallel", "Parallel execution", value = (get_val(debug_df, "parallel") == 1))
        )
      ),
      hr(),
      h4("Price Emulation"),
      fluidRow(
        column(4,
          checkboxInput("Price_emulation", "Enable price emulation",
                        value = (get_val(debug_df, "Price_emulation") == 1))
        )
      ),
      br(),
      actionButton("save_debug", "Save debug_and_config.csv", class = "btn-primary"),
      textOutput("msg_debug")
    ),

    # ----------------------------------------------------------
    # Tab 8: Flex Price Simulation
    # ----------------------------------------------------------
    tabPanel("Flex Price Simulation",
      h4("Flexibility Price Simulation Parameters"),
      p("These parameters control the random generation of flexibility prices when price emulation is enabled."),
      fluidRow(
        column(4,
          numericInput("Max_flex_periods_day", "Max flex periods per day (count)",
                       value = get_val(flex_price_df, "Max_flex_periods_day"), step = 1, min = 0)
        ),
        column(4,
          numericInput("Max_flex_com_price", "Max flex commitment price (\u20ac/kWh)",
                       value = get_val(flex_price_df, "Max_flex_com_price"), step = 0.1, min = 0)
        ),
        column(4,
          numericInput("Max_flex_exec_price", "Max flex execution price (\u20ac/kWh)",
                       value = get_val(flex_price_df, "Max_flex_exec_price"), step = 0.1, min = 0)
        )
      ),
      fluidRow(
        column(4,
          numericInput("Max_flex_period_duration", "Max flex period duration (h)",
                       value = get_val(flex_price_df, "Max_flex_period_duration"), step = 0.5, min = 0)
        ),
        column(4,
          numericInput("Max_flex_probability", "Max flex probability (%)",
                       value = get_val(flex_price_df, "Max_flex_probability"), step = 0.01, min = 0, max = 100)
        )
      ),
      br(),
      actionButton("save_flex_price", "Save flex_price_simulation.csv", class = "btn-primary"),
      textOutput("msg_flex_price")
    )

  ) # end tabsetPanel
) # end fluidPage

# -------------------------------------------------------------
# Server
# -------------------------------------------------------------
server <- function(input, output, session) {

  # ---- Setpoint modes reactive table ----
  modes_rv <- reactiveVal(setpoint_modes_df)

  output$modes_table <- renderRHandsontable({
    rhandsontable(modes_rv(), stretchH = "all") %>%
      hot_col("mode",    type = "numeric") %>%
      hot_col("heating", type = "numeric") %>%
      hot_col("cooling", type = "numeric")
  })

  observeEvent(input$add_mode_row, {
    df       <- modes_rv()
    new_mode <- if (nrow(df) > 0) max(df$mode, na.rm = TRUE) + 1 else 1
    df       <- rbind(df, data.frame(mode = new_mode, heating = 20, cooling = 26))
    modes_rv(df)
  })

  observeEvent(input$remove_mode_row, {
    df <- modes_rv()
    if (nrow(df) > 1) modes_rv(df[-nrow(df), ])
  })

  # ---- Save: model_parameters.csv ----
  observeEvent(input$save_model, {
    params <- c("Ci","Ce","Rie","Rea","Aw","Ae",
                "Shading_0","Shading_1","Setpoint_Shading1",
                "AT_hp_heat_1","AT_hp_heat_2","Q_hp_heat_1","Q_hp_heat_2",
                "COP_hp_heat_1_coef1","COP_hp_heat_1_coef2","COP_hp_heat_1_coef3",
                "COP_hp_heat_2","Tsup_hp_heat",
                "AT_hp_cool","Q_hp_cool","COP_hp_cool",
                "Rvent01","Rvent1","Rvent2","Setpoint_Rvent1",
                "Ti_0","Te_0","Qh_0","Qc_0")
    vals <- sapply(params, function(p) input[[p]])
    df   <- data.frame(parameter = params, value = vals, stringsAsFactors = FALSE)
    header <- "# Physical and thermal parameters of the building and HVAC system"
    write_param_csv("model_parameters.csv", df, header)
    output$msg_model <- renderText("\u2714 model_parameters.csv saved.")
  })

  # ---- Save: control_parameters.csv ----
  observeEvent(input$save_control, {
    params <- c("set_point_range_heating_low","set_point_range_heating_high",
                "set_point_range_cooling_low","set_point_range_cooling_high",
                "Deadband","control_type",
                "set_point_default_cooling","set_point_default_heating",
                "mode_default","optimization_aim",
                "flexibility_event_length_max","flexibility_recover_timespan",
                "thermal_stabilization_timespan","flexibility_commitment",
                "minimum_flexibility","minimum_spare_capacity","flexibility_splits")
    vals <- c(input$sp_heat_low, input$sp_heat_high,
              input$sp_cool_low, input$sp_cool_high,
              input$Deadband, as.integer(input$control_type),
              input$sp_def_cool, input$sp_def_heat,
              as.integer(input$mode_default), as.integer(input$optimization_aim),
              input$flex_event_length, input$flex_recover,
              input$thermal_stab, input$flex_commitment,
              input$min_flexibility, input$min_spare, as.integer(input$flex_splits))
    df   <- data.frame(parameter = params, value = vals, stringsAsFactors = FALSE)
    header <- "# HVAC control parameters"
    write_param_csv("control_parameters.csv", df, header)
    output$msg_control <- renderText("\u2714 control_parameters.csv saved.")
  })

  # ---- Save: optimization_parameters.csv ----
  observeEvent(input$save_optim, {
    params <- c("population_size","iteration_number","run_number",
                "pcrossover","pmutation",
                "control_optimization_horizon","control_implementation_horizon",
                "control_optimization_anticipation","market_resolution")
    vals <- c(as.integer(input$pop_size), as.integer(input$iter_num), as.integer(input$run_num),
              input$pcrossover, input$pmutation,
              input$opt_horizon, input$impl_horizon,
              input$anticipation, as.integer(input$mkt_res))
    df   <- data.frame(parameter = params, value = vals, stringsAsFactors = FALSE)
    header <- "# Optimization and MPC horizon parameters"
    write_param_csv("optimization_parameters.csv", df, header)
    output$msg_optim <- renderText("\u2714 optimization_parameters.csv saved.")
  })

  # ---- Save: forecast_parameters.csv ----
  observeEvent(input$save_forecast, {
    params <- c("forecast_type","forecast_n_days_back",
                "forecast_weight_history","t_ext_24h_default")
    vals   <- c(as.integer(input$forecast_type),
                as.integer(input$n_days_back),
                input$weight_history,
                input$t_ext_default)
    df   <- data.frame(parameter = params, value = vals, stringsAsFactors = FALSE)
    header <- "# Weather forecast parameters"
    write_param_csv("forecast_parameters.csv", df, header)
    output$msg_forecast <- renderText("\u2714 forecast_parameters.csv saved.")
  })

  # ---- Save: reward_parameters.csv ----
  observeEvent(input$save_reward, {
    df <- data.frame(parameter = c("Alpha_confort", "confort_low", "confort_high"),
                     value     = c(input$Alpha_confort, input$confort_low, input$confort_high),
                     stringsAsFactors = FALSE)
    write_param_csv("reward_parameters.csv", df, "# Reward function parameters")
    output$msg_reward <- renderText("\u2714 reward_parameters.csv saved.")
  })

  # ---- Save: debug_and_config.csv ----
  observeEvent(input$save_debug, {
    params <- c("month_subset", "period_subset", "verbose", "parallel", "Price_emulation")
    vals   <- c(as.integer(input$month_subset),
                as.integer(input$period_subset),
                as.integer(input$verbose),
                as.integer(input$parallel),
                as.integer(input$Price_emulation))
    df <- data.frame(parameter = params, value = vals, stringsAsFactors = FALSE)
    write_param_csv("debug_and_config.csv", df, "# Debug and configuration parameters")
    output$msg_debug <- renderText("\u2714 debug_and_config.csv saved.")
  })

  # ---- Save: flex_price_simulation.csv ----
  observeEvent(input$save_flex_price, {
    params <- c("Max_flex_periods_day", "Max_flex_com_price", "Max_flex_exec_price",
                "Max_flex_period_duration", "Max_flex_probability")
    vals   <- c(as.integer(input$Max_flex_periods_day),
                input$Max_flex_com_price,
                input$Max_flex_exec_price,
                input$Max_flex_period_duration,
                input$Max_flex_probability)
    df <- data.frame(parameter = params, value = vals, stringsAsFactors = FALSE)
    write_param_csv("flex_price_simulation.csv", df, "# Flexibility price simulation parameters")
    output$msg_flex_price <- renderText("\u2714 flex_price_simulation.csv saved.")
  })

  # ---- Save: setpoint_modes.csv ----
  observeEvent(input$save_modes, {
    if (is.null(input$modes_table)) {
      output$msg_modes <- renderText("No table data to save.")
      return()
    }
    df <- tryCatch(
      hot_to_r(input$modes_table),
      error = function(e) {
        output$msg_modes <- renderText(paste("Error reading table:", conditionMessage(e)))
        NULL
      }
    )
    if (is.null(df)) return()
    path <- file.path(config_path, "setpoint_modes.csv")
    con  <- file(path, open = "wt")
    writeLines("# Setpoint modes & associated heating and cooling setpoints", con)
    write.csv(df, con, row.names = FALSE, quote = FALSE)
    close(con)
    output$msg_modes <- renderText("\u2714 setpoint_modes.csv saved.")
  })

} # end server

# -------------------------------------------------------------
# Launch
# -------------------------------------------------------------
shinyApp(ui = ui, server = server)
