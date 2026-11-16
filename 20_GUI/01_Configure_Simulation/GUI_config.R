# -------------------------------------------------------------
# Script: GUI_config.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Shiny interface for editing and saving simulation
# configuration files in 30_Simulation/02_Config: the files of the
# system, the asset registry and the files of each asset, which are
# in its own folder, 30_Simulation/02_Config/20_Assets/<asset_id>/.
# The first tab, Assets, has one selector for each type of model, with
# the number of assets of that type, and the read-only list of the
# registry. Raising a number adds assets with the lowest free numbers
# of their type: an asset takes the values of its folder when the
# folder exists, and the default values, in red, otherwise. Lowering
# a number removes the assets with the highest numbers, after a
# confirmation. A number cannot leave the system with no asset, and
# nothing is written until a save button is pressed. The folder of an
# asset that leaves stays on disk. Changing a number never changes
# the tab the user is in: the tab of a new asset is not opened.
# A tab is titled in red while it has something pending: values that
# took a default, parameters found twice, or edits that are not saved
# (its content differs from what was last read from disk or saved).
# The tab of an asset is red while the asset is not in the registry
# on disk or while any of its inner tabs is red, the Assets tab while
# the registry differs from the one on disk, and the Reward Function
# tab also while any of its boxes for the assets is pending. The red
# goes when the configuration is saved.
# Each asset of the registry has a tab titled with its id, with one
# tab inside it for each file of its type of model.
# The Reward Function tab holds the parameters of the reward of the
# system, and below them the parameters of the assets that the
# system weighs together: one input for each asset of the type, such
# as the weight of comfort of each building, labelled with the id of
# the asset. Which parameters of an asset file go there is read from
# 02_Config/GUI_reward_asset_parameters.csv. Each value is saved in
# the file of its asset, and the tab of the asset does not show it.
# The inputs follow the assets as they are added and removed.
# The configuration is read from disk each time the page is opened or
# reloaded, so a reload shows the files as they are on disk at that
# moment, and drops the edits that were not saved.
# The interface reads parameter files and editable tables,
# keeps the reactive state synchronized with user edits,
# and writes all configuration files when the save button
# of any tab is pressed: every save button checks and writes the
# whole configuration, and writes nothing if any value is invalid.
# -------------------------------------------------------------
# File paths: the file names of every configuration file are read
# from 30_Simulation/02_Config/00_Inner_parameters/04_File_paths.csv.
# The rows of scope system are the files of the system, and the rows
# whose scope is a type of model are the files of each asset of that
# type, found in its folder. When the file is missing or lacks a key,
# the default paths of the repository are used
# (00_Validation/Default_04_File_paths.csv), and when the registry
# holds no valid asset, the default registry
# (00_Validation/Default_12_Asset_registry.csv), so this app keeps no
# list of its own.
# -------------------------------------------------------------
# Loading safety: every configuration file is loaded through a
# "safe loader" that tolerates a missing file, a missing parameter,
# a duplicated parameter, or an invalid value. Whatever loads and
# validates correctly is kept; anything missing or invalid is
# replaced by the default value of the parameter catalogue,
# 30_Simulation/02_Config/00_Validation/Parameter_catalogue.csv, for
# the flat files, and by the matching entry from a Default_ file in
# the same folder for the tables (default values are never
# hard-coded in this script); a duplicated parameter keeps its first
# value. Every such case is collected as a warning, and the affected
# input/row is rendered in red so the user can see at a glance what
# came from defaults, or was deduplicated, rather than being read
# as-is from the file on disk. All loading/saving notices are shown
# in English.
# -------------------------------------------------------------
# The parameter catalogue: the parameters of each flat file and their
# order, the blocks that group them in their tab, their units, the
# options of the closed-list parameters and the rules their values
# are validated against all come from the rows of
# 30_Simulation/02_Config/00_Validation/Parameter_catalogue.csv, the
# same rules the real simulation pipeline applies. The integer
# tolerance comes from the file of the tolerances of the validation
# (Validation_tolerances.csv). Values are validated both when
# loading (to decide what counts as valid) and again right before
# saving (to refuse to write anything if any field is currently
# invalid). The tabs of the tables (the modes, the two market
# schedules and the occupancy profiles) keep their own editors, and
# take their units, and for the market tables the allowed values,
# from the same catalogue. The modes file holds a block of parameters
# (the deadband of the hysteresis) above its table of modes: its tab
# shows the block as an input above the table, and the file is
# written as the block, one blank line, and the table. Whatever is
# missing or invalid in the block takes its default from the
# catalogue, as in a flat file.
# -------------------------------------------------------------
# Inputs
#   30_Simulation/02_Config/*.csv : the configuration files of the
#     system, with their names read from 04_File_paths.csv.
#   30_Simulation/02_Config/12_Asset_registry.csv : the assets.
#   30_Simulation/02_Config/20_Assets/<asset_id>/*.csv : the
#     configuration files of each asset.
#   30_Simulation/02_Config/00_Validation/ : Parameter_catalogue.csv,
#     the parameter catalogue with the rules, units, blocks and
#     default values of the flat files and of the block of the modes
#     file; Validation_tolerances.csv, the
#     tolerances of the validation; and the Default_ files of the
#     tables, which fill whatever is missing or invalid.
#   20_GUI/01_Configure_Simulation/02_Config/GUI_fallback_values.csv :
#     the values used when a row has no default either.
#   20_GUI/01_Configure_Simulation/02_Config/
#     GUI_reward_asset_parameters.csv : the parameters of the assets
#     that the Reward Function tab shows.
#   The user's edits in the browser.
# -------------------------------------------------------------
# Outputs
#   The same configuration files under 30_Simulation/02_Config/ and
#   in the folder of each asset, rewritten when a save button is
#   pressed and every value is valid. The folder of an asset is
#   created if it does not exist.
# -------------------------------------------------------------
# Code outline
# Libraries and paths of the app and of the repository, then:
# 1. The fallback values of the GUI and the parameters of the assets
#    that the Reward Function tab shows (02_Config/)
# 2. Helper functions, sourced from 03_Functions/
# 3. The page, a function that Shiny calls each time the page is
#    opened or reloaded. It reads the whole configuration from disk
#    with 04_Scripts/load_gui_configuration.R, and builds:
#      - the Assets tab;
#      - one tab per asset;
#      - one tab per group of configuration files of the system.
# Then the server, which takes its initial state from what the page
# has just read, keeps the edits in reactive state, adds and removes
# the tabs of the assets, validates and saves; and
# shinyApp(ui, server).
# -------------------------------------------------------------
# Usage instructions
# From the repository root, or from this folder:
#   Rscript -e 'shiny::runApp("20_GUI/01_Configure_Simulation/GUI_config.R")'
# or source it from RStudio. It needs shiny, shinyjs and DT.
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

# -------------------------------------------------------------
# 1. Fallback values of the GUI (02_Config/GUI_fallback_values.csv)
# and parameters of the assets that the Reward Function tab shows
# (02_Config/GUI_reward_asset_parameters.csv)
# -------------------------------------------------------------
# The values the safe loaders use when a row is invalid in its file
# and has no default value either. They live in this app's own
# configuration folder, never in the code. Without them the loaders
# would have nothing to fall back on, so a missing or invalid file
# stops the app with a message saying which file and which value.
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
                     "market_end_optimization", "occupancy_hour_value")
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

  # The parameters of the assets that the Reward Function tab shows,
  # one input for each asset, instead of the tab of the asset.
  reward_asset_file  <- file.path(app_dir, "02_Config",
                                  "GUI_reward_asset_parameters.csv")
  reward_asset_table <- tryCatch(
    suppressWarnings(read.csv(reward_asset_file, comment.char = "#",
                              stringsAsFactors = FALSE, strip.white = TRUE)),
    error = function(e) NULL
  )
  if (is.null(reward_asset_table) ||
      !all(c("asset_type", "file_key", "parameter") %in%
             names(reward_asset_table))) {
    stop("GUI_config.R: cannot read ", reward_asset_file)
  }
  # The unit row of the file is skipped.
  reward_asset_table <- reward_asset_table[-1, , drop = FALSE]
  rownames(reward_asset_table) <- NULL
  rm(reward_asset_file)
}

# -------------------------------------------------------------
# 2. Helper functions (03_Functions/)
# -------------------------------------------------------------
# Every helper of the app lives in its own file under 03_Functions/:
# the validity checks, the raw readers, the safe loaders with their
# defaults, the writers and the builders of the editors. They are
# sourced into this environment rather than the global one, because
# the readers and writers use config_path, and the checks, the units
# and the writers use validation_config, all resolved here; so they
# behave exactly as if they were written here, whether the app is
# started with runApp() or sourced.
# -------------------------------------------------------------
{
  for (CONT_001 in list.files(file.path(app_dir, "03_Functions"),
                              pattern = "\\.R$", full.names = TRUE)) {
    # source() is called to define each helper in this environment.
    source(CONT_001, local = TRUE)
  }
  rm(CONT_001)
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
# 3. The configuration read from disk, and the page built from it
# -------------------------------------------------------------
# The page is a function, which Shiny calls each time the page is
# opened or reloaded. It reads the whole configuration from disk
# again, into the environment of the app, and builds the page from
# it. The server of that page, which starts right after, takes its
# initial state from the same objects. A page opened or reloaded
# therefore always shows what is on disk at that moment: the values
# of the files, the defaults that replaced what is missing or
# invalid, in red, and the notices of the loading.
# -------------------------------------------------------------
app_env <- environment()

ui <- function(request) {

  # load_gui_configuration.R is sourced to read every configuration
  # file from disk again, with the defaults of the repository for
  # whatever is missing or invalid, into the environment of the app.
  source(file.path(app_dir, "04_Scripts", "load_gui_configuration.R"),
         local = app_env)

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

  # build_asset_tab is called for each asset of the registry, to build
  # its tab with one inner tab for each file of its type of model.
  asset_tabs <- lapply(
    registry_df$asset_id,
    function(asset_id) {
      build_asset_tab(
        asset_id    = asset_id,
        files       = asset_files[[asset_id]],
        save_prefix = asset_save_prefix
      )
    }
  )

  # The Assets tab holds one selector for each type of model, with the
  # number of assets of that type, and the read-only list of the
  # registry. The server creates and removes the tabs of the assets as
  # the numbers change.
  assets_tab <- tabPanel(
    "Assets",
    tags$p(
      class = "gui-note",
      paste("Change the number of assets of a type to add or remove assets.",
            "New assets take the lowest free number of their type, and the",
            "assets with the highest numbers leave first. Nothing is written",
            "until a save button is pressed.")
    ),
    lapply(
      asset_types,
      function(asset_type) {
        numericInput(
          inputId = paste0("count_", asset_type),
          label   = paste0(asset_type, " assets [count]"),
          value   = sum(registry_df$asset_type == asset_type),
          min     = 0,
          step    = 1
        )
      }
    ),
    uiOutput("assets_notice"),
    h4("Assets of the registry"),
    uiOutput("assets_registry"),
    actionButton("save_assets", "save all", class = "btn-primary")
  )

  fluidPage(
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
      ".gui-note { color: #6c757d; font-style: italic; margin-bottom: 8px; }",
      ".nav-tabs > li > a.gui-tab-pending {",
      "  color: #c0392b !important; font-weight: 600; }"
    )))),
    titlePanel("MPC simulation configuration"),
    load_warning_banner,
    tags$p(
      class = "gui-note",
      paste("Every save button checks and writes the whole configuration:",
            "the files of the system, the asset registry and the files of",
            "every asset.")
    ),
    # The Assets tab comes first, then the tabs of the assets, one for
    # each asset of the registry, and then the tabs of the system.
    do.call(tabsetPanel, c(list(id = "main_tabs"), list(assets_tab), asset_tabs, list(
      tabPanel(
        "Optimization",
        uiOutput("optimization_ui"),
        actionButton("save_optimization", "save all", class = "btn-primary")
      ),
      tabPanel(
        "Market",
        tags$p(
          class = "gui-note",
          paste("Scheduling and Piloting markets (the parameters ending in",
                "_scheduling or _piloting): read only when Complex_Market_Config",
                "is no. With yes, the markets, their horizons and their aims come",
                "from the Market Schedules tabs, and these fields are shaded.")
        ),
        # build_file_editor is called to build the groups of the market
        # file from its rows of the catalogue.
        build_file_editor(
          df                = market_df,
          prefix            = "market__",
          file_label        = file_labels$market,
          validation_config = validation_config,
          defaulted         = market_load$defaulted,
          duplicated        = market_load$duplicated,
          max_per_row       = 4,
          hidden            = character(0)
        ),
        actionButton("save_market", "save all", class = "btn-primary")
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
        actionButton("save_sched", "save all", class = "btn-primary")
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
        actionButton("save_pilot", "save all", class = "btn-primary")
      ),
      tabPanel(
        "Full Market Emulation. Energy",
        uiOutput("energy_price_ui"),
        actionButton("save_energy_price", "save all", class = "btn-primary")
      ),
      tabPanel(
        "Full Market Emulation. Flexibility Price",
        uiOutput("flex_generation_ui"),
        actionButton("save_flex_generation", "save all", class = "btn-primary")
      ),
      tabPanel(
        "Full Market Emulation. Flexibility Events",
        # build_file_editor is called to build the groups of the
        # flexibility event file from its rows of the catalogue.
        build_file_editor(
          df                = flex_events_df,
          prefix            = "flexev__",
          file_label        = file_labels$flexibility_events,
          validation_config = validation_config,
          defaulted         = flex_events_load$defaulted,
          duplicated        = flex_events_load$duplicated,
          max_per_row       = 4,
          hidden            = character(0)
        ),
        actionButton("save_flexibility_events", "save all", class = "btn-primary")
      ),
      tabPanel(
        "Reward Function",
        uiOutput("reward_ui"),
        uiOutput("reward_asset_ui"),
        actionButton("save_reward", "save all", class = "btn-primary")
      ),
      tabPanel(
        "Forecasting",
        uiOutput("forecast_ui"),
        actionButton("save_forecast", "save all", class = "btn-primary")
      ),
      tabPanel(
        "Configuration and Debug",
        uiOutput("debug_ui"),
        actionButton("save_debug", "save all", class = "btn-primary")
      )
    ))),
    br(),
    uiOutput("msg_save")
  )
}

server <- function(input, output, session) {

  rv <- reactiveValues(
    flex_events     = flex_events_df,
    optimization    = optimization_df,
    market          = market_df,
    sched           = sched_df,
    pilot           = pilot_df,
    reward          = reward_df,
    forecast        = forecast_df,
    energy_price    = energy_price_df,
    flex_generation = flex_generation_df,
    debug           = debug_df,

    flex_events_defaulted  = flex_events_load$defaulted,
    optimization_defaulted = optimization_load$defaulted,
    market_defaulted       = market_load$defaulted,
    reward_defaulted       = reward_load$defaulted,
    forecast_defaulted     = forecast_load$defaulted,
    energy_price_defaulted = energy_price_load$defaulted,
    flex_generation_defaulted = flex_generation_load$defaulted,
    debug_defaulted        = debug_load$defaulted,

    flex_events_duplicated  = flex_events_load$duplicated,
    optimization_duplicated = optimization_load$duplicated,
    market_duplicated       = market_load$duplicated,
    reward_duplicated       = reward_load$duplicated,
    forecast_duplicated     = forecast_load$duplicated,
    energy_price_duplicated = energy_price_load$duplicated,
    flex_generation_duplicated = flex_generation_load$duplicated,
    debug_duplicated        = debug_load$duplicated,

    sched_defaulted_rows           = sched_load$defaulted_rows,
    pilot_defaulted_rows           = pilot_load$defaulted_rows,
    registry        = registry_df,
    asset_status    = asset_status,
    registry_defaulted_rows = registry_defaulted_rows,
    assets_notice   = character(0)
  )

  # The state of each asset is its own reactiveValues object, so that
  # an edit in one asset does not redraw the others. They are kept
  # by asset id, with the observers that serve them.
  asset_rvs      <- list()
  asset_handlers <- list()

  # The parameters of each asset that the Reward Function tab holds,
  # by asset id and key of file.
  asset_hidden   <- list()

  # The files of each asset are kept by asset id too. The server works
  # on its own copy, so that the assets added or removed in one
  # session do not reach the others.
  asset_files <- asset_files

  # What was last read from disk or saved, to tell the edits that are
  # not saved: the data frames of the system and the registry under
  # system, and the state of each asset under its id.
  system_slots <- c("flex_events", "optimization", "market",
                    "sched", "pilot", "reward", "forecast", "energy_price",
                    "flex_generation", "debug", "registry")
  baselines <- reactiveValues()
  baselines$system <- isolate(reactiveValuesToList(rv))[system_slots]

  # The assets that wait for the user to confirm that they leave.
  pending_removal <- reactiveVal(NULL)

  output$optimization_ui <- renderUI({
    # build_file_editor is called to build the groups of the file from
    # its rows of the catalogue, with the values of the reactive state.
    build_file_editor(
      df                = rv$optimization,
      prefix            = "opt__",
      file_label        = file_labels$optimization,
      validation_config = validation_config,
      defaulted         = rv$optimization_defaulted,
      duplicated        = rv$optimization_duplicated,
      max_per_row       = 4,
      hidden            = character(0)
    )
  })

  output$reward_ui <- renderUI({
    # build_file_editor is called to build the groups of the file from
    # its rows of the catalogue, with the values of the reactive state.
    build_file_editor(
      df                = rv$reward,
      prefix            = "reward__",
      file_label        = file_labels$reward,
      validation_config = validation_config,
      defaulted         = rv$reward_defaulted,
      duplicated        = rv$reward_duplicated,
      max_per_row       = 4,
      hidden            = character(0)
    )
  })

  output$reward_asset_ui <- renderUI({
    # build_reward_asset_inputs is called to build one input for each
    # asset of the parameters that the Reward Function tab holds for
    # the assets, such as the weight of comfort of each building. It
    # is built again when an asset is added or removed.
    build_reward_asset_inputs(
      reward_table      = reward_asset_table,
      registry          = rv$registry,
      asset_files       = asset_files,
      asset_rvs         = asset_rvs,
      typed             = function(input_id) isolate(input[[input_id]]),
      validation_config = validation_config,
      max_per_row       = 4
    )
  })

  output$forecast_ui <- renderUI({
    # build_file_editor is called to build the groups of the file from
    # its rows of the catalogue, with the values of the reactive state.
    build_file_editor(
      df                = rv$forecast,
      prefix            = "forecast__",
      file_label        = file_labels$forecast,
      validation_config = validation_config,
      defaulted         = rv$forecast_defaulted,
      duplicated        = rv$forecast_duplicated,
      max_per_row       = 1,
      hidden            = character(0)
    )
  })

  output$energy_price_ui <- renderUI({
    # build_file_editor is called to build the groups of the file from
    # its rows of the catalogue, with the values of the reactive state.
    build_file_editor(
      df                = rv$energy_price,
      prefix            = "energyprice__",
      file_label        = file_labels$energy_price,
      validation_config = validation_config,
      defaulted         = rv$energy_price_defaulted,
      duplicated        = rv$energy_price_duplicated,
      max_per_row       = 1,
      hidden            = character(0)
    )
  })

  output$flex_generation_ui <- renderUI({
    # build_file_editor is called to build the groups of the file from
    # its rows of the catalogue, with the values of the reactive state.
    build_file_editor(
      df                = rv$flex_generation,
      prefix            = "flexgen__",
      file_label        = file_labels$flex_generation,
      validation_config = validation_config,
      defaulted         = rv$flex_generation_defaulted,
      duplicated        = rv$flex_generation_duplicated,
      max_per_row       = 1,
      hidden            = character(0)
    )
  })

  output$debug_ui <- renderUI({
    # build_file_editor is called to build the groups of the file from
    # its rows of the catalogue, with the values of the reactive state.
    build_file_editor(
      df                = rv$debug,
      prefix            = "debug__",
      file_label        = file_labels$debug,
      validation_config = validation_config,
      defaulted         = rv$debug_defaulted,
      duplicated        = rv$debug_duplicated,
      max_per_row       = 1,
      hidden            = character(0)
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
    for (CONT_005 in market_basic_only_params) {
      toggleClass(
        selector  = paste0(".shiny-input-container:has(#market__", CONT_005, ")"),
        class     = "gui-unused",
        condition = identical(complex_now, "yes")
      )
    }
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
                        file_key = file_labels$sched, USE.NAMES = FALSE),
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
                        file_key = file_labels$pilot, USE.NAMES = FALSE),
      options  = list(dom = "t", ordering = FALSE,
                      pageLength = max(1, nrow(display_df)))
    )
  })

  observeEvent(input$sched_cell_text_edit, {
    rv$sched <- apply_text_table_edit(rv$sched, input$sched_cell_text_edit)
  })

  observeEvent(input$pilot_cell_text_edit, {
    rv$pilot <- apply_text_table_edit(rv$pilot, input$pilot_cell_text_edit)
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

  # -------------------------------------------------------------
  # The assets of the registry: the state of each one, and its tab
  # connected to it. The tabs of the assets of the registry were
  # built with the interface. The tab of an asset that is added later
  # is inserted when the number of assets of its type is raised, and
  # removed when it is lowered and the user confirms.
  # -------------------------------------------------------------
  # connect_asset creates the state of an asset and the observers
  # that serve its tab.
  connect_asset <- function(asset_id, asset_type, state) {
    asset_rvs[[asset_id]] <<- do.call(reactiveValues, state)

    # asset_reward_parameters is called to find the parameters of the
    # asset that the Reward Function tab shows, so that its own tab
    # leaves them out.
    reward_rows    <- asset_reward_parameters(reward_asset_table, asset_type)
    hidden_by_file <- split(reward_rows$parameter, reward_rows$file_key)
    rm(reward_rows)
    asset_hidden[[asset_id]] <<- hidden_by_file

    # The state read from the folder of the asset is what a pending
    # edit is compared with, until the asset is saved.
    baselines[[asset_id]] <- state

    # register_asset_observers is called to fill the outputs of the
    # tab of the asset, and to create the observers of its tables
    # and of its save button. The save button calls save_all(),
    # which is defined below.
    asset_handlers[[asset_id]] <<- register_asset_observers(
      asset_id          = asset_id,
      files             = asset_files[[asset_id]],
      asset_rv          = asset_rvs[[asset_id]],
      input             = input,
      output            = output,
      save_prefix       = asset_save_prefix,
      on_save           = function() save_all(),
      validation_config = validation_config,
      table_callback    = table_input_callback,
      hidden_parameters = hidden_by_file
    )
    invisible(NULL)
  }

  for (CONT_006 in registry_df$asset_id) {
    connect_asset(
      CONT_006,
      registry_df$asset_type[registry_df$asset_id == CONT_006],
      asset_states[[CONT_006]]
    )
  }

  # add_asset adds an asset of a type: its state is loaded from its
  # folder when it exists, and from the defaults of the repository
  # otherwise, nothing is written on disk, and its tab is inserted
  # after the last asset.
  add_asset <- function(asset_id, asset_type) {
    asset_files[[asset_id]] <<- asset_type_files(paths_table, asset_type)

    # load_asset_state is called to load the files of the asset from
    # its folder, or from the defaults, which the interface paints in
    # red until the asset is saved.
    loaded <- load_asset_state(
      asset_id          = asset_id,
      files             = asset_files[[asset_id]],
      asset_folder      = file.path(paths$asset_config_folder, asset_id),
      validation_config = validation_config
    )

    # insertTab is called to put the tab of the asset after the last
    # asset. The tab is not opened: the user stays in the tab where
    # the number was changed.
    insertTab(
      inputId  = "main_tabs",
      tab      = build_asset_tab(
        asset_id    = asset_id,
        files       = asset_files[[asset_id]],
        save_prefix = asset_save_prefix
      ),
      target   = tail(isolate(rv$registry$asset_id), 1),
      position = "after",
      select   = FALSE
    )
    connect_asset(asset_id, asset_type, loaded$state)

    status <- isolate(rv$asset_status)
    status[[asset_id]] <- if (loaded$origin == "folder") {
      "loaded from an existing folder"
    } else {
      "new, not saved"
    }
    rv$asset_status <- status
    rv$registry <- rbind(
      isolate(rv$registry),
      data.frame(asset_id = asset_id, asset_type = asset_type,
                 stringsAsFactors = FALSE)
    )

    if (loaded$origin == "folder") {
      return(c(sprintf(
        "%s: its folder already exists, so the asset takes the values of that folder.",
        asset_id
      ), loaded$messages))
    }
    sprintf(
      "%s: new asset with the default values of the repository, shown in red until they are saved.",
      asset_id
    )
  }

  # remove_asset takes an asset out of the interface: its observers
  # are destroyed, its tab and its state are removed, and the last
  # values of its inputs are cleared so that they cannot reach a new
  # asset that takes the same id. Its folder is not touched.
  remove_asset <- function(asset_id) {
    for (CONT_011 in asset_handlers[[asset_id]]) {
      CONT_011$destroy()
    }
    removeTab(inputId = "main_tabs", target = asset_id)

    input_names <- grep(
      paste0("^(", asset_id, "__|", asset_save_prefix, asset_id, "$|tabs_",
             asset_id, "$)"),
      names(isolate(reactiveValuesToList(input))),
      value = TRUE
    )
    runjs(sprintf(
      "%s.forEach(function(name) { Shiny.setInputValue(name, null); });",
      jsonlite::toJSON(input_names)
    ))
    for (CONT_012 in grep(paste0("^", asset_id, "__"), names(output),
                          value = TRUE)) {
      output[[CONT_012]] <- NULL
    }

    asset_rvs[[asset_id]]      <<- NULL
    asset_handlers[[asset_id]] <<- NULL
    asset_hidden[[asset_id]]   <<- NULL
    baselines[[asset_id]]      <- NULL
    asset_files[[asset_id]]    <<- NULL
    registry_now <- isolate(rv$registry)
    registry_now <- registry_now[registry_now$asset_id != asset_id, ,
                                 drop = FALSE]
    rownames(registry_now) <- NULL
    rv$registry     <- registry_now
    rv$asset_status <- isolate(rv$asset_status)[
      names(isolate(rv$asset_status)) != asset_id
    ]
    invisible(NULL)
  }

  # restore_selector puts the selector of a type back to the number of
  # assets of that type that the registry holds.
  restore_selector <- function(asset_type) {
    updateNumericInput(
      session,
      paste0("count_", asset_type),
      value = sum(isolate(rv$registry$asset_type) == asset_type)
    )
  }

  # change_count handles a new number of assets of a type: it adds
  # the new assets, asks for confirmation before removing some, and
  # refuses a number that is not valid or leaves the system with no
  # asset.
  change_count <- function(asset_type, count) {
    current_ids <- isolate(rv$registry$asset_id[rv$registry$asset_type ==
                                                  asset_type])

    # asset_ids_after_count is called to find the ids that enter and
    # the ids that leave for the number asked, and to refuse a number
    # that is not valid.
    change <- tryCatch(
      asset_ids_after_count(current_ids, asset_type, count),
      error = function(e) e
    )
    if (inherits(change, "error")) {
      rv$assets_notice <- conditionMessage(change)
      restore_selector(asset_type)
      return(invisible(NULL))
    }
    if (length(change$add) == 0 && length(change$remove) == 0) {
      return(invisible(NULL))
    }

    total_after <- nrow(isolate(rv$registry)) + length(change$add) -
      length(change$remove)
    if (total_after < 1) {
      rv$assets_notice <- paste(
        "The system needs at least one asset: the number of assets of",
        "type", asset_type, "was not changed."
      )
      restore_selector(asset_type)
      return(invisible(NULL))
    }

    rv$assets_notice <- character(0)
    if (length(change$add) > 0) {
      notices <- character(0)
      for (CONT_013 in change$add) {
        notices <- c(notices, add_asset(CONT_013, asset_type))
      }
      rv$assets_notice <- notices
    }
    if (length(change$remove) > 0) {
      pending_removal(list(asset_type = asset_type, ids = change$remove))
      showModal(modalDialog(
        title = "Remove assets",
        tags$p("These assets will leave the simulation:",
               paste(change$remove, collapse = ", ")),
        tags$p("Their unsaved changes are lost. Their folders stay on",
               "disk, and the simulation does not read them."),
        footer    = tagList(
          actionButton("cancel_remove_assets", "cancel"),
          actionButton("confirm_remove_assets", "remove",
                       class = "btn-primary")
        ),
        easyClose = FALSE
      ))
    }
    invisible(NULL)
  }

  for (CONT_014 in asset_types) {
    local({
      asset_type <- CONT_014
      observeEvent(input[[paste0("count_", asset_type)]], {
        change_count(asset_type, input[[paste0("count_", asset_type)]])
      }, ignoreInit = TRUE, ignoreNULL = FALSE)
    })
  }

  observeEvent(input$cancel_remove_assets, {
    pending <- pending_removal()
    if (!is.null(pending)) {
      restore_selector(pending$asset_type)
    }
    pending_removal(NULL)
    removeModal()
  })

  observeEvent(input$confirm_remove_assets, {
    pending <- pending_removal()
    removeModal()
    if (is.null(pending)) {
      return()
    }
    for (CONT_015 in pending$ids) {
      remove_asset(CONT_015)
    }
    rv$assets_notice <- paste(
      paste(pending$ids, collapse = ", "),
      "will leave the simulation when the configuration is saved."
    )
    pending_removal(NULL)
  })

  output$assets_notice <- renderUI({
    if (length(rv$assets_notice) == 0) {
      return(NULL)
    }
    tags$div(
      class = "gui-note",
      lapply(rv$assets_notice, function(m) tags$p(m))
    )
  })

  output$assets_registry <- renderUI({
    # build_assets_registry_table is called to list the assets of the
    # registry with their status, read-only.
    build_assets_registry_table(
      registry_df    = rv$registry,
      status         = rv$asset_status,
      defaulted_rows = rv$registry_defaulted_rows,
      file_label     = file_labels$asset_registry
    )
  })

  # -------------------------------------------------------------
  # The tabs with something pending: values that took a default,
  # parameters found twice, edits that are not saved and assets that
  # are not in the registry. The title of each of them is painted in
  # red until it is saved.
  # -------------------------------------------------------------
  # The flat files of the system: tab, slot of the state and start
  # of the id of its inputs.
  system_flat_tabs <- list(
    list(tab = "Optimization", slot = "optimization", prefix = "opt__"),
    list(tab = "Market", slot = "market", prefix = "market__"),
    list(tab = "Full Market Emulation. Energy", slot = "energy_price",
         prefix = "energyprice__"),
    list(tab = "Full Market Emulation. Flexibility Price",
         slot = "flex_generation", prefix = "flexgen__"),
    list(tab = "Full Market Emulation. Flexibility Events",
         slot = "flex_events", prefix = "flexev__"),
    list(tab = "Reward Function", slot = "reward", prefix = "reward__"),
    list(tab = "Forecasting", slot = "forecast", prefix = "forecast__"),
    list(tab = "Configuration and Debug", slot = "debug", prefix = "debug__")
  )
  # The tables of the system: tab and slot of the state.
  system_table_tabs <- list(
    list(tab = "Market Schedules (Scheduling)", slot = "sched"),
    list(tab = "Market Schedules (Piloting)", slot = "pilot")
  )

  pending_tabs <- reactive({
    base  <- baselines$system
    flags <- list()
    reward_assets <- FALSE

    # asset_pending_tabs is called for each asset of the registry, to
    # find which of its inner tabs have something pending.
    for (CONT_017 in rv$registry$asset_id) {
      if (is.null(asset_rvs[[CONT_017]]) || is.null(baselines[[CONT_017]])) {
        next
      }
      asset_pending <- asset_pending_tabs(
        asset_id          = CONT_017,
        files             = asset_files[[CONT_017]],
        asset_rv          = asset_rvs[[CONT_017]],
        baseline          = baselines[[CONT_017]],
        input             = input,
        hidden_parameters = asset_hidden[[CONT_017]]
      )
      for (CONT_018 in names(asset_pending$tabs)) {
        flags[[sprintf("#tabs_%s > li > a[data-value='%s']", CONT_017,
                       CONT_018)]] <- asset_pending$tabs[[CONT_018]]
      }
      flags[[sprintf("#main_tabs > li > a[data-value='%s']", CONT_017)]] <-
        any(asset_pending$tabs) ||
        !identical(rv$asset_status[[CONT_017]], "in the registry")
      reward_assets <- reward_assets || asset_pending$reward
      rm(asset_pending)
    }

    for (CONT_019 in system_flat_tabs) {
      # param_file_pending is called to compare the inputs of the file
      # with what was last read from disk or saved.
      flags[[sprintf("#main_tabs > li > a[data-value='%s']", CONT_019$tab)]] <-
        param_file_pending(
          df          = rv[[CONT_019$slot]],
          baseline_df = base[[CONT_019$slot]],
          prefix      = CONT_019$prefix,
          input       = input,
          flagged     = c(rv[[paste0(CONT_019$slot, "_defaulted")]],
                          rv[[paste0(CONT_019$slot, "_duplicated")]]),
          include     = as.character(rv[[CONT_019$slot]]$parameter)
        ) || (CONT_019$slot == "reward" && reward_assets)
    }
    for (CONT_020 in system_table_tabs) {
      # table_pending is called to compare the table with what was
      # last read from disk or saved.
      flags[[sprintf("#main_tabs > li > a[data-value='%s']", CONT_020$tab)]] <-
        table_pending(
          df             = rv[[CONT_020$slot]],
          baseline_df    = base[[CONT_020$slot]],
          defaulted_rows = rv[[paste0(CONT_020$slot, "_defaulted_rows")]]
        )
    }
    # The Assets tab has something pending while the registry is not
    # the one on disk.
    flags[["#main_tabs > li > a[data-value='Assets']"]] <-
      length(rv$registry_defaulted_rows) > 0 ||
      any(rv$asset_status != "in the registry") ||
      table_pending(rv$registry, base$registry, integer(0))
    flags
  })

  observe({
    flags <- pending_tabs()
    # The classes are switched once the browser has received the
    # output of this flush, so that the tab of a new asset exists
    # when its class is set.
    session$onFlushed(function() {
      withReactiveDomain(session, {
        for (CONT_021 in names(flags)) {
          toggleClass(
            selector  = CONT_021,
            class     = "gui-tab-pending",
            condition = isTRUE(flags[[CONT_021]])
          )
        }
      })
    }, once = TRUE)
  })

  save_all <- function() {
    tryCatch(
      {
        # flush_table_edits() pulls in any pending cell edits from the
        # DT tables of the system (the market schedules) before the
        # parameter tabs below are read from their individual Shiny
        # inputs, so nothing entered by the user is lost regardless of
        # which tab is currently open when "save all" is pressed.
        flush_table_edits(rv, input)

        # update_df_from_inputs() re-reads every widget's current
        # value back into its reactive data frame - one call per tab,
        # all sharing the same pattern (widget input -> df$value).
        rv$flex_events  <- update_df_from_inputs(rv$flex_events, "flexev__", input)
        rv$optimization <- update_df_from_inputs(rv$optimization, "opt__", input)
        rv$market       <- update_df_from_inputs(rv$market, "market__", input)
        rv$reward       <- update_df_from_inputs(rv$reward, "reward__", input)
        rv$forecast     <- update_df_from_inputs(rv$forecast, "forecast__", input)
        rv$energy_price <- update_df_from_inputs(rv$energy_price, "energyprice__", input)
        rv$flex_generation <- update_df_from_inputs(rv$flex_generation, "flexgen__", input)
        rv$debug        <- update_df_from_inputs(rv$debug, "debug__", input)

        # update_asset_from_inputs() does the same for each asset of
        # the registry: the pending edits of its tables and the value
        # of each input of its tabs.
        asset_ids <- rv$registry$asset_id
        for (CONT_007 in asset_ids) {
          update_asset_from_inputs(
            asset_rv = asset_rvs[[CONT_007]],
            asset_id = CONT_007,
            files    = asset_files[[CONT_007]],
            input    = input
          )
        }

        # ---- Validate everything before writing anything ----
        # Every tab is validated against the same catalogue rules used
        # by the real simulation pipeline, before any file
        # on disk is touched, so a single invalid value in one tab
        # cannot leave the configuration half-written.
        # validate_param_df_gui is called once per flat file of the
        # system, to check each of its values against its rule of the
        # catalogue and collect a message for each invalid one.
        validation_errors <- c(
          validate_asset_registry_gui(rv$registry, file_labels$asset_registry,
                                      validation_config),
          validate_param_df_gui(rv$flex_events, file_labels$flexibility_events,
                                validation_config),
          validate_param_df_gui(rv$optimization, file_labels$optimization,
                                validation_config),
          validate_param_df_gui(rv$market, file_labels$market, validation_config),
          validate_param_df_gui(rv$reward, file_labels$reward, validation_config),
          validate_param_df_gui(rv$forecast, file_labels$forecast, validation_config),
          validate_param_df_gui(rv$energy_price, file_labels$energy_price,
                                validation_config),
          validate_param_df_gui(rv$flex_generation, file_labels$flex_generation,
                                validation_config),
          validate_param_df_gui(rv$debug, file_labels$debug, validation_config),
          validate_market_table_df_gui(rv$sched, file_labels$sched),
          validate_market_table_df_gui(rv$pilot, file_labels$pilot)
        )

        # The files of the system that the relations between
        # parameters may use, each under the name of its file.
        system_values <- setNames(
          list(rv$flex_events, rv$market, rv$reward),
          c(file_labels$flexibility_events, file_labels$market,
            file_labels$reward)
        )

        # validate_asset_state_gui is called once for each asset, to
        # check its files and, once they are valid, the relations
        # between its parameters and those of the system. Its
        # messages start with the id of the asset.
        for (CONT_008 in asset_ids) {
          validation_errors <- c(validation_errors, validate_asset_state_gui(
            asset_rv            = asset_rvs[[CONT_008]],
            asset_id            = CONT_008,
            files               = asset_files[[CONT_008]],
            validation_config   = validation_config,
            parameter_relations = parameter_relations,
            system_values       = system_values
          ))
        }

        if (length(validation_errors) > 0) {
          output$msg_save <- renderUI(
            tags$div(
              style = "color:#c0392b; white-space:pre-wrap;",
              tags$strong("\u2716 Nothing was saved. Fix these values:"),
              tags$ul(lapply(validation_errors, function(m) tags$li(m)))
            )
          )
          return(invisible(NULL))
        }

        # All validation above passed, so everything is now written:
        # the folder and the files of each asset, the registry and the
        # files of the system.
        for (CONT_009 in asset_ids) {
          # write_asset_state is called to create the folder of the
          # asset when it does not exist and write its files.
          write_asset_state(
            asset_rv     = asset_rvs[[CONT_009]],
            asset_id     = CONT_009,
            asset_type   = rv$registry$asset_type[rv$registry$asset_id ==
                                                    CONT_009],
            files        = asset_files[[CONT_009]],
            asset_folder = file.path(paths$asset_config_folder, CONT_009)
          )
        }

        # write_table_file is called to write the registry: the rows
        # change, and its comments and units row are kept.
        write_table_file(
          paths$asset_registry_file,
          c(paste0("# ", file_labels$asset_registry),
            "# Asset registry configuration file",
            paste0("# ", strrep("-", 61))),
          rv$registry
        )

        # All validation above passed, so every tab of the system is
        # written to its configuration file on disk:
        #   - write_param_file() for flat "parameter,value,unit" files
        #   - write_table_file() for the market-schedule tables
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
        rv$flex_events_defaulted  <- character(0)
        rv$optimization_defaulted <- character(0)
        rv$market_defaulted       <- character(0)
        rv$reward_defaulted       <- character(0)
        rv$forecast_defaulted     <- character(0)
        rv$energy_price_defaulted <- character(0)
        rv$flex_generation_defaulted <- character(0)
        rv$debug_defaulted        <- character(0)
        rv$flex_events_duplicated  <- character(0)
        rv$optimization_duplicated <- character(0)
        rv$market_duplicated       <- character(0)
        rv$reward_duplicated       <- character(0)
        rv$forecast_duplicated     <- character(0)
        rv$energy_price_duplicated <- character(0)
        rv$flex_generation_duplicated <- character(0)
        rv$debug_duplicated        <- character(0)
        rv$sched_defaulted_rows    <- integer(0)
        rv$pilot_defaulted_rows    <- integer(0)
        for (CONT_010 in asset_ids) {
          # clear_asset_flags is called to stop painting in red the
          # values of the asset that have just been written.
          clear_asset_flags(asset_rvs[[CONT_010]])
        }
        rv$asset_status <- setNames(
          rep("in the registry", length(asset_ids)),
          asset_ids
        )
        rv$registry_defaulted_rows <- integer(0)

        # What has just been written is the new baseline of the
        # pending edits.
        baselines$system <- reactiveValuesToList(rv)[system_slots]
        for (CONT_016 in asset_ids) {
          baselines[[CONT_016]] <- reactiveValuesToList(asset_rvs[[CONT_016]])
        }

        output$msg_save <- renderUI(
          tags$div(
            style = "color:#1e7e34;",
            paste("\u2714 All configuration files saved in:", config_path)
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
    "save_assets", "save_flexibility_events",
    "save_optimization", "save_market", "save_sched", "save_pilot",
    "save_reward", "save_forecast", "save_energy_price", "save_flex_generation", "save_debug"
  )

  for (CONT_004 in save_buttons) {
    local({
      button_id <- CONT_004
      observeEvent(input[[button_id]], {
        # Every "save all" button triggers the same save_all(): it
        # always validates and writes the whole configuration at
        # once, not just the tab the button belongs to.
        save_all()
      })
    })
  }
}

shinyApp(ui = ui, server = server)
