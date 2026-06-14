# -------------------------------------------------------------
# Script: GUI_config.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK5
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Shiny interface for editing and saving simulation
# configuration files in 30_Simulation/02_Config.
# The interface reads parameter files and editable tables,
# keeps the reactive state synchronized with user edits,
# and writes all configuration files when the save button
# of any tab is pressed.
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

file_names <- list(
  model        = "11_Model_parameters.csv",
  occupancy    = "04_Use_Patterns.csv",
  control      = "12_Control_parameters.csv",
  modes        = "13_Modes_setpoints.csv",
  optimization = "14_Optimization_parameters.csv",
  market       = "15_Market_config.csv",
  sched        = "16_Market_config_scheduling.csv",
  pilot        = "17_Market_config_piloting.csv",
  reward       = "18_Reward_parameters.csv",
  forecast     = "19_Forecast_parameters.csv",
  flex_price   = "20_Flex_price_simulation.csv",
  debug        = "30_Debug_and_config.csv"
)

read_param_file <- function(filename) {
  read.csv(
    file.path(config_path, filename),
    comment.char     = "#",
    stringsAsFactors = FALSE,
    strip.white      = TRUE
  )
}

read_table_file <- function(filename) {
  df <- read.csv(
    file.path(config_path, filename),
    comment.char     = "#",
    stringsAsFactors = FALSE,
    strip.white      = TRUE
  )
  if (nrow(df) > 0 && "Market" %in% names(df)) {
    first_market_value <- tolower(trimws(as.character(df$Market[1])))
    if (identical(first_market_value, "texto")) {
      df <- df[-1, , drop = FALSE]
    }
  }
  df
}

read_use_patterns_file <- function(filename) {
  full_path <- file.path(config_path, filename)
  raw_lines <- readLines(full_path, warn = FALSE)
  raw_lines <- raw_lines[
    !grepl("^\\s*#", raw_lines) & nzchar(trimws(raw_lines))
  ]
  
  type_header_idx <- which(grepl("^\\s*TYPE\\s*,",
                                 raw_lines,
                                 ignore.case = TRUE))[1]
  month_header_idx <- which(grepl("^\\s*MONTH\\s*,",
                                  raw_lines,
                                  ignore.case = TRUE))[1]
  
  if (is.na(type_header_idx) || is.na(month_header_idx)) {
    stop("04_Use_Patterns.csv must contain TYPE and MONTH table headers")
  }
  
  type_lines  <- raw_lines[type_header_idx:(month_header_idx - 1)]
  month_lines <- raw_lines[month_header_idx:length(raw_lines)]
  
  day_types <- read.csv(
    text             = paste(type_lines, collapse = "\n"),
    stringsAsFactors = FALSE,
    strip.white      = TRUE
  )
  month_profiles <- read.csv(
    text             = paste(month_lines, collapse = "\n"),
    stringsAsFactors = FALSE,
    strip.white      = TRUE
  )
  
  if (nrow(day_types) > 0 &&
      tolower(trimws(as.character(day_types$TYPE[1]))) == "texto") {
    day_types <- day_types[-1, , drop = FALSE]
  }
  if (nrow(month_profiles) > 0 &&
      tolower(trimws(as.character(month_profiles$MONTH[1]))) == "texto") {
    month_profiles <- month_profiles[-1, , drop = FALSE]
  }
  
  list(day_types = day_types, month_profiles = month_profiles)
}

write_use_patterns_file <- function(
    filename,
    day_types_df,
    month_profiles_df
) {
  con <- file(file.path(config_path, filename), open = "wt")
  on.exit(close(con), add = TRUE)
  
  writeLines(
    c(
      "# Occupancy use patterns configuration file",
      "# -------------------------------------------------------------",
      "# Day type profiles by hour"
    ),
    con
  )
  
  write.csv(
    rbind(
      setNames(
        as.data.frame(
          as.list(c("texto", rep("0/1", max(0, ncol(day_types_df) - 1)))),
          stringsAsFactors = FALSE
        ),
        names(day_types_df)
      ),
      day_types_df
    ),
    con,
    row.names = FALSE,
    quote = FALSE
  )
  
  writeLines(
    c(
      "",
      "# -------------------------------------------------------------",
      "# Monthly mapping by weekday (D01 = Monday, D07 = Sunday)"
    ),
    con
  )
  
  write.csv(
    rbind(
      setNames(
        as.data.frame(
          as.list(c("texto", rep("perfil",
                                 max(0, ncol(month_profiles_df) - 1)))),
          stringsAsFactors = FALSE
        ),
        names(month_profiles_df)
      ),
      month_profiles_df
    ),
    con,
    row.names = FALSE,
    quote = FALSE
  )
}

write_param_file <- function(filename, header, df) {
  con <- file(file.path(config_path, filename), open = "wt")
  on.exit(close(con), add = TRUE)
  
  writeLines(header, con)
  write.csv(df, con, row.names = FALSE, quote = FALSE)
}

write_table_file <- function(filename, header, df) {
  con <- file(file.path(config_path, filename), open = "wt")
  on.exit(close(con), add = TRUE)
  
  writeLines(header, con)
  write.csv(df, con, row.names = FALSE, quote = FALSE)
}

get_param_value <- function(df, param) {
  value <- df$value[df$parameter == param]
  if (length(value) == 0) {
    return("")
  }
  as.character(value[1])
}

update_df_from_inputs <- function(df, prefix, input) {
  for (CONT_001 in seq_len(nrow(df))) {
    param_name <- as.character(df$parameter[CONT_001])
    input_id   <- paste0(prefix, param_name)
    if (!is.null(input[[input_id]])) {
      df$value[CONT_001] <- as.character(input[[input_id]])
    }
  }
  df
}

insert_row <- function(df, index, template_row) {
  if (nrow(df) == 0) {
    return(template_row)
  }
  
  index <- max(1, min(index, nrow(df) + 1))
  
  if (index == 1) {
    return(rbind(template_row, df))
  }
  
  if (index == nrow(df) + 1) {
    return(rbind(df, template_row))
  }
  
  rbind(
    df[1:(index - 1), , drop = FALSE],
    template_row,
    df[index:nrow(df), , drop = FALSE]
  )
}

add_row_controls <- function(df, prefix) {
  if (nrow(df) == 0) {
    df <- data.frame(stringsAsFactors = FALSE)
  }
  
  n_rows <- nrow(df)
  if (n_rows > 0) {
    df$`Add above` <- sprintf(
      "<a href='#' onclick=\"Shiny.setInputValue('%s_add_above', %d, {priority: 'event'});\">Add above</a>",
      prefix,
      seq_len(n_rows)
    )
    df$`Add below` <- sprintf(
      "<a href='#' onclick=\"Shiny.setInputValue('%s_add_below', %d, {priority: 'event'});\">Add below</a>",
      prefix,
      seq_len(n_rows)
    )
    df$`Delete` <- sprintf(
      "<a href='#' onclick=\"Shiny.setInputValue('%s_delete', %d, {priority: 'event'});\">Delete</a>",
      prefix,
      seq_len(n_rows)
    )
  }
  
  df
}

escape_html_attr <- function(value) {
  value <- as.character(value)
  value <- gsub("&", "&amp;", value, fixed = TRUE)
  value <- gsub("\"", "&quot;", value, fixed = TRUE)
  value <- gsub("<", "&lt;", value, fixed = TRUE)
  value <- gsub(">", "&gt;", value, fixed = TRUE)
  value
}

build_input_grid <- function(input_defs, max_per_row = 4) {
  if (length(input_defs) == 0) {
    return(NULL)
  }
  
  row_groups <- split(
    input_defs,
    ceiling(seq_along(input_defs) / max_per_row)
  )
  
  tags$div(
    lapply(
      row_groups,
      function(row_items) {
        fluidRow(
          lapply(
            row_items,
            function(item) {
              column(
                width = floor(12 / max_per_row),
                if (!is.null(item$options)) {
                  selectInput(
                    inputId  = item$id,
                    label    = item$label,
                    choices  = item$options,
                    selected = item$value
                  )
                } else {
                  textInput(
                    inputId = item$id,
                    label   = item$label,
                    value   = item$value
                  )
                }
              )
            }
          )
        )
      }
    )
  )
}

build_param_editor <- function(df, prefix, max_per_row = 1, options_list = list()) {
  input_defs <- lapply(
    seq_len(nrow(df)),
    function(CONT_002) {
      param_name <- as.character(df$parameter[CONT_002])
      list(
        id      = paste0(prefix, param_name),
        label   = param_name,
        value   = as.character(df$value[CONT_002]),
        options = options_list[[param_name]]
      )
    }
  )
  
  if (max_per_row <= 1) {
    return(
      tags$div(
        lapply(
          input_defs,
          function(item) {
            if (!is.null(item$options)) {
              selectInput(
                inputId  = item$id,
                label    = item$label,
                choices  = item$options,
                selected = item$value
              )
            } else {
              textInput(
                inputId = item$id,
                label   = item$label,
                value   = item$value
              )
            }
          }
        )
      )
    )
  }
  
  build_input_grid(input_defs, max_per_row = max_per_row)
}

build_group_editor <- function(df, prefix, title, parameters, options_list = list()) {
  input_defs <- lapply(
    parameters,
    function(CONT_003) {
      list(
        id      = paste0(prefix, CONT_003),
        label   = CONT_003,
        value   = get_param_value(df, CONT_003),
        options = options_list[[CONT_003]]
      )
    }
  )
  
  wellPanel(
    h4(title),
    build_input_grid(input_defs, max_per_row = 4)
  )
}

build_table_cell_inputs <- function(df, prefix) {
  if (nrow(df) == 0) {
    return(add_row_controls(df, prefix))
  }
  
  data_cols <- names(df)
  for (col_name in data_cols) {
    df[[col_name]] <- mapply(
      function(cell_value, row_idx) {
        sprintf(
          "<input type='text' class='form-control input-sm table-cell-input' data-prefix='%s' data-row='%d' data-col='%s' value=\"%s\"/>",
          prefix,
          row_idx,
          col_name,
          escape_html_attr(cell_value)
        )
      },
      df[[col_name]],
      seq_len(nrow(df)),
      USE.NAMES = FALSE
    )
  }
  
  add_row_controls(df, prefix)
}

apply_text_table_edit <- function(df, edit_info) {
  if (is.null(edit_info)) {
    return(df)
  }
  
  row_idx  <- as.integer(edit_info$row)
  col_name <- as.character(edit_info$col)
  
  if (!is.na(row_idx) &&
      row_idx >= 1 &&
      row_idx <= nrow(df) &&
      col_name %in% names(df)) {
    df[row_idx, col_name] <- as.character(edit_info$value)
  }
  
  df
}

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

model_df         <- read_param_file(file_names$model)
occupancy_dfs    <- read_use_patterns_file(file_names$occupancy)
control_df       <- read_param_file(file_names$control)
optimization_df  <- read_param_file(file_names$optimization)
market_df        <- read_param_file(file_names$market)
reward_df        <- read_param_file(file_names$reward)
forecast_df      <- read_param_file(file_names$forecast)
flex_price_df    <- read_param_file(file_names$flex_price)
debug_df         <- read_param_file(file_names$debug)
modes_df         <- read_table_file(file_names$modes)
sched_df         <- read_table_file(file_names$sched)
pilot_df         <- read_table_file(file_names$pilot)
occupancy_type_df  <- occupancy_dfs$day_types
occupancy_month_df <- occupancy_dfs$month_profiles

if (nrow(modes_df) == 0) {
  modes_df <- data.frame(mode = 1, heating = 21, cooling = 25)
}

ui <- fluidPage(
  useShinyjs(),
  titlePanel("MPC simulation configuration"),
  tabsetPanel(
    tabPanel(
      "Model",
      build_group_editor(
        model_df,
        "model__",
        "Building Inertia",
        c("Ci", "Ce", "Rie", "Rea", "Aw", "Ae")
      ),
      build_group_editor(
        model_df,
        "model__",
        "Shading",
        c("Shading_0", "Shading_1", "Setpoint_Shading1")
      ),
      build_group_editor(
        model_df,
        "model__",
        "Heat Pump",
        c("AT_hp_heat_1", "AT_hp_heat_2", "Q_hp_heat_1", "Q_hp_heat_2",
          "COP_hp_heat_1_coef1", "COP_hp_heat_1_coef2",
          "COP_hp_heat_1_coef3", "Tsup_hp_heat", "Q_hp_cool",
          "COP_hp_cool")
      ),
      build_group_editor(
        model_df,
        "model__",
        "Ventilation",
        c("RENvent01", "RENvent1", "RENvent2",
          "Setpoint_Rvent1", "Volume", "Efi_Vent_Rec")
      ),
      build_group_editor(
        model_df,
        "model__",
        "Initialization",
        c("Ti_0", "Te_0", "Qh_0", "Qc_0")
      ),
      build_group_editor(
        model_df,
        "model__",
        "Heat Distribution",
        c("inertial_fact")
      ),
      actionButton("save_model", "save", class = "btn-primary")
    ),
    tabPanel(
      "Occupancy",
      h4("Day Type Profiles"),
      DTOutput("occupancy_type_table"),
      h4("Monthly Weekday Mapping"),
      DTOutput("occupancy_month_table"),
      actionButton("save_occupancy", "save", class = "btn-primary")
    ),
    tabPanel(
      "Control",
      build_group_editor(
        control_df,
        "control__",
        "Control Approach",
        c("control_type"),
        options_list = list(
          control_type = c("modes", "setpoints")
        )
      ),
      build_group_editor(
        control_df,
        "control__",
        "Default Setpoints",
        c("set_point_default_cooling", "set_point_default_heating")
      ),
      build_group_editor(
        control_df,
        "control__",
        "Acceptable Setpoint range",
        c("set_point_range_heating_low", "set_point_range_heating_high",
          "set_point_range_cooling_low", "set_point_range_cooling_high",
          "Deadband")
      ),
      build_group_editor(
        control_df,
        "control__",
        "Flexibility Event Response",
        c("flexibility_event_length_max", "flexibility_recover_timespan",
          "thermal_stabilization_timespan", "minimum_flexibility",
          "flexibility_splits")
      ),
      actionButton("save_control", "save", class = "btn-primary")
    ),
    tabPanel(
      "Modes",
      DTOutput("modes_table"),
      actionButton("save_modes", "save", class = "btn-primary")
    ),
    tabPanel(
      "Optimization",
      uiOutput("optimization_ui"),
      actionButton("save_optimization", "save", class = "btn-primary")
    ),
    tabPanel(
      "Market",
      build_group_editor(
        market_df,
        "market__",
        "Market definition",
        c("market_resolution", "Complex_Market_Config"),
        options_list = list(
          Complex_Market_Config = c("yes", "no")
        )
      ),
      build_group_editor(
        market_df,
        "market__",
        "Scheduling Markets",
        c("Optimization_horizon_scheduling",
          "Implementation_horizon_scheduling",
          "Anticipation_scheduling", "optimization_aim_scheduling"),
        options_list = list(
          optimization_aim_scheduling = c("O", "E", "O+F", "E+F")
        )
      ),
      build_group_editor(
        market_df,
        "market__",
        "Piloting Markets",
        c("Optimization_horizon_piloting",
          "Implementation_horizon_piloting",
          "Anticipation_piloting", "optimization_aim_piloting"),
        options_list = list(
          optimization_aim_piloting = c("O", "E", "O+F", "E+F")
        )
      ),
      actionButton("save_market", "save", class = "btn-primary")
    ),
    tabPanel(
      "Market Schedules (Scheduling)",
      DTOutput("sched_table"),
      actionButton("save_sched", "save", class = "btn-primary")
    ),
    tabPanel(
      "Market Schedules (Piloting)",
      DTOutput("pilot_table"),
      actionButton("save_pilot", "save", class = "btn-primary")
    ),
    tabPanel(
      "Reward Function",
      uiOutput("reward_ui"),
      actionButton("save_reward", "save", class = "btn-primary")
    ),
    tabPanel(
      "Forecasting",
      uiOutput("forecast_ui"),
      actionButton("save_forecast", "save", class = "btn-primary")
    ),
    tabPanel(
      "Price Emulation",
      uiOutput("flex_price_ui"),
      actionButton("save_flex_price", "save", class = "btn-primary")
    ),
    tabPanel(
      "Configuration and Debug",
      uiOutput("debug_ui"),
      actionButton("save_debug", "save", class = "btn-primary")
    )
  ),
  br(),
  textOutput("msg_save")
)

server <- function(input, output, session) {
  
  rv <- reactiveValues(
    model           = model_df,
    occupancy_type  = occupancy_type_df,
    occupancy_month = occupancy_month_df,
    control         = control_df,
    modes           = modes_df,
    optimization    = optimization_df,
    market          = market_df,
    sched           = sched_df,
    pilot           = pilot_df,
    reward          = reward_df,
    forecast        = forecast_df,
    flex_price      = flex_price_df,
    debug           = debug_df
  )
  
  output$optimization_ui <- renderUI({
    build_param_editor(rv$optimization, "opt__", max_per_row = 4)
  })
  
  output$reward_ui <- renderUI({
    tagList(
      build_group_editor(
        rv$reward,
        "reward__",
        "Service",
        c("Alpha_Service_Min", "Service_T_Low", "Service_T_High",
          "Setback_T_Low", "Setback_T_High")
      ),
      build_group_editor(
        rv$reward,
        "reward__",
        "Scheduling",
        c("Service_Anticipation_Begin", "Service_Anticipation_End",
          "Service_AT_Low_Sched_HDD", "Service_AT_High_Sched_CDD")
      ),
      build_group_editor(
        rv$reward,
        "reward__",
        "Climate Correction for Scheduling",
        c("HDD_base", "HDD_period", "CDD_base", "CDD_period")
      ),
      build_group_editor(
        rv$reward,
        "reward__",
        "Correction for flex revenues",
        c("Revenue_discount_per_hour")
      )
    )
  })
  
  output$forecast_ui <- renderUI({
    build_param_editor(
      rv$forecast,
      "forecast__",
      options_list = list(
        forecast_type = c("accurate", "inaccurate")
      )
    )
  })
  
  output$flex_price_ui <- renderUI({
    build_param_editor(rv$flex_price, "flex__")
  })
  
  output$debug_ui <- renderUI({
    build_param_editor(
      rv$debug,
      "debug__",
      options_list = list(
        verbose         = c("0", "1"),
        parallel        = c("0", "1"),
        Price_emulation = c("0", "1")
      )
    )
  })
  
  output$modes_table <- renderDT({
    display_df <- build_table_cell_inputs(rv$modes, "modes")
    datatable(
      display_df,
      rownames = FALSE,
      escape   = FALSE,
      editable = FALSE,
      callback = table_input_callback,
      options  = list(dom = "t", pageLength = max(1, nrow(display_df)))
    )
  })
  
  output$occupancy_type_table <- renderDT({
    display_df <- build_table_cell_inputs(rv$occupancy_type, "occupancy_type")
    datatable(
      display_df,
      rownames = FALSE,
      escape   = FALSE,
      editable = FALSE,
      callback = table_input_callback,
      options  = list(dom = "t", pageLength = max(1, nrow(display_df)))
    )
  })
  
  output$occupancy_month_table <- renderDT({
    display_df <- build_table_cell_inputs(rv$occupancy_month, "occupancy_month")
    datatable(
      display_df,
      rownames = FALSE,
      escape   = FALSE,
      editable = FALSE,
      callback = table_input_callback,
      options  = list(dom = "t", pageLength = max(1, nrow(display_df)))
    )
  })
  
  output$sched_table <- renderDT({
    display_df <- build_table_cell_inputs(rv$sched, "sched")
    datatable(
      display_df,
      rownames = FALSE,
      escape   = FALSE,
      editable = FALSE,
      callback = table_input_callback,
      options  = list(dom = "t", pageLength = max(1, nrow(display_df)))
    )
  })
  
  output$pilot_table <- renderDT({
    display_df <- build_table_cell_inputs(rv$pilot, "pilot")
    datatable(
      display_df,
      rownames = FALSE,
      escape   = FALSE,
      editable = FALSE,
      callback = table_input_callback,
      options  = list(dom = "t", pageLength = max(1, nrow(display_df)))
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
  })
  
  observeEvent(input$modes_add_below, {
    template <- rv$modes[max(1, input$modes_add_below), , drop = FALSE]
    rv$modes <- insert_row(rv$modes, input$modes_add_below + 1, template)
  })
  
  observeEvent(input$modes_delete, {
    if (nrow(rv$modes) <= 1) {
      return()
    }
    rv$modes <- rv$modes[-input$modes_delete, , drop = FALSE]
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
        flush_table_edits(rv, input)
        
        rv$model        <- update_df_from_inputs(rv$model, "model__", input)
        rv$control      <- update_df_from_inputs(rv$control, "control__", input)
        rv$optimization <- update_df_from_inputs(rv$optimization, "opt__", input)
        rv$market       <- update_df_from_inputs(rv$market, "market__", input)
        rv$reward       <- update_df_from_inputs(rv$reward, "reward__", input)
        rv$forecast     <- update_df_from_inputs(rv$forecast, "forecast__", input)
        rv$flex_price   <- update_df_from_inputs(rv$flex_price, "flex__", input)
        rv$debug        <- update_df_from_inputs(rv$debug, "debug__", input)
        
        rv$occupancy_type[]  <- lapply(rv$occupancy_type, as.character)
        rv$occupancy_month[] <- lapply(rv$occupancy_month, as.character)
        
        rv$modes$mode <- seq_len(nrow(rv$modes))
        
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
          "# HVAC control parameters",
          rv$control
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
          file_names$forecast,
          "# Weather forecast parameters",
          rv$forecast
        )
        write_param_file(
          file_names$flex_price,
          "# Flexibility price simulation parameters",
          rv$flex_price
        )
        write_param_file(
          file_names$debug,
          "# Debug and configuration parameters",
          rv$debug
        )
        
        output$msg_save <- renderText(
          paste("✔ All configuration files saved in:", config_path)
        )
      },
      error = function(e) {
        output$msg_save <- renderText(
          paste("Error while saving configuration files:", e$message)
        )
      }
    )
  }
  
  save_buttons <- c(
    "save_model", "save_occupancy", "save_control", "save_modes",
    "save_optimization", "save_market", "save_sched", "save_pilot",
    "save_reward", "save_forecast", "save_flex_price", "save_debug"
  )
  
  for (CONT_004 in save_buttons) {
    local({
      button_id <- CONT_004
      observeEvent(input[[button_id]], {
        save_all()
      })
    })
  }
}

shinyApp(ui = ui, server = server)