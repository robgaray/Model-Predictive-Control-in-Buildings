# -------------------------------------------------------------
# Script: GUI_config.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Shiny interface for editing and saving simulation
# configuration files in 30_Simulation/02_Config.
# The interface reads parameter files and editable tables,
# keeps the reactive state synchronized with user edits,
# and writes all configuration files when the save button
# of any tab is pressed.
# -------------------------------------------------------------
# File paths: the file names of every configuration file are read
# from 30_Simulation/02_Config/00_Inner_parameters/04_File_paths.csv (falls back to a
# hard-coded default list if that file is missing/unreadable), so
# this app no longer keeps its own separate copy of that list.
# -------------------------------------------------------------
# Loading safety: every configuration file is loaded through a
# "safe loader" that tolerates a missing file, a missing parameter,
# a duplicated parameter, or an invalid value. Whatever loads and
# validates correctly is kept; anything missing or invalid is
# replaced by the matching entry from a Default_ file in
# 30_Simulation/02_Config/00_Validation/ (default values are never
# hard-coded in this script); a duplicated parameter keeps its first
# value. Every such case is collected as a warning, and the affected
# input/row is rendered in red so the user can see at a glance what
# came from defaults, or was deduplicated, rather than being read
# as-is from the file on disk. All loading/saving notices are shown
# in English.
# -------------------------------------------------------------
# Validation: values are validated against
# 30_Simulation/02_Config/00_Validation/Parameter_config.csv (the
# same rules used by the real simulation pipeline) both when loading
# (to decide what counts as valid) and again right before saving (to
# refuse to write anything if any field is currently invalid).
# -------------------------------------------------------------
# Inputs
#   30_Simulation/02_Config/*.csv : the configuration files, with their
#     names read from 04_File_paths.csv.
#   30_Simulation/02_Config/00_Validation/ : Parameter_config.csv and
#     the Default_ files that fill whatever is missing or invalid.
#   20_GUI/01_Configure_Simulation/02_Config/GUI_fallback_values.csv :
#     the values used when a row has no default either.
#   The user's edits in the browser.
# -------------------------------------------------------------
# Outputs
#   The same configuration files under 30_Simulation/02_Config/,
#   rewritten when a save button is pressed and every value is valid.
# -------------------------------------------------------------
# Code outline
# Libraries and paths of the app and of the repository, then:
# 1. File paths (04_File_paths.csv)
# 2. Validation rules (Parameter_config.csv), 2.1 parameter units and
#    2.2 the fallback values of the GUI (02_Config/)
# 3. Helper functions, sourced from 03_Functions/, and 3.1 the
#    options of the closed-list parameters
# 4. Initial (safe) loading of every configuration file
# Then the user interface, one tab per group of configuration files;
# the server, which keeps the edits in reactive state, validates and
# saves; and shinyApp(ui, server).
# -------------------------------------------------------------
# Usage instructions
# From the repository root, or from this folder:
#   Rscript -e 'shiny::runApp("20_GUI/01_Configure_Simulation/GUI_config.R")'
# or source it from RStudio. It needs shiny, shinyjs and DT.
# -------------------------------------------------------------
# Where this function/script is used
# Run by hand. Nothing in the repository calls it.
# -------------------------------------------------------------
# functions/scripts called
# The helpers of 20_GUI/01_Configure_Simulation/03_Functions/, one per
# file:
#   - validity checks
#   - readers
#   - safe loaders
#   - writers
#   - editor builders
# and those of these packages:
#   - shiny
#   - shinyjs
#   - DT
# It calls no function or script of 30_Simulation/.
# -------------------------------------------------------------

library(shiny)
library(shinyjs)
library(DT)

input_path <- "30_Simulation/02_Config"

{
  .script_dir <- tryCatch(
    dirname(normalizePath(sys.frame(1)$ofile)),
    error = function(e) NULL
  )

  if (!is.null(.script_dir) && nzchar(.script_dir)) {
    app_dir <- .script_dir
  } else {
    app_dir <- getwd()
  }

  if (!grepl("01_Configure_Simulation", app_dir, fixed = TRUE)) {
    candidate <- file.path(app_dir, "20_GUI", "01_Configure_Simulation")
    if (dir.exists(candidate)) {
      app_dir <- normalizePath(candidate)
    } else {
      stop(
        "GUI_config.R: cannot locate '20_GUI/01_Configure_Simulation' ",
        "under '", app_dir, "'.  ",
        "Please run this script from the repo root or from the app folder."
      )
    }
  }

  repo_root <- normalizePath(file.path(app_dir, "..", ".."))
  config_path <- normalizePath(
    file.path(repo_root, input_path),
    winslash = "/",
    mustWork = TRUE
  )
}

# Collects every loading warning/notice generated below, shown to the
# user in a banner at the top of the app.
all_load_messages <- character(0)

# -------------------------------------------------------------
# 1. File paths (30_Simulation/02_Config/00_Inner_parameters/04_File_paths.csv)
# -------------------------------------------------------------
{
  default_file_names <- list(
    library_file                     = "00_Inner_parameters/00_Libraries.txt",
    needed_cols_file                 = "00_Inner_parameters/02_Needed_cols.csv",
    parameter_validation_file        = "00_Validation/Parameter_config.csv",
    physical_properties_file         = "00_Inner_parameters/03_Physical_properties.csv",
    optimization_file                = "01_Optimization_parameters.csv",
    control_file                     = "02_Control.csv",
    market_file                      = "03_Market_config.csv",
    market_config_scheduling_file    = "04_Market_config_scheduling.csv",
    market_config_piloting_file      = "05_Market_config_piloting.csv",
    energy_price_file                = "06_Energy_price_parameters.csv",
    flexibility_price_emulation_file = "07_Flexibility_price_emulation_parameters.csv",
    flexibility_events_file          = "08_Flexibility_Event_Configuration.csv",
    reward_file                      = "09_Reward_parameters.csv",
    reward_corrections_file          = "10_Reward_parameter_corrections.csv",
    model_file                       = "11_Model_parameters.csv",
    temperature_setpoints_file       = "12_Temperature_Setpoints.csv",
    setpoint_mode_file               = "13_Modes_setpoints.csv",
    use_patterns_file                = "14_Use_Patterns.csv",
    forecast_file                    = "15_Forecast_parameters.csv",
    debug_and_config_file            = "16_Debug_and_config.csv"
  )

  paths_file_name <- "00_Inner_parameters/04_File_paths.csv"
  paths_table <- tryCatch(
    suppressWarnings(read.csv(file.path(config_path, paths_file_name), comment.char = "#",
                              stringsAsFactors = FALSE, strip.white = TRUE)),
    error = function(e) NULL
  )

  if (is.null(paths_table) ||
      !all(c("key", "filename") %in% names(paths_table)) ||
      nrow(paths_table) == 0) {
    all_load_messages <- c(all_load_messages, sprintf(
      "Could not read '%s' (missing file or invalid columns). Using the default file paths.",
      paths_file_name
    ))
    paths <- default_file_names
  } else {
    loaded_paths <- setNames(
      as.list(trimws(as.character(paths_table$filename))),
      trimws(as.character(paths_table$key))
    )
    paths <- default_file_names
    for (key in names(default_file_names)) {
      if (!is.null(loaded_paths[[key]]) && nzchar(loaded_paths[[key]])) {
        paths[[key]] <- loaded_paths[[key]]
      } else {
        all_load_messages <- c(all_load_messages, sprintf(
          "'%s' is missing from %s. Using the default path '%s'.",
          key, paths_file_name, default_file_names[[key]]
        ))
      }
    }
  }

  file_names <- list(
    model        = paths$model_file,
    occupancy    = paths$use_patterns_file,
    control      = paths$control_file,
    temperature_setpoints = paths$temperature_setpoints_file,
    flexibility_events    = paths$flexibility_events_file,
    modes        = paths$setpoint_mode_file,
    optimization = paths$optimization_file,
    market       = paths$market_file,
    sched        = paths$market_config_scheduling_file,
    pilot        = paths$market_config_piloting_file,
    reward       = paths$reward_file,
    reward_corrections = paths$reward_corrections_file,
    forecast     = paths$forecast_file,
    energy_price = paths$energy_price_file,
    flex_generation = paths$flexibility_price_emulation_file,
    debug        = paths$debug_and_config_file
  )

  rm(default_file_names, paths_file_name, paths_table)
}

# -------------------------------------------------------------
# 2. Validation rules (00_Validation/Parameter_config.csv).
# -------------------------------------------------------------
{
  validation_config <- tryCatch(
    suppressWarnings(read.csv(file.path(config_path, paths$parameter_validation_file),
                              comment.char = "#", stringsAsFactors = FALSE)),
    error = function(e) NULL
  )

  required_cols <- c("file_name", "parameter_name", "type", "output", "options")
  if (is.null(validation_config) || !all(required_cols %in% names(validation_config))) {
    all_load_messages <- c(all_load_messages, sprintf(
      "Could not read '%s'. Value validation is limited to basic checks.",
      paths$parameter_validation_file
    ))
    validation_config <- data.frame(
      file_name = character(0), parameter_name = character(0),
      type = character(0), output = character(0), options = character(0),
      stringsAsFactors = FALSE
    )
  }

  rm(required_cols)
}

# -------------------------------------------------------------
# 2.1. Parameter units (90_Structure/Parameter_Units.csv).
# -------------------------------------------------------------
# get_param_unit()/label_with_unit() (03_Functions/) read this table
# for build_param_editor() and build_group_editor(), to append
# "[unit]" to every parameter label, per 00_Base_Criteria.md ("Units
# in graphic interfaces").
# -------------------------------------------------------------
{
  param_units_table <- tryCatch(
    suppressWarnings(read.csv(file.path(repo_root, "90_Structure", "Parameter_Units.csv"),
                              stringsAsFactors = FALSE)),
    error = function(e) NULL
  )
}

# -------------------------------------------------------------
# 2.2. Fallback values of the GUI (02_Config/GUI_fallback_values.csv)
# -------------------------------------------------------------
# The values the safe loaders use when a row is invalid in its file
# and missing from its Default_ file too, and the tolerance of the
# Integer check. They live in this app's own configuration folder,
# never in the code. Without them the loaders would have nothing to
# fall back on, so a missing or invalid file stops the app with a
# message saying which file and which value.
# -------------------------------------------------------------
{
  fallback_file <- file.path(app_dir, "02_Config", "GUI_fallback_values.csv")
  fallback_table <- tryCatch(
    suppressWarnings(read.csv(fallback_file, comment.char = "#",
                              stringsAsFactors = FALSE, strip.white = TRUE)),
    error = function(e) NULL
  )
  numeric_names <- c("mode_heating_setpoint", "mode_cooling_setpoint",
                     "market_closure", "market_begin", "market_end",
                     "market_end_optimization", "occupancy_hour_value",
                     "integer_tolerance")
  text_names    <- c("market_aim_scheduling", "market_aim_piloting")
  if (is.null(fallback_table) ||
      !all(c("parameter", "value") %in% names(fallback_table))) {
    stop("GUI_config.R: cannot read ", fallback_file)
  }
  fallback_values <- setNames(trimws(as.character(fallback_table$value)),
                              trimws(as.character(fallback_table$parameter)))
  invalid_fallback <- c(
    numeric_names[is.na(suppressWarnings(as.numeric(fallback_values[numeric_names])))],
    text_names[is.na(fallback_values[text_names]) | !nzchar(fallback_values[text_names])]
  )
  if (length(invalid_fallback) > 0) {
    stop("GUI_config.R: ", fallback_file, " lacks a valid value for: ",
         paste(invalid_fallback, collapse = ", "))
  }
  gui_fallback <- c(
    as.list(setNames(as.numeric(fallback_values[numeric_names]), numeric_names)),
    as.list(fallback_values[text_names])
  )

  rm(fallback_file, fallback_table, numeric_names, text_names, fallback_values,
     invalid_fallback)
}

# -------------------------------------------------------------
# 3. Helper functions (03_Functions/)
# -------------------------------------------------------------
# Every helper of the app lives in its own file under 03_Functions/:
# the validity checks, the raw readers, the safe loaders with their
# defaults, the writers and the builders of the editors. They are
# sourced into this environment rather than the global one, because
# the readers and writers use config_path, and get_param_unit() uses
# param_units_table, both resolved above; so they behave exactly as
# if they were written here, whether the app is started with runApp()
# or sourced.
# -------------------------------------------------------------
{
  for (CONT_001 in list.files(file.path(app_dir, "03_Functions"),
                              pattern = "\\.R$", full.names = TRUE)) {
    # source() is called to define each helper in this environment.
    source(CONT_001, local = TRUE)
  }
  rm(CONT_001)
}

# -------------------------------------------------------------
# 3.1. Options of the closed-list parameters
# -------------------------------------------------------------
# validation_options() is called to take the allowed aims of a
# market, and the 0/1 flags of 16_Debug_and_config.csv, from
# Parameter_config.csv, the one place they are declared. The market
# tables have no rule of their own for their aim column, so they
# check it against the aims of 03_Market_config.csv.
# -------------------------------------------------------------
{
  market_aim_options <- validation_options(validation_config, "03_Market_config.csv",
                                           "optimization_aim_scheduling")
  debug_flag_options <- lapply(
    setNames(nm = c("verbose", "parallel", "Price_emulation")),
    function(name) validation_options(validation_config, "16_Debug_and_config.csv", name)
  )
}

# The browser side of the editable tables: every change of a cell
# input is sent to the server as <prefix>_cell_text_edit, which
# apply_text_table_edit() applies to the reactive state.
table_input_callback <- JS(
  "table.on('change', 'input.table-cell-input', function() {",
  "  var input = $(this);",
  "  Shiny.setInputValue(input.data('prefix') + '_cell_text_edit', {",
  "    row: parseInt(input.data('row'), 10),",
  "    col: input.data('col'),",
  "    value: input.val(),",
  "    nonce: Math.random()",
  "  }, {priority: 'event'});",
  "});"
)

# -------------------------------------------------------------
# 4. Initial (safe) loading of every configuration file.
# -------------------------------------------------------------
# load_param_file_safe() is called once per flat "parameter,value"
# configuration file, reconciling it against its Default_<file>
# counterpart so a missing/invalid entry never stops the app - the
# same call pattern repeats for every tab below.
model_load        <- load_param_file_safe(file_names$model, "11_Model_parameters.csv",
                                          default_file_for(file_names$model), validation_config)
control_load      <- load_param_file_safe(file_names$control, "02_Control.csv",
                                          default_file_for(file_names$control), validation_config)
setpoints_load    <- load_param_file_safe(file_names$temperature_setpoints,
                                          "12_Temperature_Setpoints.csv",
                                          default_file_for(file_names$temperature_setpoints),
                                          validation_config)
flex_events_load  <- load_param_file_safe(file_names$flexibility_events,
                                          "08_Flexibility_Event_Configuration.csv",
                                          default_file_for(file_names$flexibility_events),
                                          validation_config)
optimization_load <- load_param_file_safe(file_names$optimization, "01_Optimization_parameters.csv",
                                          default_file_for(file_names$optimization), validation_config)
market_load       <- load_param_file_safe(file_names$market, "03_Market_config.csv",
                                          default_file_for(file_names$market), validation_config)
reward_load       <- load_param_file_safe(file_names$reward, "09_Reward_parameters.csv",
                                          default_file_for(file_names$reward), validation_config)
reward_corr_load  <- load_param_file_safe(file_names$reward_corrections,
                                          "10_Reward_parameter_corrections.csv",
                                          default_file_for(file_names$reward_corrections),
                                          validation_config)
forecast_load     <- load_param_file_safe(file_names$forecast, "15_Forecast_parameters.csv",
                                          default_file_for(file_names$forecast), validation_config)
energy_price_load <- load_param_file_safe(file_names$energy_price, "06_Energy_price_parameters.csv",
                                          default_file_for(file_names$energy_price), validation_config)
flex_generation_load <- load_param_file_safe(file_names$flex_generation,
                                          "07_Flexibility_price_emulation_parameters.csv",
                                          default_file_for(file_names$flex_generation), validation_config)
debug_load        <- load_param_file_safe(file_names$debug, "16_Debug_and_config.csv",
                                          default_file_for(file_names$debug), validation_config)
# The four remaining tables (modes, the two market schedules, and
# occupancy) each have their own row-level safe loader instead of
# load_param_file_safe(), since a row (not a single value) is the
# reconciliation unit for these.
modes_load        <- load_modes_file_safe(file_names$modes, default_file_for(file_names$modes))
sched_load        <- load_market_table_file_safe(file_names$sched, default_file_for(file_names$sched),
                                                 gui_fallback$market_aim_scheduling)
pilot_load        <- load_market_table_file_safe(file_names$pilot, default_file_for(file_names$pilot),
                                                 gui_fallback$market_aim_piloting)
occupancy_load    <- load_occupancy_file_safe(file_names$occupancy, default_file_for(file_names$occupancy))

model_df           <- model_load$df
control_df         <- control_load$df
setpoints_df       <- setpoints_load$df
flex_events_df     <- flex_events_load$df
optimization_df    <- optimization_load$df
market_df          <- market_load$df
reward_df          <- reward_load$df
reward_corr_df     <- reward_corr_load$df
forecast_df        <- forecast_load$df
energy_price_df    <- energy_price_load$df
flex_generation_df <- flex_generation_load$df
debug_df           <- debug_load$df
modes_df           <- modes_load$df
sched_df           <- sched_load$df
pilot_df           <- pilot_load$df
occupancy_type_df  <- occupancy_load$day_types
occupancy_month_df <- occupancy_load$month_profiles

all_load_messages <- c(
  all_load_messages,
  model_load$messages, control_load$messages, setpoints_load$messages,
  flex_events_load$messages, optimization_load$messages,
  market_load$messages, reward_load$messages, reward_corr_load$messages,
  forecast_load$messages,
  energy_price_load$messages,
  flex_generation_load$messages, debug_load$messages, modes_load$messages,
  sched_load$messages, pilot_load$messages, occupancy_load$messages
)

load_warning_banner <- if (length(all_load_messages) > 0) {
  tags$div(
    style = paste(
      "background:#fff3cd; border:1px solid #ffeeba; color:#856404;",
      "padding:12px 15px; margin-bottom:15px; border-radius:4px;"
    ),
    tags$strong("Configuration loading notice:"),
    tags$ul(lapply(all_load_messages, function(m) tags$li(m)))
  )
} else {
  NULL
}

ui <- fluidPage(
  useShinyjs(),
  # Fields the simulation will not read with the current
  # Complex_Market_Config are shaded; the classes are switched by the
  # server as the value changes.
  tags$head(tags$style(HTML(paste(
    ".gui-unused input, .gui-unused .selectize-input {",
    "  background-color: #e9ecef !important; color: #868e96 !important; }",
    ".gui-basic input.table-cell-input[data-col='Market'],",
    ".gui-basic input.table-cell-input[data-col='begin'],",
    ".gui-basic input.table-cell-input[data-col='aim'] {",
    "  background-color: #e9ecef !important; color: #868e96 !important; }",
    ".gui-note { color: #6c757d; font-style: italic; margin-bottom: 8px; }"
  )))),
  titlePanel("MPC simulation configuration"),
  load_warning_banner,
  tabsetPanel(
    tabPanel(
      "Optimization",
      uiOutput("optimization_ui"),
      actionButton("save_optimization", "save", class = "btn-primary")
    ),
    tabPanel(
      "Control",
      build_group_editor(
        control_df,
        "control__",
        "Control Approach",
        c("control_type"),
        options_list = list(
          control_type = validation_options(validation_config, "02_Control.csv", "control_type")
        ),
        defaulted = control_load$defaulted,
        duplicated = control_load$duplicated,
        file_key = "02_Control.csv"
      ),
      build_group_editor(
        control_df,
        "control__",
        "Hysteresis",
        c("Deadband"),
        defaulted = control_load$defaulted,
        duplicated = control_load$duplicated,
        file_key = "02_Control.csv"
      ),
      build_group_editor(
        control_df,
        "control__",
        "Default Setpoints",
        c("set_point_default_heating", "set_point_default_cooling"),
        defaulted = control_load$defaulted,
        duplicated = control_load$duplicated,
        file_key = "02_Control.csv"
      ),
      build_group_editor(
        control_df,
        "control__",
        "Setpoints Beyond the Optimized Horizon",
        c("pad_heating", "pad_cooling"),
        defaulted = control_load$defaulted,
        duplicated = control_load$duplicated,
        file_key = "02_Control.csv"
      ),
      actionButton("save_control", "save", class = "btn-primary")
    ),
    tabPanel(
      "Market",
      build_group_editor(
        market_df,
        "market__",
        "Market definition",
        c("market_resolution", "Complex_Market_Config"),
        options_list = list(
          Complex_Market_Config = validation_options(
            validation_config, "03_Market_config.csv", "Complex_Market_Config"
          )
        ),
        defaulted = market_load$defaulted,
        duplicated = market_load$duplicated,
        file_key = "03_Market_config.csv"
      ),
      tags$div(
        id = "market_basic_only",
        tags$p(
          class = "gui-note",
          paste("Scheduling and Piloting markets: read only when Complex_Market_Config",
                "is no. With yes, the markets, their horizons and their aims come from",
                "the Market Schedules tabs, and these fields are shaded.")
        ),
        build_group_editor(
          market_df,
          "market__",
          "Scheduling Markets",
          c("Optimization_horizon_scheduling",
            "Implementation_horizon_scheduling",
            "Anticipation_scheduling", "optimization_aim_scheduling"),
          options_list = list(
            optimization_aim_scheduling = validation_options(
              validation_config, "03_Market_config.csv", "optimization_aim_scheduling"
            )
          ),
          defaulted = market_load$defaulted,
          duplicated = market_load$duplicated,
          file_key = "03_Market_config.csv"
        ),
        build_group_editor(
          market_df,
          "market__",
          "Piloting Markets",
          c("Optimization_horizon_piloting",
            "Implementation_horizon_piloting",
            "Anticipation_piloting", "optimization_aim_piloting"),
          options_list = list(
            optimization_aim_piloting = validation_options(
              validation_config, "03_Market_config.csv", "optimization_aim_piloting"
            )
          ),
          defaulted = market_load$defaulted,
          duplicated = market_load$duplicated,
          file_key = "03_Market_config.csv"
        ),
      ),
      build_group_editor(
        market_df,
        "market__",
        "Flexibility Price Emulation",
        c("Max_flex_periods_day", "Max_flex_com_price", "Max_flex_exec_price",
          "Max_flex_period_duration", "Max_flex_probability_down",
          "Max_flex_probability_up"),
        defaulted = market_load$defaulted,
        duplicated = market_load$duplicated,
        file_key = "03_Market_config.csv"
      ),
      actionButton("save_market", "save", class = "btn-primary")
    ),
    tabPanel(
      "Market Schedules (Scheduling)",
      tags$p(
        class = "gui-note",
        paste("With Complex_Market_Config = yes the whole table is read. With no,",
              "only closure, end and end_optimization are read: they set how far",
              "ahead the price and commitment matrices reach. Market, begin and aim",
              "are then shaded.")
      ),
      tags$div(id = "sched_wrap", DTOutput("sched_table")),
      actionButton("save_sched", "save", class = "btn-primary")
    ),
    tabPanel(
      "Market Schedules (Piloting)",
      tags$p(
        class = "gui-note",
        paste("With Complex_Market_Config = yes the whole table is read. With no,",
              "only closure, end and end_optimization are read: they set how far",
              "ahead the price and commitment matrices reach. Market, begin and aim",
              "are then shaded.")
      ),
      tags$div(id = "pilot_wrap", DTOutput("pilot_table")),
      actionButton("save_pilot", "save", class = "btn-primary")
    ),
    tabPanel(
      "Full Market Emulation. Energy",
      uiOutput("energy_price_ui"),
      actionButton("save_energy_price", "save", class = "btn-primary")
    ),
    tabPanel(
      "Full Market Emulation. Flexibility Price",
      uiOutput("flex_generation_ui"),
      actionButton("save_flex_generation", "save", class = "btn-primary")
    ),
    tabPanel(
      "Full Market Emulation. Flexibility Events",
      build_group_editor(
        flex_events_df,
        "flexev__",
        "Phases of an Event",
        c("commitment_phase_length_max", "neutral_phase_timespan",
          "recovery_phase_timespan", "minimum_flexibility"),
        defaulted = flex_events_load$defaulted,
        duplicated = flex_events_load$duplicated,
        file_key = "08_Flexibility_Event_Configuration.csv"
      ),
      build_group_editor(
        flex_events_df,
        "flexev__",
        "Convergence of the Recovery Phase",
        c("recovery_convergence_window", "recovery_convergence_tol_rel",
          "recovery_convergence_tol_abs"),
        defaulted = flex_events_load$defaulted,
        duplicated = flex_events_load$duplicated,
        file_key = "08_Flexibility_Event_Configuration.csv"
      ),
      build_group_editor(
        flex_events_df,
        "flexev__",
        "System of an Upward Event",
        c("flex_up_horizon_long", "flex_up_horizon_short",
          "flex_up_dominance_threshold", "flex_up_max_power_heating"),
        options_list = list(
          flex_up_max_power_heating = validation_options(
            validation_config, "08_Flexibility_Event_Configuration.csv",
            "flex_up_max_power_heating"
          )
        ),
        defaulted = flex_events_load$defaulted,
        duplicated = flex_events_load$duplicated,
        file_key = "08_Flexibility_Event_Configuration.csv"
      ),
      build_group_editor(
        flex_events_df,
        "flexev__",
        "Feasibility of a Window and Commitment",
        c("flex_feasibility_tolerance", "flex_feasibility_floor",
          "flex_restatement_tol", "flexibility_commitment_margin"),
        defaulted = flex_events_load$defaulted,
        duplicated = flex_events_load$duplicated,
        file_key = "08_Flexibility_Event_Configuration.csv"
      ),
      actionButton("save_flexibility_events", "save", class = "btn-primary")
    ),
    tabPanel(
      "Reward Function",
      uiOutput("reward_ui"),
      actionButton("save_reward", "save", class = "btn-primary")
    ),
    tabPanel(
      "Reward Corrections",
      uiOutput("reward_corrections_ui"),
      actionButton("save_reward_corrections", "save", class = "btn-primary")
    ),
    tabPanel(
      "Model",
      build_group_editor(
        model_df,
        "model__",
        "Building Inertia",
        c("Ci", "Ce", "Rie", "Rea", "Aw", "Ae"),
        defaulted = model_load$defaulted,
        duplicated = model_load$duplicated,
        file_key = "11_Model_parameters.csv"
      ),
      build_group_editor(
        model_df,
        "model__",
        "Shading",
        c("Shading_0", "Shading_1", "Setpoint_Shading1"),
        defaulted = model_load$defaulted,
        duplicated = model_load$duplicated,
        file_key = "11_Model_parameters.csv"
      ),
      build_group_editor(
        model_df,
        "model__",
        "Heat Pump",
        c("AT_hp_heat_1", "AT_hp_heat_2", "Q_hp_heat_1", "Q_hp_heat_2",
          "COP_hp_heat_1_coef1", "COP_hp_heat_1_coef2",
          "COP_hp_heat_1_coef3", "Tsup_hp_heat",
          "Text_ref_hp_heat", "Tsup_ref_hp_heat", "Q_hp_cool",
          "COP_hp_cool"),
        defaulted = model_load$defaulted,
        duplicated = model_load$duplicated,
        file_key = "11_Model_parameters.csv"
      ),
      build_group_editor(
        model_df,
        "model__",
        "Ventilation",
        c("RENvent01", "RENvent1", "RENvent2",
          "Setpoint_Rvent1", "Volume", "Efi_Vent_Rec"),
        defaulted = model_load$defaulted,
        duplicated = model_load$duplicated,
        file_key = "11_Model_parameters.csv"
      ),
      build_group_editor(
        model_df,
        "model__",
        "Initialization",
        c("Ti_0", "Te_0", "Qh_0", "Qc_0"),
        defaulted = model_load$defaulted,
        duplicated = model_load$duplicated,
        file_key = "11_Model_parameters.csv"
      ),
      build_group_editor(
        model_df,
        "model__",
        "Heat Distribution",
        c("inertial_fact"),
        defaulted = model_load$defaulted,
        duplicated = model_load$duplicated,
        file_key = "11_Model_parameters.csv"
      ),
      actionButton("save_model", "save", class = "btn-primary")
    ),
    tabPanel(
      "Temperature Setpoints",
      build_group_editor(
        setpoints_df,
        "setpoints__",
        "Acceptable Setpoint Range (setpoints control only)",
        c("set_point_range_heating_low", "set_point_range_heating_high",
          "set_point_range_cooling_low", "set_point_range_cooling_high"),
        defaulted = setpoints_load$defaulted,
        duplicated = setpoints_load$duplicated,
        file_key = "12_Temperature_Setpoints.csv"
      ),
      actionButton("save_temperature_setpoints", "save", class = "btn-primary")
    ),
    tabPanel(
      "Modes",
      DTOutput("modes_table"),
      actionButton("save_modes", "save", class = "btn-primary")
    ),
    tabPanel(
      "Occupancy",
      h4("Day Type Profiles [0/1 per hour]"),
      DTOutput("occupancy_type_table"),
      h4("Monthly Weekday Mapping [TYPE reference per weekday]"),
      DTOutput("occupancy_month_table"),
      actionButton("save_occupancy", "save", class = "btn-primary")
    ),
    tabPanel(
      "Forecasting",
      uiOutput("forecast_ui"),
      actionButton("save_forecast", "save", class = "btn-primary")
    ),
    tabPanel(
      "Configuration and Debug",
      uiOutput("debug_ui"),
      actionButton("save_debug", "save", class = "btn-primary")
    )
  ),
  br(),
  uiOutput("msg_save")
)

server <- function(input, output, session) {

  rv <- reactiveValues(
    model           = model_df,
    occupancy_type  = occupancy_type_df,
    occupancy_month = occupancy_month_df,
    control         = control_df,
    setpoints       = setpoints_df,
    flex_events     = flex_events_df,
    modes           = modes_df,
    optimization    = optimization_df,
    market          = market_df,
    sched           = sched_df,
    pilot           = pilot_df,
    reward          = reward_df,
    reward_corr     = reward_corr_df,
    forecast        = forecast_df,
    energy_price    = energy_price_df,
    flex_generation = flex_generation_df,
    debug           = debug_df,

    model_defaulted        = model_load$defaulted,
    control_defaulted      = control_load$defaulted,
    setpoints_defaulted    = setpoints_load$defaulted,
    flex_events_defaulted  = flex_events_load$defaulted,
    optimization_defaulted = optimization_load$defaulted,
    market_defaulted       = market_load$defaulted,
    reward_defaulted       = reward_load$defaulted,
    reward_corr_defaulted  = reward_corr_load$defaulted,
    forecast_defaulted     = forecast_load$defaulted,
    energy_price_defaulted = energy_price_load$defaulted,
    flex_generation_defaulted = flex_generation_load$defaulted,
    debug_defaulted        = debug_load$defaulted,

    model_duplicated        = model_load$duplicated,
    control_duplicated      = control_load$duplicated,
    setpoints_duplicated    = setpoints_load$duplicated,
    flex_events_duplicated  = flex_events_load$duplicated,
    optimization_duplicated = optimization_load$duplicated,
    market_duplicated       = market_load$duplicated,
    reward_duplicated       = reward_load$duplicated,
    reward_corr_duplicated  = reward_corr_load$duplicated,
    forecast_duplicated     = forecast_load$duplicated,
    energy_price_duplicated = energy_price_load$duplicated,
    flex_generation_duplicated = flex_generation_load$duplicated,
    debug_duplicated        = debug_load$duplicated,

    modes_defaulted_rows           = modes_load$defaulted_rows,
    sched_defaulted_rows           = sched_load$defaulted_rows,
    pilot_defaulted_rows           = pilot_load$defaulted_rows,
    occupancy_type_defaulted_rows  = occupancy_load$defaulted_type_rows,
    occupancy_month_defaulted_rows = occupancy_load$defaulted_month_rows
  )

  output$optimization_ui <- renderUI({
    build_param_editor(rv$optimization, "opt__", max_per_row = 4,
                       defaulted = rv$optimization_defaulted,
                       duplicated = rv$optimization_duplicated,
                       file_key = "01_Optimization_parameters.csv")
  })

  output$reward_ui <- renderUI({
    tagList(
      build_group_editor(
        rv$reward,
        "reward__",
        "Weights",
        c("alpha_comfort", "alpha_cost"),
        defaulted = rv$reward_defaulted,
        duplicated = rv$reward_duplicated,
        file_key = "09_Reward_parameters.csv"
      ),
      build_group_editor(
        rv$reward,
        "reward__",
        "Comfort Band",
        c("Service_T_Low", "Service_T_High", "Setback_T_Low", "Setback_T_High"),
        defaulted = rv$reward_defaulted,
        duplicated = rv$reward_duplicated,
        file_key = "09_Reward_parameters.csv"
      ),
      build_group_editor(
        rv$reward,
        "reward__",
        "Revenue Discount",
        c("Revenue_discount_per_hour"),
        defaulted = rv$reward_defaulted,
        duplicated = rv$reward_duplicated,
        file_key = "09_Reward_parameters.csv"
      )
    )
  })

  output$reward_corrections_ui <- renderUI({
    tagList(
      build_group_editor(
        rv$reward_corr,
        "rewardcorr__",
        "Scheduling",
        c("Service_Anticipation_Begin", "Service_Anticipation_End",
          "Service_AT_Low_Sched_HDD", "Service_AT_High_Sched_CDD"),
        defaulted = rv$reward_corr_defaulted,
        duplicated = rv$reward_corr_duplicated,
        file_key = "10_Reward_parameter_corrections.csv"
      ),
      build_group_editor(
        rv$reward_corr,
        "rewardcorr__",
        "Climate Correction for Scheduling",
        c("T_ref_Heating_Season", "HDD_period", "T_ref_Cooling_Season", "CDD_period"),
        defaulted = rv$reward_corr_defaulted,
        duplicated = rv$reward_corr_duplicated,
        file_key = "10_Reward_parameter_corrections.csv"
      )
    )
  })

  output$forecast_ui <- renderUI({
    build_param_editor(
      rv$forecast,
      "forecast__",
      options_list = list(
        weather_forecast_type = c("accurate", "inaccurate"),
        price_forecast_type   = c("accurate", "inaccurate")
      ),
      defaulted = rv$forecast_defaulted,
      duplicated = rv$forecast_duplicated,
      file_key = "15_Forecast_parameters.csv"
    )
  })

  output$energy_price_ui <- renderUI({
    build_param_editor(rv$energy_price, "energyprice__", defaulted = rv$energy_price_defaulted,
                       duplicated = rv$energy_price_duplicated,
                       file_key = "06_Energy_price_parameters.csv")
  })

  output$flex_generation_ui <- renderUI({
    build_param_editor(rv$flex_generation, "flexgen__", defaulted = rv$flex_generation_defaulted,
                       duplicated = rv$flex_generation_duplicated,
                       file_key = "07_Flexibility_price_emulation_parameters.csv")
  })

  output$debug_ui <- renderUI({
    build_param_editor(
      rv$debug,
      "debug__",
      options_list = debug_flag_options,
      defaulted = rv$debug_defaulted,
      duplicated = rv$debug_duplicated,
      file_key = "16_Debug_and_config.csv"
    )
  })

  output$modes_table <- renderDT({
    display_df <- build_table_cell_inputs(rv$modes, "modes",
                                          defaulted_rows = rv$modes_defaulted_rows,
                                          readonly_cols = "mode")
    datatable(
      display_df,
      rownames = FALSE,
      escape   = FALSE,
      editable = FALSE,
      callback = table_input_callback,
      colnames = sapply(names(display_df), label_with_unit,
                        file_key = "13_Modes_setpoints.csv", USE.NAMES = FALSE),
      options  = list(dom = "t", ordering = FALSE,
                      pageLength = max(1, nrow(display_df)))
    )
  })

  output$occupancy_type_table <- renderDT({
    display_df <- build_table_cell_inputs(rv$occupancy_type, "occupancy_type",
                                          defaulted_rows = rv$occupancy_type_defaulted_rows)
    datatable(
      display_df,
      rownames = FALSE,
      escape   = FALSE,
      editable = FALSE,
      callback = table_input_callback,
      options  = list(dom = "t", ordering = FALSE,
                      pageLength = max(1, nrow(display_df)))
    )
  })

  output$occupancy_month_table <- renderDT({
    display_df <- build_table_cell_inputs(rv$occupancy_month, "occupancy_month",
                                          defaulted_rows = rv$occupancy_month_defaulted_rows)
    datatable(
      display_df,
      rownames = FALSE,
      escape   = FALSE,
      editable = FALSE,
      callback = table_input_callback,
      options  = list(dom = "t", ordering = FALSE,
                      pageLength = max(1, nrow(display_df)))
    )
  })

  # Shade what the simulation will not read with the current
  # Complex_Market_Config: the horizons and aims of the Market tab when
  # it is yes, and the Market, begin and aim columns of the two
  # schedule tables when it is no.
  observe({
    complex_now <- input$market__Complex_Market_Config
    if (is.null(complex_now)) {
      complex_now <- get_param_value(rv$market, "Complex_Market_Config")
    }
    complex_now <- tolower(trimws(as.character(complex_now)))
    toggleClass(id = "market_basic_only", class = "gui-unused",
                condition = identical(complex_now, "yes"))
    toggleClass(id = "sched_wrap", class = "gui-basic",
                condition = identical(complex_now, "no"))
    toggleClass(id = "pilot_wrap", class = "gui-basic",
                condition = identical(complex_now, "no"))
  })

  output$sched_table <- renderDT({
    display_df <- build_table_cell_inputs(rv$sched, "sched",
                                          defaulted_rows = rv$sched_defaulted_rows)
    datatable(
      display_df,
      rownames = FALSE,
      escape   = FALSE,
      editable = FALSE,
      callback = table_input_callback,
      colnames = sapply(names(display_df), label_with_unit,
                        file_key = "04_Market_config_scheduling.csv", USE.NAMES = FALSE),
      options  = list(dom = "t", ordering = FALSE,
                      pageLength = max(1, nrow(display_df)))
    )
  })

  output$pilot_table <- renderDT({
    display_df <- build_table_cell_inputs(rv$pilot, "pilot",
                                          defaulted_rows = rv$pilot_defaulted_rows)
    datatable(
      display_df,
      rownames = FALSE,
      escape   = FALSE,
      editable = FALSE,
      callback = table_input_callback,
      colnames = sapply(names(display_df), label_with_unit,
                        file_key = "05_Market_config_piloting.csv", USE.NAMES = FALSE),
      options  = list(dom = "t", ordering = FALSE,
                      pageLength = max(1, nrow(display_df)))
    )
  })

  observeEvent(input$modes_cell_text_edit, {
    rv$modes <- apply_text_table_edit(rv$modes, input$modes_cell_text_edit)
  })

  observeEvent(input$occupancy_type_cell_text_edit, {
    rv$occupancy_type <- apply_text_table_edit(
      rv$occupancy_type,
      input$occupancy_type_cell_text_edit
    )
  })

  observeEvent(input$occupancy_month_cell_text_edit, {
    rv$occupancy_month <- apply_text_table_edit(
      rv$occupancy_month,
      input$occupancy_month_cell_text_edit
    )
  })

  observeEvent(input$sched_cell_text_edit, {
    rv$sched <- apply_text_table_edit(rv$sched, input$sched_cell_text_edit)
  })

  observeEvent(input$pilot_cell_text_edit, {
    rv$pilot <- apply_text_table_edit(rv$pilot, input$pilot_cell_text_edit)
  })

  observeEvent(input$modes_add_above, {
    template <- rv$modes[max(1, input$modes_add_above), , drop = FALSE]
    rv$modes <- insert_row(rv$modes, input$modes_add_above, template)
    rv$modes$mode <- seq_len(nrow(rv$modes))
  })

  observeEvent(input$modes_add_below, {
    template <- rv$modes[max(1, input$modes_add_below), , drop = FALSE]
    rv$modes <- insert_row(rv$modes, input$modes_add_below + 1, template)
    rv$modes$mode <- seq_len(nrow(rv$modes))
  })

  observeEvent(input$modes_delete, {
    if (nrow(rv$modes) <= 1) {
      return()
    }
    rv$modes <- rv$modes[-input$modes_delete, , drop = FALSE]
    rv$modes$mode <- seq_len(nrow(rv$modes))
  })

  observeEvent(input$occupancy_type_add_above, {
    template <- rv$occupancy_type[max(1, input$occupancy_type_add_above), ,
                                  drop = FALSE]
    rv$occupancy_type <- insert_row(
      rv$occupancy_type,
      input$occupancy_type_add_above,
      template
    )
  })

  observeEvent(input$occupancy_type_add_below, {
    template <- rv$occupancy_type[max(1, input$occupancy_type_add_below), ,
                                  drop = FALSE]
    rv$occupancy_type <- insert_row(
      rv$occupancy_type,
      input$occupancy_type_add_below + 1,
      template
    )
  })

  observeEvent(input$occupancy_type_delete, {
    if (nrow(rv$occupancy_type) <= 1) {
      return()
    }
    rv$occupancy_type <- rv$occupancy_type[-input$occupancy_type_delete, ,
                                           drop = FALSE]
  })

  observeEvent(input$occupancy_month_add_above, {
    template <- rv$occupancy_month[max(1, input$occupancy_month_add_above), ,
                                   drop = FALSE]
    rv$occupancy_month <- insert_row(
      rv$occupancy_month,
      input$occupancy_month_add_above,
      template
    )
  })

  observeEvent(input$occupancy_month_add_below, {
    template <- rv$occupancy_month[max(1, input$occupancy_month_add_below), ,
                                   drop = FALSE]
    rv$occupancy_month <- insert_row(
      rv$occupancy_month,
      input$occupancy_month_add_below + 1,
      template
    )
  })

  observeEvent(input$occupancy_month_delete, {
    if (nrow(rv$occupancy_month) <= 1) {
      return()
    }
    rv$occupancy_month <- rv$occupancy_month[-input$occupancy_month_delete, ,
                                             drop = FALSE]
  })

  observeEvent(input$sched_add_above, {
    template <- rv$sched[max(1, input$sched_add_above), , drop = FALSE]
    rv$sched <- insert_row(rv$sched, input$sched_add_above, template)
  })

  observeEvent(input$sched_add_below, {
    template <- rv$sched[max(1, input$sched_add_below), , drop = FALSE]
    rv$sched <- insert_row(rv$sched, input$sched_add_below + 1, template)
  })

  observeEvent(input$sched_delete, {
    if (nrow(rv$sched) <= 1) {
      return()
    }
    rv$sched <- rv$sched[-input$sched_delete, , drop = FALSE]
  })

  observeEvent(input$pilot_add_above, {
    template <- rv$pilot[max(1, input$pilot_add_above), , drop = FALSE]
    rv$pilot <- insert_row(rv$pilot, input$pilot_add_above, template)
  })

  observeEvent(input$pilot_add_below, {
    template <- rv$pilot[max(1, input$pilot_add_below), , drop = FALSE]
    rv$pilot <- insert_row(rv$pilot, input$pilot_add_below + 1, template)
  })

  observeEvent(input$pilot_delete, {
    if (nrow(rv$pilot) <= 1) {
      return()
    }
    rv$pilot <- rv$pilot[-input$pilot_delete, , drop = FALSE]
  })

  save_all <- function() {
    tryCatch(
      {
        # flush_table_edits() pulls in any pending cell edits from the
        # DT tables (modes/occupancy) before the parameter tabs below
        # are read from their individual Shiny inputs, so nothing
        # entered by the user is lost regardless of which tab is
        # currently open when "save" is pressed.
        flush_table_edits(rv, input)

        # update_df_from_inputs() re-reads every widget's current
        # value back into its reactive data frame - one call per tab,
        # all sharing the same pattern (widget input -> df$value).
        rv$model        <- update_df_from_inputs(rv$model, "model__", input)
        rv$control      <- update_df_from_inputs(rv$control, "control__", input)
        rv$setpoints    <- update_df_from_inputs(rv$setpoints, "setpoints__", input)
        rv$flex_events  <- update_df_from_inputs(rv$flex_events, "flexev__", input)
        rv$optimization <- update_df_from_inputs(rv$optimization, "opt__", input)
        rv$market       <- update_df_from_inputs(rv$market, "market__", input)
        rv$reward       <- update_df_from_inputs(rv$reward, "reward__", input)
        rv$reward_corr  <- update_df_from_inputs(rv$reward_corr, "rewardcorr__", input)
        rv$forecast     <- update_df_from_inputs(rv$forecast, "forecast__", input)
        rv$energy_price <- update_df_from_inputs(rv$energy_price, "energyprice__", input)
        rv$flex_generation <- update_df_from_inputs(rv$flex_generation, "flexgen__", input)
        rv$debug        <- update_df_from_inputs(rv$debug, "debug__", input)

        rv$occupancy_type[]  <- lapply(rv$occupancy_type, as.character)
        rv$occupancy_month[] <- lapply(rv$occupancy_month, as.character)

        # ---- Validate everything before writing anything ----
        # Every tab is validated against the same Parameter_config.csv
        # rules used by the real simulation pipeline, before any file
        # on disk is touched, so a single invalid value in one tab
        # cannot leave the configuration half-written.
        validation_errors <- c(
          validate_param_df_gui(rv$model, "11_Model_parameters.csv", validation_config),
          validate_param_df_gui(rv$control, "02_Control.csv", validation_config),
          validate_param_df_gui(rv$setpoints, "12_Temperature_Setpoints.csv", validation_config),
          validate_param_df_gui(rv$flex_events, "08_Flexibility_Event_Configuration.csv",
                                validation_config),
          validate_param_df_gui(rv$optimization, "01_Optimization_parameters.csv", validation_config),
          validate_param_df_gui(rv$market, "03_Market_config.csv", validation_config),
          validate_param_df_gui(rv$reward, "09_Reward_parameters.csv", validation_config),
          validate_param_df_gui(rv$reward_corr, "10_Reward_parameter_corrections.csv",
                                validation_config),
          validate_param_df_gui(rv$forecast, "15_Forecast_parameters.csv", validation_config),
          validate_param_df_gui(rv$energy_price, "06_Energy_price_parameters.csv", validation_config),
          validate_param_df_gui(rv$flex_generation, "07_Flexibility_price_emulation_parameters.csv", validation_config),
          validate_param_df_gui(rv$debug, "16_Debug_and_config.csv", validation_config),
          validate_modes_df_gui(rv$modes),
          validate_market_table_df_gui(rv$sched, "04_Market_config_scheduling.csv"),
          validate_market_table_df_gui(rv$pilot, "05_Market_config_piloting.csv"),
          validate_occupancy_dfs_gui(rv$occupancy_type, rv$occupancy_month)
        )

        if (length(validation_errors) > 0) {
          output$msg_save <- renderUI(
            tags$div(
              style = "color:#c0392b; white-space:pre-wrap;",
              tags$strong("✖ Nothing was saved. Fix these values:"),
              tags$ul(lapply(validation_errors, function(m) tags$li(m)))
            )
          )
          return(invisible(NULL))
        }

        rv$modes$mode <- seq_len(nrow(rv$modes))

        # All validation above passed, so every tab is now written to
        # its configuration file on disk:
        #   - write_param_file() for flat "parameter,value,unit" files
        #   - write_table_file() for the modes/market-schedule tables
        #   - write_use_patterns_file() for the two-block occupancy
        #     file
        write_param_file(
          file_names$model,
          "# Physical and thermal parameters of the building and HVAC system",
          rv$model
        )
        write_use_patterns_file(
          file_names$occupancy,
          rv$occupancy_type,
          rv$occupancy_month
        )
        write_param_file(
          file_names$control,
          "# Control parameters",
          rv$control
        )
        write_param_file(
          file_names$temperature_setpoints,
          "# Temperature setpoint parameters",
          rv$setpoints
        )
        write_param_file(
          file_names$flexibility_events,
          "# Flexibility event configuration",
          rv$flex_events
        )
        write_param_file(
          file_names$optimization,
          "# Optimization and MPC horizon parameters",
          rv$optimization
        )
        write_param_file(
          file_names$market,
          "# Market definition and horizon parameters",
          rv$market
        )
        write_table_file(
          file_names$modes,
          "# Setpoint modes & associated heating and cooling setpoints",
          rv$modes
        )
        write_table_file(
          file_names$sched,
          "# Market configuration table",
          rv$sched
        )
        write_table_file(
          file_names$pilot,
          "# Market configuration table",
          rv$pilot
        )
        write_param_file(
          file_names$reward,
          "# Reward function parameters",
          rv$reward
        )
        write_param_file(
          file_names$reward_corrections,
          "# Reward parameter corrections",
          rv$reward_corr
        )
        write_param_file(
          file_names$forecast,
          "# Weather forecast parameters",
          rv$forecast
        )
        write_param_file(
          file_names$energy_price,
          "# Energy market price discount/premium parameters",
          rv$energy_price
        )
        write_param_file(
          file_names$flex_generation,
          "# Market-aware flexibility generation parameters (Complex_Market_Config == \"yes\" only)",
          rv$flex_generation
        )
        write_param_file(
          file_names$debug,
          "# Debug and configuration parameters",
          rv$debug
        )

        # Values just written are the user's deliberate choice, not
        # leftover defaults or duplicates: clear every "defaulted" and
        # "duplicated" flag so the red highlighting disappears now
        # that it has been persisted.
        rv$model_defaulted        <- character(0)
        rv$control_defaulted      <- character(0)
        rv$setpoints_defaulted    <- character(0)
        rv$flex_events_defaulted  <- character(0)
        rv$optimization_defaulted <- character(0)
        rv$market_defaulted       <- character(0)
        rv$reward_defaulted       <- character(0)
        rv$reward_corr_defaulted  <- character(0)
        rv$forecast_defaulted     <- character(0)
        rv$energy_price_defaulted <- character(0)
        rv$flex_generation_defaulted <- character(0)
        rv$debug_defaulted        <- character(0)
        rv$model_duplicated        <- character(0)
        rv$control_duplicated      <- character(0)
        rv$setpoints_duplicated    <- character(0)
        rv$flex_events_duplicated  <- character(0)
        rv$optimization_duplicated <- character(0)
        rv$market_duplicated       <- character(0)
        rv$reward_duplicated       <- character(0)
        rv$reward_corr_duplicated  <- character(0)
        rv$forecast_duplicated     <- character(0)
        rv$energy_price_duplicated <- character(0)
        rv$flex_generation_duplicated <- character(0)
        rv$debug_duplicated        <- character(0)
        rv$modes_defaulted_rows           <- integer(0)
        rv$sched_defaulted_rows           <- integer(0)
        rv$pilot_defaulted_rows           <- integer(0)
        rv$occupancy_type_defaulted_rows  <- integer(0)
        rv$occupancy_month_defaulted_rows <- integer(0)

        output$msg_save <- renderUI(
          tags$div(
            style = "color:#1e7e34;",
            paste("✔ All configuration files saved in:", config_path)
          )
        )
      },
      error = function(e) {
        output$msg_save <- renderUI(
          tags$div(
            style = "color:#c0392b;",
            paste("Error while saving configuration files:", e$message)
          )
        )
      }
    )
  }

  save_buttons <- c(
    "save_model", "save_occupancy", "save_control", "save_temperature_setpoints",
    "save_modes", "save_flexibility_events",
    "save_optimization", "save_market", "save_sched", "save_pilot",
    "save_reward", "save_reward_corrections", "save_forecast", "save_energy_price", "save_flex_generation", "save_debug"
  )

  for (CONT_004 in save_buttons) {
    local({
      button_id <- CONT_004
      observeEvent(input[[button_id]], {
        # Every "save" button triggers the same save_all(): it always
        # validates and writes the whole configuration at once, not
        # just the tab the button belongs to (see the "Clear scope for
        # save actions" rule in 00_Base_Criteria.md).
        save_all()
      })
    })
  }
}

shinyApp(ui = ui, server = server)
