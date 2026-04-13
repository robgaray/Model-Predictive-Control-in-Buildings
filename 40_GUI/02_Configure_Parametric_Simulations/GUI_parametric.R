# -------------------------------------------------------------
# Script: GUI_parametric.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Location: 40_GUI/02_Configure_Parametric_Simulations/GUI_parametric.R
# -------------------------------------------------------------
# Overall description
# This script launches a Shiny GUI to configure and generate
# the parametric simulation file (Optim_parameters.csv) used by
# the SCC job array scripts.
#
# Memory-efficient version: the full factorial is built
# incrementally using nested for loops with chunked matrix
# allocation (see generate_full_factorial.R), avoiding the
# 8+ GB expand.grid() allocation for large parameter spaces.
#
# Workflow:
#   1. Set min/max/step for each numeric parameter and select
#      checkbox options for categorical parameters.
#   2. Use one of three strategies to build the configuration:
#      a) "Generate Full Factorial" - replaces existing file
#      b) "Append Full Factorial" - appends to existing file
#      c) "Generate Latin Hypercube Sample" - efficient sampling
#   3. Click "Generate Configuration File" to write
#      Optim_parameters.csv and scc_settings.sh to
#      02_SCC_simulation/.
# -------------------------------------------------------------
# Parameters grouped by configuration file:
#
# optimization_parameters.csv:
#   population_size, iteration_number, run_number,
#   pcrossover, pmutation,
#   control_optimization_horizon, control_implementation_horizon,
#   control_optimization_anticipation
#
# control_parameters.csv:
#   control_type (checkbox: 1=modes, 2=setpoint),
#   optimization_aim (checkbox: 1=energy, 2=flexibility),
#   flexibility_event_length_max, flexibility_recover_timespan,
#   thermal_stabilization_timespan, minimum_flexibility,
#   flexibility_splits
#
# reward_parameters.csv:
#   Alpha_confort
#
# debug_and_config.csv:
#   month_subset (checkbox: 0..12)
#
# SCC settings:
#   job_name       (Slurm job name)
#   tasks_per_job  (tasks per job array)
#   scc_queue      (Slurm partition)
#   scc_qos        (Quality of Service)
#   scc_user       (email for --mail-user)
#   scc_username   (cluster login for squeue)
#   output_formats (csv, rds, or both)
# -------------------------------------------------------------
# Inputs
#   User interaction via Shiny widgets.
#   Default values loaded from:
#     02_Config/GUI_parametric_config.csv
# -------------------------------------------------------------
# Outputs
#   02_SCC_simulation/Optim_parameters.csv
#   02_SCC_simulation/scc_settings.sh
#   02_SCC_simulation/Extraction_code.txt
# -------------------------------------------------------------
# Code outline
#   1. Path resolution
#   2. Source helper functions
#   2b. Load GUI default configuration
#   3. Helper UI function (param_row)
#   4. UI definition
#     4.1. Optimization parameters
#     4.2. Control parameters
#     4.3. Reward parameters
#     4.4. Debug & Config parameters
#     4.5. SCC Settings (job name, tasks per job, etc.)
#     4.6. Configuration Generation buttons
#   5. Server logic
#     5.1. Reactive values and parameter builder
#     5.2. Estimated configuration count
#     5.3. Generate Full Factorial
#     5.4. Append Full Factorial
#     5.5. Generate Latin Hypercube Sample
#     5.6. Configuration summary
#     5.7. Save configuration file
#   6. Launch
# -------------------------------------------------------------
# Usage instructions
#   Run from the repo root:
#     shiny::runApp("40_GUI/02_Configure_Parametric_Simulations")
#   Or source this file directly.
# -------------------------------------------------------------
# Where this function/script is used
#   Standalone Shiny app, launched by the user.
# -------------------------------------------------------------
# functions/scripts called
#   build_param_range.R, generate_full_factorial.R,
#   generate_lhs_design.R, save_optim_params.R
# -------------------------------------------------------------

library(shiny)
library(shinyjs)
library(DT)

# -------------------------------------------------------------
# 1. Path resolution
# Shiny sets getwd() to the app directory at launch.
# The app lives at 40_GUI/02_Configure_Parametric_Simulations/
# so the repo root is two levels up.
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
  if (!grepl("02_Configure_Parametric_Simulations", app_dir, fixed = TRUE)) {
    candidate <- file.path(app_dir, "40_GUI", "02_Configure_Parametric_Simulations")
    if (dir.exists(candidate)) {
      app_dir <- normalizePath(candidate)
    } else {
      stop(
        "GUI_parametric.R: cannot locate '40_GUI/02_Configure_Parametric_Simulations' ",
        "under '", app_dir, "'.  ",
        "Please run this script from the repo root or from the app folder."
      )
    }
  }
  
  repo_root <- normalizePath(file.path(app_dir, "..", ".."))
  scc_path  <- file.path(repo_root, "02_SCC_simulation")
}

# -------------------------------------------------------------
# 2. Source helper functions
# -------------------------------------------------------------
functions_path <- file.path(app_dir, "03_Functions")
source(file.path(functions_path, "build_param_range.R"))
source(file.path(functions_path, "generate_full_factorial.R"))
source(file.path(functions_path, "generate_lhs_design.R"))
source(file.path(functions_path, "save_optim_params.R"))

# -------------------------------------------------------------
# 2b. Load GUI default configuration
# Reads default values for all widgets from the configuration
# file 02_Config/GUI_parametric_config.csv. This avoids
# hardcoding initial values and makes the GUI configurable.
# -------------------------------------------------------------
{
  gui_config_path <- file.path(app_dir, "02_Config",
                               "GUI_parametric_config.csv")
  gui_defaults    <- read.csv(gui_config_path,
                              stringsAsFactors = FALSE,
                              strip.white      = TRUE)
  rownames(gui_defaults) <- gui_defaults$Parameter

  # Helper to retrieve a numeric value from the config
  cfg_num <- function(param) {
    as.numeric(gui_defaults[param, "Value"])
  }

  # Helper to retrieve a character value from the config
  cfg_chr <- function(param) {
    as.character(gui_defaults[param, "Value"])
  }
}

# -------------------------------------------------------------
# 3. Helper: min/max/step row of inputs
# Each param_row already shows labels (Min, Max, Step) in the
# numericInput widgets, so no separate header row is needed.
# -------------------------------------------------------------
param_row <- function(id, label, min_val, max_val, step_val, step_step = 1) {
  fluidRow(
    column(3, tags$label(label)),
    column(2, numericInput(paste0(id, "_min"),  "Min",  value = min_val,  step = step_step)),
    column(2, numericInput(paste0(id, "_max"),  "Max",  value = max_val,  step = step_step)),
    column(2, numericInput(paste0(id, "_step"), "Step", value = step_val, step = step_step, min = 0))
  )
}

# -------------------------------------------------------------
# 4. UI
# Single-page layout (no tabs). All parameter sections,
# SCC settings, and generation buttons are on one page.
# -------------------------------------------------------------
ui <- fluidPage(
  useShinyjs(),
  titlePanel("MPC in Buildings \u2013 Parametric Simulation Configuration"),
  br(),
  
  # -------------------------------------------------------------
  # 4.1. Optimization parameters section
  # -------------------------------------------------------------
  wellPanel(
    h4(icon("sliders"), " Optimization Parameters",
       tags$small(em(" (optimization_parameters.csv)"))),
    param_row("population_size",                   "Population Size",              cfg_num("population_size_min"),  cfg_num("population_size_max"), cfg_num("population_size_step")),
    param_row("iteration_number",                  "Iteration Number",             cfg_num("iteration_number_min"),  cfg_num("iteration_number_max"), cfg_num("iteration_number_step")),
    param_row("run_number",                        "Run Number",                    cfg_num("run_number_min"),   cfg_num("run_number_max"),  cfg_num("run_number_step")),
    param_row("pcrossover",                        "Crossover Probability",         cfg_num("pcrossover_min"),   cfg_num("pcrossover_max"),  cfg_num("pcrossover_step"), step_step = 0.01),
    param_row("pmutation",                         "Mutation Probability",        cfg_num("pmutation_min"), cfg_num("pmutation_max"), cfg_num("pmutation_step"), step_step = 0.01),
    param_row("control_optimization_horizon",      "Optimization Horizon (h)",     cfg_num("control_optimization_horizon_min"),  cfg_num("control_optimization_horizon_max"), cfg_num("control_optimization_horizon_step")),
    param_row("control_implementation_horizon",    "Implementation Horizon (h)",   cfg_num("control_implementation_horizon_min"),  cfg_num("control_implementation_horizon_max"), cfg_num("control_implementation_horizon_step")),
    param_row("control_optimization_anticipation", "Anticipation (h)",              cfg_num("control_optimization_anticipation_min"),  cfg_num("control_optimization_anticipation_max"), cfg_num("control_optimization_anticipation_step"))
  ),
  
  # -------------------------------------------------------------
  # 4.2. Control parameters section
  # -------------------------------------------------------------
  wellPanel(
    h4(icon("cog"), " Control Parameters",
       tags$small(em(" (control_parameters.csv)"))),
    fluidRow(
      column(6,
             checkboxGroupInput(
               "control_type",
               "Control Type",
               choices  = c("Modes (1)"    = 1, "Setpoint (2)" = 2),
               selected = as.integer(
                 trimws(unlist(strsplit(cfg_chr("control_type"), ",")))
               )
             )
      ),
      column(6,
             checkboxGroupInput(
               "optimization_aim",
               "Optimization Aim",
               choices  = c("Energy (1)" = 1, "Flexibility (2)" = 2),
               selected = as.integer(
                 trimws(unlist(strsplit(cfg_chr("optimization_aim"), ",")))
               )
             )
      )
    ),
    param_row("flexibility_event_length_max",   "Event Length (h)",             cfg_num("flexibility_event_length_max_min"),   cfg_num("flexibility_event_length_max_max"), cfg_num("flexibility_event_length_max_step"), 0.25),
    param_row("flexibility_recover_timespan",   "Recover Timespan (h)",         cfg_num("flexibility_recover_timespan_min"),   cfg_num("flexibility_recover_timespan_max"), cfg_num("flexibility_recover_timespan_step"), 0.25),
    param_row("thermal_stabilization_timespan", "Thermal Stabilization (h)",    cfg_num("thermal_stabilization_timespan_min"),   cfg_num("thermal_stabilization_timespan_max"), cfg_num("thermal_stabilization_timespan_step"), 0.25),
    param_row("minimum_flexibility",            "Minimum Flexibility (kW)",     cfg_num("minimum_flexibility_min"), cfg_num("minimum_flexibility_max"), cfg_num("minimum_flexibility_step"), 0.5),
    param_row("flexibility_splits",             "Flexibility Splits",            cfg_num("flexibility_splits_min"),   cfg_num("flexibility_splits_max"), cfg_num("flexibility_splits_step"), 1)
  ),
  
  # -------------------------------------------------------------
  # 4.3. Reward parameters section
  # -------------------------------------------------------------
  wellPanel(
    h4(icon("star"), " Reward Parameters",
       tags$small(em(" (reward_parameters.csv)"))),
    param_row("Alpha_confort", "Alpha (comfort weight)", cfg_num("Alpha_confort_min"), cfg_num("Alpha_confort_max"), cfg_num("Alpha_confort_step"), 0.1)
  ),
  
  # -------------------------------------------------------------
  # 4.4. Debug/Config parameters section
  # -------------------------------------------------------------
  wellPanel(
    h4(icon("calendar"), " Debug & Config Parameters",
       tags$small(em(" (debug_and_config.csv)"))),
    checkboxGroupInput(
      "month_subset",
      "Month Subset (0 = full year)",
      choices  = setNames(0:12, c("Full year (0)", paste("Month", 1:12))),
      selected = as.integer(
        trimws(unlist(strsplit(cfg_chr("month_subset"), ",")))
      ),
      inline   = TRUE
    )
  ),
  
  # -------------------------------------------------------------
  # 4.5. SCC Settings section
  # Job name, tasks per job, partition, user, etc.
  # -------------------------------------------------------------
  wellPanel(
    h4(icon("server"), " SCC Settings"),
    fluidRow(
      column(3,
             textInput("job_name",
                       "Job name (for Slurm)",
                       value = cfg_chr("job_name"))
      ),
      column(2,
             textInput("scc_queue",
                       "Slurm partition",
                       value = cfg_chr("scc_queue"))
      ),
      column(2,
             textInput("scc_qos",
                       "Quality of Service (qos)",
                       value = cfg_chr("scc_qos"))
      ),
      column(2,
             textInput("scc_username",
                       "Username (for squeue)",
                       value = cfg_chr("scc_username"))
      ),
      column(3,
             textInput("scc_user",
                       "User email (mail-user)",
                       value = cfg_chr("scc_user"))
      )
    ),
    fluidRow(
      column(4,
             numericInput("tasks_per_job",
                          "Tasks (configurations) per job",
                          value = cfg_num("tasks_per_job"), min = 1, step = 50)
      ),
      column(4,
             checkboxGroupInput("output_formats",
                                "Output file formats",
                                choices  = c("Main_df CSV"              = "main_csv",
                                             "Main_df RDS"              = "main_rds",
                                             "Sinthetized_df_computed CSV" = "synth_csv",
                                             "Sinthetized_df_computed RDS" = "synth_rds"),
                                selected = trimws(unlist(
                                  strsplit(cfg_chr("output_formats"), ",")
                                )),
                                inline   = FALSE)
      ),
      column(4,
             br(),
             helpText(
               "Tasks per job defines how many configurations (tasks)",
               "are grouped into one Slurm job array.",
               "Pass n as argument to Console_code.txt to submit",
               "only a specific job, e.g.:",
               "  bash \"02_SCC_simulation/Console_code.txt\" 2",
               "or n=0 (default) for all jobs.",
               "Finished jobs automatically launch pending ones."
             )
      )
    )
  ),
  
  # -------------------------------------------------------------
  # 4.6. Configuration Generation buttons
  # Estimated count, generation buttons, summary, and save.
  # -------------------------------------------------------------
  wellPanel(
    h4(icon("cogs"), " Configuration Generation"),
    
    # --- 4.6.1. Estimated configuration count ---
    fluidRow(
      column(12,
             tags$strong("Estimated full-factorial configurations: "),
             textOutput("estimated_config_count", inline = TRUE)
      )
    ),
    br(),
    
    # --- 4.6.2. Generation buttons ---
    fluidRow(
      column(4,
             actionButton("btn_generate", "Generate Full Factorial",
                          class = "btn-primary btn-lg",
                          icon  = icon("table")),
             br(),
             tags$small(em("Replaces current configuration file"))
      ),
      column(4,
             actionButton("btn_append",
                          "Append Full Factorial to Configuration File",
                          class = "btn-info btn-lg",
                          icon  = icon("plus-circle")),
             br(),
             tags$small(em("Adds new configurations to existing file"))
      ),
      column(4,
             actionButton("btn_lhs", "Generate Latin Hypercube Sample",
                          class = "btn-warning btn-lg",
                          icon  = icon("random")),
             br(),
             numericInput("lhs_n_samples",
                          "Number of LHS samples",
                          value = cfg_num("lhs_n_samples"), min = 1, step = 10)
      )
    ),
    br(),
    fluidRow(
      column(12, textOutput("msg_generate"))
    ),
    
    hr(),
    
    # --- 4.6.3. Summary and save ---
    fluidRow(
      column(6, verbatimTextOutput("selection_summary"))
    ),
    br(),
    fluidRow(
      column(12,
             actionButton("btn_save", "Generate Configuration File",
                          class = "btn-success btn-lg",
                          icon  = icon("save")),
             textOutput("msg_save")
      )
    )
  )
) # end fluidPage

# -------------------------------------------------------------
# 5. Server
# -------------------------------------------------------------
server <- function(input, output, session) {
  
  # -------------------------------------------------------------
  # 5.1. Reactive values and parameter builder
  # config_rv holds the current configuration data.frame.
  # build_params() reads all input widgets and returns a named
  # list of parameter vectors.
  # -------------------------------------------------------------
  {
    config_rv <- reactiveVal(NULL)
    
    build_params <- reactive({
      list(
        population_size                   = build_param_range(input$population_size_min,
                                                              input$population_size_max,
                                                              input$population_size_step),
        iteration_number                  = build_param_range(input$iteration_number_min,
                                                              input$iteration_number_max,
                                                              input$iteration_number_step),
        run_number                        = build_param_range(input$run_number_min,
                                                              input$run_number_max,
                                                              input$run_number_step),
        pcrossover                        = build_param_range(input$pcrossover_min,
                                                              input$pcrossover_max,
                                                              input$pcrossover_step),
        pmutation                         = build_param_range(input$pmutation_min,
                                                              input$pmutation_max,
                                                              input$pmutation_step),
        control_optimization_horizon      = build_param_range(input$control_optimization_horizon_min,
                                                              input$control_optimization_horizon_max,
                                                              input$control_optimization_horizon_step),
        control_implementation_horizon    = build_param_range(input$control_implementation_horizon_min,
                                                              input$control_implementation_horizon_max,
                                                              input$control_implementation_horizon_step),
        control_optimization_anticipation = build_param_range(input$control_optimization_anticipation_min,
                                                              input$control_optimization_anticipation_max,
                                                              input$control_optimization_anticipation_step),
        control_type                      = as.integer(input$control_type),
        optimization_aim                  = as.integer(input$optimization_aim),
        flexibility_event_length_max      = build_param_range(input$flexibility_event_length_max_min,
                                                              input$flexibility_event_length_max_max,
                                                              input$flexibility_event_length_max_step),
        flexibility_recover_timespan      = build_param_range(input$flexibility_recover_timespan_min,
                                                              input$flexibility_recover_timespan_max,
                                                              input$flexibility_recover_timespan_step),
        thermal_stabilization_timespan    = build_param_range(input$thermal_stabilization_timespan_min,
                                                              input$thermal_stabilization_timespan_max,
                                                              input$thermal_stabilization_timespan_step),
        minimum_flexibility               = build_param_range(input$minimum_flexibility_min,
                                                              input$minimum_flexibility_max,
                                                              input$minimum_flexibility_step),
        flexibility_splits                = as.integer(build_param_range(input$flexibility_splits_min,
                                                                         input$flexibility_splits_max,
                                                                         input$flexibility_splits_step)),
        Alpha_confort                     = build_param_range(input$Alpha_confort_min,
                                                              input$Alpha_confort_max,
                                                              input$Alpha_confort_step),
        month_subset                      = as.integer(input$month_subset)
      )
    })
  }
  
  # -------------------------------------------------------------
  # 5.1b. Load existing SCC settings on startup
  # Reads scc_settings.sh from 02_SCC_simulation/ and updates
  # the GUI widgets with the stored values. This ensures the
  # GUI reflects the current cluster configuration.
  # -------------------------------------------------------------
  {
    session$onFlushed(function() {
      settings_file <- file.path(scc_path, "scc_settings.sh")
      if (file.exists(settings_file)) {
        lines <- readLines(settings_file, warn = FALSE)
        
        # Helper to extract a value from a KEY="value" or KEY=value line
        extract_val <- function(key) {
          pattern <- paste0("^", key, "=")
          matched <- grep(pattern, lines, value = TRUE)
          if (length(matched) == 0) return(NULL)
          val <- sub(paste0("^", key, "="), "", matched[1])
          val <- gsub('^"|"$', "", val)
          val
        }
        
        val <- extract_val("TASKS_PER_JOB")
        if (!is.null(val) && nzchar(val)) {
          updateNumericInput(session, "tasks_per_job", value = as.integer(val))
        }
        
        val <- extract_val("JOB_NAME")
        if (!is.null(val) && nzchar(val)) {
          updateTextInput(session, "job_name", value = val)
        }
        
        val <- extract_val("SCC_QUEUE")
        if (!is.null(val) && nzchar(val)) {
          updateTextInput(session, "scc_queue", value = val)
        }
        
        val <- extract_val("SCC_QOS")
        if (!is.null(val) && nzchar(val)) {
          updateTextInput(session, "scc_qos", value = val)
        }
        
        val <- extract_val("SCC_USER")
        if (!is.null(val)) {
          updateTextInput(session, "scc_user", value = val)
        }
        
        val <- extract_val("SCC_USERNAME")
        if (!is.null(val)) {
          updateTextInput(session, "scc_username", value = val)
        }
        
        val <- extract_val("SCC_OUTPUT_FORMATS")
        if (!is.null(val) && nzchar(val)) {
          formats <- trimws(unlist(strsplit(val, ",")))
          updateCheckboxGroupInput(session, "output_formats", selected = formats)
        }
      }
    }, once = TRUE)
  }
  
  # -------------------------------------------------------------
  # 5.2. Estimated configuration count
  # Reactively computes the number of full-factorial
  # configurations based on the current parameter ranges.
  # Displayed next to the Generate Full Factorial button.
  # -------------------------------------------------------------
  {
    output$estimated_config_count <- renderText({
      tryCatch({
        params     <- build_params()
        n_levels   <- vapply(params, length, integer(1))
        total_rows <- prod(as.numeric(n_levels))
        format(total_rows, big.mark = ",")
      }, error = function(e) {
        paste("(error:", conditionMessage(e), ")")
      })
    })
  }
  
  # -------------------------------------------------------------
  # 5.3. Generate Full Factorial (replaces current config)
  # -------------------------------------------------------------
  {
    observeEvent(input$btn_generate, {
      result <- tryCatch({
        params <- build_params()
        
        # Validate checkbox selections
        if (length(params$control_type) == 0)    stop("Select at least one Control Type.")
        if (length(params$optimization_aim) == 0) stop("Select at least one Optimization Aim.")
        if (length(params$month_subset) == 0)    stop("Select at least one Month Subset.")
        
        n_levels   <- vapply(params, length, integer(1))
        total_rows <- prod(as.numeric(n_levels))
        est_mb     <- total_rows * length(params) * 8 / 1e6
        message(sprintf(
          "[GUI_parametric] Estimated full factorial: %s rows, %.1f MB",
          format(total_rows, big.mark = ","), est_mb
        ))
        
        withProgress(
          message = sprintf("Generating %s configurations...",
                            format(total_rows, big.mark = ",")),
          value   = 0,
          {
            progress_callback <- function(current, total) {
              setProgress(value = current / total,
                          detail = sprintf("%s / %s rows",
                                           format(current, big.mark = ","),
                                           format(total,   big.mark = ",")))
            }
            df <- generate_full_factorial(params,
                                          chunk_size  = 50000L,
                                          progress_fn = progress_callback)
          }
        )
        
        config_rv(df)
        
        output$msg_generate <- renderText(
          sprintf(
            "\u2714 Generated %s configurations (%.1f MB).",
            format(nrow(df), big.mark = ","), est_mb
          )
        )
        NULL
        
      }, error = function(e) {
        output$msg_generate <- renderText(
          paste("\u2718 Error:", conditionMessage(e))
        )
        NULL
      })
    })
  }
  
  # -------------------------------------------------------------
  # 5.4. Append Full Factorial to existing configuration
  # Generates a full factorial from current parameters and
  # appends (row-binds) the new rows to the existing config_rv.
  # Duplicate rows are removed after appending.
  # -------------------------------------------------------------
  {
    observeEvent(input$btn_append, {
      result <- tryCatch({
        params <- build_params()
        
        if (length(params$control_type) == 0)    stop("Select at least one Control Type.")
        if (length(params$optimization_aim) == 0) stop("Select at least one Optimization Aim.")
        if (length(params$month_subset) == 0)    stop("Select at least one Month Subset.")
        
        n_levels   <- vapply(params, length, integer(1))
        total_rows <- prod(as.numeric(n_levels))
        
        withProgress(
          message = sprintf("Generating %s configurations to append...",
                            format(total_rows, big.mark = ",")),
          value   = 0,
          {
            progress_callback <- function(current, total) {
              setProgress(value = current / total,
                          detail = sprintf("%s / %s rows",
                                           format(current, big.mark = ","),
                                           format(total,   big.mark = ",")))
            }
            new_df <- generate_full_factorial(params,
                                              chunk_size  = 50000L,
                                              progress_fn = progress_callback)
          }
        )
        
        existing <- config_rv()
        if (!is.null(existing) && nrow(existing) > 0) {
          combined <- rbind(existing, new_df)
          combined <- unique(combined)
          rownames(combined) <- NULL
        } else {
          combined <- new_df
        }
        
        config_rv(combined)
        
        n_added <- nrow(combined) - ifelse(is.null(existing), 0L, nrow(existing))
        output$msg_generate <- renderText(
          sprintf(
            paste0("\u2714 Appended %s new configurations ",
                   "(%s duplicates removed). Total: %s."),
            format(nrow(new_df), big.mark = ","),
            format(nrow(new_df) - n_added, big.mark = ","),
            format(nrow(combined), big.mark = ",")
          )
        )
        NULL
        
      }, error = function(e) {
        output$msg_generate <- renderText(
          paste("\u2718 Error:", conditionMessage(e))
        )
        NULL
      })
    })
  }
  
  # -------------------------------------------------------------
  # 5.5. Generate Latin Hypercube Sample
  # Uses the LHS function to generate a space-filling design
  # with the specified number of samples.
  # -------------------------------------------------------------
  {
    observeEvent(input$btn_lhs, {
      result <- tryCatch({
        params    <- build_params()
        n_samples <- as.integer(input$lhs_n_samples)
        
        if (length(params$control_type) == 0)    stop("Select at least one Control Type.")
        if (length(params$optimization_aim) == 0) stop("Select at least one Optimization Aim.")
        if (length(params$month_subset) == 0)    stop("Select at least one Month Subset.")
        if (is.na(n_samples) || n_samples < 1)   stop("Number of LHS samples must be >= 1.")
        
        withProgress(
          message = sprintf("Generating %d LHS samples...", n_samples),
          value   = 0.5,
          {
            df <- generate_lhs_design(params,
                                      n_samples = n_samples)
          }
        )
        
        config_rv(df)
        
        output$msg_generate <- renderText(
          sprintf(
            "\u2714 Generated %s LHS configurations.",
            format(nrow(df), big.mark = ",")
          )
        )
        NULL
        
      }, error = function(e) {
        output$msg_generate <- renderText(
          paste("\u2718 Error:", conditionMessage(e))
        )
        NULL
      })
    })
  }
  
  # -------------------------------------------------------------
  # 5.6. Configuration summary
  # Shows current config size, tasks per job, and estimated
  # number of jobs to submit.
  # -------------------------------------------------------------
  {
    output$selection_summary <- renderText({
      df <- config_rv()
      if (is.null(df)) return("No configurations generated yet.")
      n_total      <- nrow(df)
      tasks_per    <- input$tasks_per_job
      n_jobs       <- ceiling(n_total / max(tasks_per, 1))
      paste0(
        "Total configurations:       ", format(n_total, big.mark = ","), "\n",
        "Tasks (configurations)/job: ", tasks_per,   "\n",
        "Estimated jobs to submit:   ", n_jobs
      )
    })
  }
  
  # -------------------------------------------------------------
  # 5.7. Save configuration file
  # Writes Optim_parameters.csv and scc_settings.sh with
  # the current configuration and SCC settings.
  # -------------------------------------------------------------
  {
    observeEvent(input$btn_save, {
      df <- config_rv()
      
      if (is.null(df) || nrow(df) == 0) {
        output$msg_save <- renderText(
          "\u2718 No configurations. Generate data first."
        )
        return()
      }
      
      tryCatch({
        result <- save_optim_params(
          df,
          scc_path,
          tasks_per_job  = input$tasks_per_job,
          scc_queue      = input$scc_queue,
          scc_qos        = input$scc_qos,
          scc_user       = input$scc_user,
          scc_username   = input$scc_username,
          output_formats = input$output_formats,
          job_name       = input$job_name
        )
        output$msg_save <- renderText(sprintf(
          "\u2714 Saved %s configurations to:\n  %s\n  %s\n  %s",
          format(nrow(df), big.mark = ","),
          result$csv_path,
          result$sh_path,
          result$ext_path
        ))
      }, error = function(e) {
        output$msg_save <- renderText(
          paste("\u2718 Error saving:", conditionMessage(e))
        )
      })
    })
  }
  
} # end server

# -------------------------------------------------------------
# 6. Launch
# -------------------------------------------------------------
shinyApp(ui = ui, server = server)
