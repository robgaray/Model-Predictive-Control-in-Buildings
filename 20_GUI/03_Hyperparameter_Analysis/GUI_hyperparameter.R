# -------------------------------------------------------------
# Script: GUI_hyperparameter.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Shiny GUI for the hyperparameter sensitivity analysis.
# Provides an interactive graphical interface for the workflow
# implemented in PostProcess_hyperparameter_analysis.R,
# replacing readline() prompts with Shiny widgets.
#
# Workflow:
#   1. Enter the input directory and load data.
#   2. Select which varying parameters to include in the
#      analysis; define min-max ranges for excluded parameters.
#   3. Configure boxplot threshold percentiles and outlier
#      display once (applied to all plots).
#   4. Run iterations one at a time or all at once.
#      Before each iteration (from the second), optionally
#      redefine the parameter selection for that pass.
#   5. Inspect the generated boxplots and frequency charts
#      inside the app.
#   6. Save all output plots and selected configurations to
#      the output directory.
# -------------------------------------------------------------
# Inputs
#   User interaction via Shiny widgets.
#   Default values loaded from:
#     02_Config/GUI_hyperparameter_config.csv
#   Sinthetized_df_computed_* files from the input directory.
# -------------------------------------------------------------
# Outputs
#   Plots displayed interactively in the app.
#   On save: reward_vs_*.jpg, process_time_vs_*.jpg,
#            freq_*.jpg, global_df.csv/.rds,
#            selected_configurations.csv/.rds
# -------------------------------------------------------------
# Code outline
#   1. Path resolution
#   2. Source helper functions
#   3. Load GUI configuration defaults
#   4. UI definition
#      4.1. Data Input section
#      4.2. Parameter Settings section
#      4.3. Boxplot Settings section
#      4.4. Analysis & Plots section
#      4.5. Save Outputs section
#   5. Server logic
#      5.1. Reactive state values
#      5.2. Load data
#      5.3. Parameter settings helpers
#      5.4. Apply parameter settings
#      5.5. Run one iteration
#      5.6. Reset analysis
#      5.7. Dynamic parameter selection UI
#      5.8. Dynamic plot rendering
#      5.9. Save outputs
#   6. Launch app
# -------------------------------------------------------------
# Usage instructions
#   Run from the repository root:
#     shiny::runApp("20_GUI/03_Hyperparameter_Analysis")
#   Or source this file directly.
# -------------------------------------------------------------
# Where this function/script is used
#   Standalone Shiny app, launched by the user.
# -------------------------------------------------------------
# functions/scripts called
#   load_hyperparameter_data.R  (from PostProcess 03_Functions/)
#   compute_boxplot_stats.R     (from PostProcess 03_Functions/)
#   plot_and_save.R             (from PostProcess 03_Functions/)
# -------------------------------------------------------------

library(shiny)
library(shinyjs)

# -------------------------------------------------------------
# 1. Path resolution
# Shiny sets getwd() to the app directory at launch.
# The app lives at 20_GUI/03_Hyperparameter_Analysis/ so the
# repo root is two levels up.
# -------------------------------------------------------------
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

  if (!grepl("03_Hyperparameter_Analysis", app_dir, fixed = TRUE)) {
    candidate <- file.path(app_dir,
                           "20_GUI",
                           "03_Hyperparameter_Analysis")
    if (dir.exists(candidate)) {
      app_dir <- normalizePath(candidate)
    } else {
      stop(
        "GUI_hyperparameter.R: cannot locate ",
        "'20_GUI/03_Hyperparameter_Analysis' under '",
        app_dir, "'. ",
        "Run this script from the repo root or from the app folder."
      )
    }
  }

  repo_root <- normalizePath(file.path(app_dir, "..", ".."))
}

# -------------------------------------------------------------
# 2. Source helper functions
# Functions are shared with PostProcess_hyperparameter_analysis.R
# and reside in the PostProcess 03_Functions folder.
# -------------------------------------------------------------
{
  pp_func_dir <- file.path(repo_root,
                           "40_PostProcess",
                           "01_Hyperparameter_Analysis",
                           "03_Functions")
  source(file.path(pp_func_dir, "load_hyperparameter_data.R"))
  source(file.path(pp_func_dir, "compute_boxplot_stats.R"))
  source(file.path(pp_func_dir, "plot_and_save.R"))
}

# All candidate parameter names (same order as main script)
all_candidate_vars <- c(
  "population_size",
  "iteration_number",
  "run_number",
  "pcrossover",
  "pmutation",
  "control_optimization_horizon",
  "control_implementation_horizon",
  "control_optimization_anticipation",
  "control_type",
  "optimization_aim",
  "flexibility_event_length_max",
  "flexibility_recover_timespan",
  "thermal_stabilization_timespan",
  "minimum_flexibility",
  "flexibility_splits",
  "Alpha_Service_Min",
  "month_subset"
)

# -------------------------------------------------------------
# 3. Load GUI configuration defaults
# Reads default widget values from 02_Config/
# -------------------------------------------------------------
{
  gui_config_path <- file.path(app_dir, "02_Config",
                               "GUI_hyperparameter_config.csv")
  gui_defaults    <- read.csv(gui_config_path,
                              stringsAsFactors = FALSE,
                              strip.white      = TRUE)
  rownames(gui_defaults) <- gui_defaults$Parameter

  cfg_num <- function(param) as.numeric(gui_defaults[param, "Value"])
  cfg_chr <- function(param) as.character(gui_defaults[param, "Value"])
  cfg_lgl <- function(param) as.logical(gui_defaults[param, "Value"])
}

# -------------------------------------------------------------
# 4. UI definition
# Single-page layout. Sections are shown/hidden reactively
# via shinyjs as the user progresses through the workflow.
# -------------------------------------------------------------
ui <- fluidPage(
  useShinyjs(),
  titlePanel("MPC in Buildings \u2013 Hyperparameter Analysis"),
  br(),

  # -----------------------------------------------------------
  # 4.1. Data Input section
  # User specifies the input directory and loads the data.
  # -----------------------------------------------------------
  wellPanel(
    h4(icon("folder-open"), " 1. Data Input"),
    fluidRow(
      column(8,
             textInput("input_dir",
                       "Input directory (relative to repo root or absolute)",
                       value = cfg_chr("input_dir"))
      ),
      column(2,
             br(),
             actionButton("btn_load",
                          "Load Data",
                          class = "btn-primary btn-lg",
                          icon  = icon("upload"))
      )
    ),
    fluidRow(
      column(12, verbatimTextOutput("status_load"))
    )
  ),

  # -----------------------------------------------------------
  # 4.2. Parameter Settings section
  # Shown after data is loaded. For each varying parameter the
  # user selects Y/N (include in analysis). Excluded parameters
  # show stats and min-max range inputs.
  # -----------------------------------------------------------
  div(
    id = "div_params",
    wellPanel(
      h4(icon("sliders"), " 2. Parameter Settings"),
      helpText(
        "Check parameters to include in the sensitivity analysis.",
        "For unchecked parameters, specify the min-max range to",
        "use for filtering configurations."
      ),
      uiOutput("ui_param_rows"),
      br(),
      actionButton("btn_apply_params",
                   "Apply Parameter Settings",
                   class = "btn-primary",
                   icon  = icon("check")),
      verbatimTextOutput("status_params")
    )
  ),

  # -----------------------------------------------------------
  # 4.3. Boxplot Settings section
  # Always visible. User defines percentile thresholds and
  # chooses mean/median as the center statistic, plus whether
  # to show outliers. Applied to all plots.
  # -----------------------------------------------------------
  wellPanel(
    h4(icon("bar-chart"), " 3. Boxplot Settings"),
    helpText(
      "Define the percentile thresholds for boxplot elements.",
      "These settings are used for all plots in all iterations.",
      "Adaptive Y axis scales each iteration to its data range (always including 0)."
    ),
    fluidRow(
      column(2,
             numericInput("bxp_lower_pct",
                          "Lower whisker (%)",
                          value = cfg_num("lower_pct"),
                          min   = 0,
                          max   = 100,
                          step  = 1)
      ),
      column(2,
             numericInput("bxp_lower_box_pct",
                          "Lower box edge (%)",
                          value = cfg_num("lower_box_pct"),
                          min   = 0,
                          max   = 100,
                          step  = 1)
      ),
      column(2,
             selectInput("bxp_center_type",
                         "Center statistic",
                         choices  = c("median", "mean"),
                         selected = cfg_chr("center_type"))
      ),
      column(2,
             numericInput("bxp_upper_box_pct",
                          "Upper box edge (%)",
                          value = cfg_num("upper_box_pct"),
                          min   = 0,
                          max   = 100,
                          step  = 1)
      ),
      column(2,
             numericInput("bxp_upper_pct",
                          "Upper whisker (%)",
                          value = cfg_num("upper_pct"),
                          min   = 0,
                          max   = 100,
                          step  = 1)
      ),
      column(2,
             br(),
             checkboxInput("bxp_show_outliers",
                           "Show outliers",
                           value = cfg_lgl("show_outliers"))
      ),
      column(2,
             br(),
             checkboxInput("bxp_adaptive_y",
                           "Adaptive Y axis",
                           value = cfg_lgl("adaptive_y_axis"))
      )
    )
  ),

  # -----------------------------------------------------------
  # 4.4. Analysis & Plots section
  # Shown after parameter settings are applied.
  # Controls for running iterations and displaying plots.
  # -----------------------------------------------------------
  div(
    id = "div_analysis",
    wellPanel(
      h4(icon("play-circle"), " 4. Analysis"),
      verbatimTextOutput("status_analysis"),
      br(),
      fluidRow(
        column(3,
               actionButton("btn_run_iter",
                            "Run Next Iteration",
                            class = "btn-success btn-lg",
                            icon  = icon("step-forward"))
        ),
        column(3,
               actionButton("btn_run_all",
                            "Run All Iterations",
                            class = "btn-warning btn-lg",
                            icon  = icon("fast-forward"))
        ),
        column(3,
               actionButton("btn_reset",
                            "Reset",
                            class = "btn-danger",
                            icon  = icon("undo"))
        ),
        column(3,
               br(),
               checkboxInput(
                 "chk_diff_params",
                 "Use different parameter selection for next iteration",
                 value = FALSE)
        )
      ),
      br(),
      uiOutput("ui_plots")
    )
  ),

  # -----------------------------------------------------------
  # 4.5. Save Outputs section
  # Shown after at least one iteration has been run.
  # Saves all generated plots and dataframes to the output
  # directory.
  # -----------------------------------------------------------
  div(
    id = "div_save",
    wellPanel(
      h4(icon("save"), " 5. Save Outputs"),
      fluidRow(
        column(8,
               textInput("output_dir",
                         "Output directory (relative to repo root or absolute)",
                         value = cfg_chr("output_dir"))
        ),
        column(2,
               br(),
               actionButton("btn_save",
                            "Save All Outputs",
                            class = "btn-success btn-lg",
                            icon  = icon("download"))
        )
      ),
      verbatimTextOutput("status_save")
    )
  )

) # end fluidPage

# -------------------------------------------------------------
# 5. Server logic
# -------------------------------------------------------------
server <- function(input, output, session) {

  # -----------------------------------------------------------
  # 5.1. Reactive state values
  # Holds all mutable state that drives the analysis workflow.
  # -----------------------------------------------------------
  {
    rv <- reactiveValues(
      global_df      = NULL,
      varying_vars   = character(0),
      analysis_df    = NULL,
      current_df     = NULL,
      expl_vars      = character(0),
      global_rew_ylim = NULL,
      global_pt_ylim  = NULL,
      global_groups   = list(),
      iter           = 0,
      iter_plots     = list(),
      status_load    = "No data loaded.",
      status_params  = "",
      status_analysis = "Apply parameter settings to begin analysis.",
      status_save    = ""
    )
  }

  # Hide sections until relevant steps are completed
  shinyjs::hide("div_params")
  shinyjs::hide("div_analysis")
  shinyjs::hide("div_save")

  # -----------------------------------------------------------
  # 5.2. Load data
  # Reads and merges all input files using
  # load_hyperparameter_data(). Computes which parameters vary
  # and stores global axis limits for all subsequent plots.
  # -----------------------------------------------------------
  {
    observeEvent(input$btn_load, {

      rv$status_load <- "Loading data..."

      result <- tryCatch({

        dir_  <- input$input_dir
        if (!dir.exists(dir_)) {
          dir_ <- file.path(repo_root, dir_)
        }

        progress_fn_ <- function(current, total, elapsed_sec) {
          rate_      <- if (elapsed_sec > 0) current / elapsed_sec else NA_real_
          remaining_ <- if (!is.na(rate_) && rate_ > 0 && current < total) {
            (total - current) / rate_
          } else {
            NA_real_
          }
          rv$status_load <- sprintf(
            "Loading: %d / %d files. Elapsed: %.1f s.%s",
            current, total, elapsed_sec,
            if (!is.na(remaining_)) {
              sprintf(" Est. remaining: %.1f s.", remaining_)
            } else {
              ""
            })
        }

        gdf <- load_hyperparameter_data(dir_, progress_fn = progress_fn_)
        rm(progress_fn_)

        # Identify varying parameters
        vv <- character(0)
        for (v_ in all_candidate_vars) {
          if (v_ %in% names(gdf) &&
              length(unique(gdf[[v_]])) > 1) {
            vv <- c(vv, v_)
          }
        }

        # Global axis limits (include 0 + data min/max)
        rew_ymin_  <- min(c(0, gdf$reward),       na.rm = TRUE)
        rew_ymax_  <- max(gdf$reward,              na.rm = TRUE)
        rew_ylim   <- c(rew_ymin_ * ifelse(rew_ymin_ < 0, 1.15, 1),
                        rew_ymax_ * ifelse(rew_ymax_ > 0, 1.15, 1))

        pt_ymin_   <- min(c(0, gdf$process_time), na.rm = TRUE)
        pt_ymax_   <- max(gdf$process_time,        na.rm = TRUE)
        pt_ylim    <- c(pt_ymin_ * ifelse(pt_ymin_ < 0, 1.15, 1),
                        pt_ymax_ * ifelse(pt_ymax_ > 0, 1.15, 1))

        gg <- list()
        for (v_ in all_candidate_vars) {
          if (v_ %in% names(gdf)) {
            gg[[v_]] <- sort(unique(gdf[[v_]]))
          }
        }

        list(gdf     = gdf,
             vv      = vv,
             rew_ylim = rew_ylim,
             pt_ylim  = pt_ylim,
             gg       = gg)

      }, error = function(e) {
        list(error = conditionMessage(e))
      })

      if (!is.null(result$error)) {
        rv$status_load <- paste("Error:", result$error)
        return()
      }

      rv$global_df       <- result$gdf
      rv$varying_vars    <- result$vv
      rv$global_rew_ylim <- result$rew_ylim
      rv$global_pt_ylim  <- result$pt_ylim
      rv$global_groups   <- result$gg
      rv$analysis_df     <- result$gdf
      rv$current_df      <- result$gdf
      rv$iter            <- 0
      rv$iter_plots      <- list()

      rv$status_load <- paste0(
        "Loaded ", nrow(result$gdf), " rows, ",
        ncol(result$gdf), " columns.\n",
        "Varying parameters: ",
        paste(result$vv, collapse = ", "))

      shinyjs::show("div_params")
      shinyjs::hide("div_analysis")
      shinyjs::hide("div_save")
      rv$status_params  <- ""
      rv$status_analysis <- "Apply parameter settings to begin."
    })

    output$status_load <- renderText(rv$status_load)
  }

  # -----------------------------------------------------------
  # 5.3. Parameter settings helpers
  # Build the dynamic UI rows for parameter selection.
  # Each varying parameter gets a checkbox (include/exclude)
  # and, when unchecked, two numeric range inputs.
  # -----------------------------------------------------------
  {
    output$ui_param_rows <- renderUI({

      req(rv$varying_vars)
      vv <- rv$varying_vars

      rows <- lapply(vv, function(v_) {
        gdf <- rv$global_df
        v_vals_ <- sort(unique(gdf[[v_]]))
        v_min_  <- min(gdf[[v_]], na.rm = TRUE)
        v_max_  <- max(gdf[[v_]], na.rm = TRUE)
        v_mean_ <- round(mean(gdf[[v_]], na.rm = TRUE), 4)

        tagList(
          fluidRow(
            column(3,
                   checkboxInput(
                     paste0("inc_", v_),
                     paste0(v_, " [",
                            length(v_vals_), " values; ",
                            "mean=", v_mean_, "]"),
                     value = TRUE)
            ),
            column(2,
                   conditionalPanel(
                     condition = paste0(
                       "!input.inc_", v_),
                     numericInput(
                       paste0("rmin_", v_),
                       "Range min",
                       value = v_min_,
                       step  = (v_max_ - v_min_) / 10)
                   )
            ),
            column(2,
                   conditionalPanel(
                     condition = paste0(
                       "!input.inc_", v_),
                     numericInput(
                       paste0("rmax_", v_),
                       "Range max",
                       value = v_max_,
                       step  = (v_max_ - v_min_) / 10)
                   )
            ),
            column(5,
                   conditionalPanel(
                     condition = paste0(
                       "!input.inc_", v_),
                     helpText(paste0(
                       v_, ": min=", v_min_,
                       ", max=", v_max_,
                       ", mean=", v_mean_))
                   )
            )
          )
        )
      })

      do.call(tagList, rows)
    })
  }

  # -----------------------------------------------------------
  # 5.4. Apply parameter settings
  # Reads the checkbox and range inputs, builds expl_vars
  # (selected parameters), filters analysis_df by the ranges
  # specified for excluded parameters, and resets the iteration.
  # -----------------------------------------------------------
  {
    observeEvent(input$btn_apply_params, {

      req(rv$global_df, rv$varying_vars)
      vv <- rv$varying_vars

      selected    <- character(0)
      filtered_df <- rv$global_df

      msgs <- character(0)

      for (v_ in vv) {
        inc_id_ <- paste0("inc_", v_)
        if (isTRUE(input[[inc_id_]])) {
          selected <- c(selected, v_)
        } else {
          rmin_id_ <- paste0("rmin_", v_)
          rmax_id_ <- paste0("rmax_", v_)
          r_min_   <- input[[rmin_id_]]
          r_max_   <- input[[rmax_id_]]

          if (is.null(r_min_) || is.null(r_max_) ||
              is.na(r_min_)   || is.na(r_max_)) {
            msgs <- c(msgs,
                      paste0("Invalid range for ", v_,
                             ". Using full range."))
            next
          }
          if (r_max_ < r_min_) {
            msgs <- c(msgs,
                      paste0("Range max < min for ", v_,
                             ". Skipping filter."))
            next
          }

          before_n_   <- nrow(filtered_df)
          if (r_min_ == r_max_) {
            filtered_df <- filtered_df[
              !is.na(filtered_df[[v_]]) &
                filtered_df[[v_]] == r_min_, ]
            msgs <- c(msgs,
                      paste0(v_, ": filtered [= ", r_min_,
                             "] -> ",
                             before_n_, " to ",
                             nrow(filtered_df), " rows"))
          } else {
            filtered_df <- filtered_df[
              !is.na(filtered_df[[v_]]) &
                filtered_df[[v_]] >= r_min_ &
                filtered_df[[v_]] <= r_max_, ]
            msgs <- c(msgs,
                      paste0(v_, ": filtered [", r_min_, ", ",
                             r_max_, "] -> ",
                             before_n_, " to ",
                             nrow(filtered_df), " rows"))
          }
        }
      }

      if (length(selected) == 0) {
        selected <- vv
        msgs     <- c(msgs,
                      "No parameters selected; using all varying.")
      }

      rv$expl_vars   <- selected
      rv$analysis_df <- filtered_df
      rv$current_df  <- filtered_df
      rv$iter        <- 0
      rv$iter_plots  <- list()

      rv$status_params <- paste(
        c(paste("Analysis parameters:", paste(selected, collapse=", ")),
          paste("Rows after filtering:", nrow(filtered_df)),
          msgs),
        collapse = "\n")

      rv$status_analysis <- paste0(
        "Ready. Configurations: ", nrow(filtered_df),
        "\nClick 'Run Next Iteration' to start.")

      shinyjs::show("div_analysis")
      shinyjs::hide("div_save")
    })

    output$status_params <- renderText(rv$status_params)
  }

  # -----------------------------------------------------------
  # 5.5. Run one iteration
  # Executes one full pass of the analysis:
  #   - (opt.) redefines parameter selection if checkbox is set
  #   - generates reward boxplots and filters by P75
  #   - generates process_time boxplots and filters by P50
  #   - generates frequency bar charts
  # Stores all draw functions in rv$iter_plots for display.
  # -----------------------------------------------------------
  {
    run_one_iter <- function() {

      if (is.null(rv$current_df) || nrow(rv$current_df) == 0) {
        rv$status_analysis <- "No data available. Load data first."
        return()
      }

      n_iter_max <- as.integer(cfg_num("n_iter_max"))

      if (rv$iter >= n_iter_max) {
        rv$status_analysis <- paste0(
          "Maximum iterations (", n_iter_max,
          ") reached. Reset to start over.")
        return()
      }

      if (rv$iter > 0 && nrow(rv$current_df) < 10) {
        rv$status_analysis <- paste0(
          "Fewer than 10 configurations remain (",
          nrow(rv$current_df), "). Stopping.")
        return()
      }

      # If user checked "different params for next iteration",
      # rebuild expl_vars from the current checkbox states.
      if (rv$iter > 0 && isTRUE(input$chk_diff_params)) {
        vv          <- rv$varying_vars
        selected_   <- character(0)
        filtered_   <- rv$current_df
        for (v_ in vv) {
          inc_id_ <- paste0("inc_", v_)
          if (isTRUE(input[[inc_id_]])) {
            selected_ <- c(selected_, v_)
          } else {
            rmin_id_ <- paste0("rmin_", v_)
            rmax_id_ <- paste0("rmax_", v_)
            r_min_   <- input[[rmin_id_]]
            r_max_   <- input[[rmax_id_]]
            if (!is.null(r_min_) && !is.null(r_max_) &&
                !is.na(r_min_) && !is.na(r_max_) &&
                r_max_ >= r_min_) {
              if (r_min_ == r_max_) {
                filtered_ <- filtered_[
                  !is.na(filtered_[[v_]]) &
                    filtered_[[v_]] == r_min_, ]
              } else {
                filtered_ <- filtered_[
                  !is.na(filtered_[[v_]]) &
                    filtered_[[v_]] >= r_min_ &
                    filtered_[[v_]] <= r_max_, ]
              }
            }
          }
        }
        if (length(selected_) == 0) selected_ <- vv
        rv$expl_vars  <- selected_
        rv$current_df <- filtered_
        updateCheckboxInput(session, "chk_diff_params", value = FALSE)
      }

      iter_num    <- rv$iter + 1
      expl_vars   <- rv$expl_vars
      current_df  <- rv$current_df
      bxp_params  <- list(
        lower_pct      = input$bxp_lower_pct,
        lower_box_pct  = input$bxp_lower_box_pct,
        center_type    = input$bxp_center_type,
        upper_box_pct  = input$bxp_upper_box_pct,
        upper_pct      = input$bxp_upper_pct,
        show_outliers  = input$bxp_show_outliers
      )
      adaptive_y      <- isTRUE(input$bxp_adaptive_y)
      global_groups   <- rv$global_groups
      global_rew_ylim <- rv$global_rew_ylim
      global_pt_ylim  <- rv$global_pt_ylim

      # Build frequency groups from expl_vars
      freq_groups <- list()
      for (v_ in expl_vars) freq_groups[[v_]] <- v_

      if (length(expl_vars) >= 2) {
        for (i_ in 1:(length(expl_vars) - 1)) {
          for (j_ in (i_ + 1):length(expl_vars)) {
            cn_ <- paste(expl_vars[i_], expl_vars[j_], sep = "_x_")
            freq_groups[[cn_]] <- c(expl_vars[i_], expl_vars[j_])
          }
        }
      }

      if (length(expl_vars) >= 3) {
        for (i_ in 1:(length(expl_vars) - 2)) {
          for (j_ in (i_ + 1):(length(expl_vars) - 1)) {
            for (k_ in (j_ + 1):length(expl_vars)) {
              cn_ <- paste(expl_vars[i_], expl_vars[j_],
                           expl_vars[k_], sep = "_x_")
              freq_groups[[cn_]] <- c(expl_vars[i_],
                                      expl_vars[j_],
                                      expl_vars[k_])
            }
          }
        }
      }

      # ------ Reward boxplots ------
      reward_p75  <- quantile(current_df$reward, 0.75, na.rm = TRUE)
      plots_this  <- list()

      for (xvar_ in expl_vars) {
        groups_    <- sort(unique(current_df[[xvar_]]))
        n_grp_     <- length(groups_)
        stats_mat_ <- matrix(NA_real_, nrow = 5, ncol = n_grp_)
        n_vec_     <- integer(n_grp_)
        out_vals_  <- numeric(0)
        out_grps_  <- integer(0)

        for (gi_ in seq_len(n_grp_)) {
          g_   <- groups_[gi_]
          y_g_ <- current_df$reward[
            !is.na(current_df[[xvar_]]) &
              current_df[[xvar_]] == g_]
          s_   <- compute_boxplot_stats(
            y_vals        = y_g_,
            lower_pct     = bxp_params$lower_pct,
            lower_box_pct = bxp_params$lower_box_pct,
            center_type   = bxp_params$center_type,
            upper_box_pct = bxp_params$upper_box_pct,
            upper_pct     = bxp_params$upper_pct)
          stats_mat_[, gi_] <- s_$stats
          n_vec_[gi_]        <- s_$n
          if (bxp_params$show_outliers && length(s_$out) > 0) {
            out_vals_ <- c(out_vals_, s_$out)
            out_grps_ <- c(out_grps_, rep(gi_, length(s_$out)))
          }
        }

        bxp_data_ <- list(
          stats = stats_mat_,
          n     = n_vec_,
          out   = out_vals_,
          group = out_grps_,
          names = as.character(groups_)
        )

        plot_id_  <- paste0("reward_", xvar_, "_iter", iter_num)
        ttl_      <- paste0("Reward vs ", xvar_,
                            " \u2013 Iteration ", iter_num)
        rp75_     <- reward_p75
        if (adaptive_y) {
          rew_iter_ymin_ <- min(c(0, current_df$reward), na.rm = TRUE)
          rew_iter_ymax_ <- max(current_df$reward,        na.rm = TRUE)
          yl_ <- c(rew_iter_ymin_ * ifelse(rew_iter_ymin_ < 0, 1.15, 1),
                   rew_iter_ymax_ * ifelse(rew_iter_ymax_ > 0, 1.15, 1))
          rm(rew_iter_ymin_, rew_iter_ymax_)
        } else {
          yl_ <- global_rew_ylim
        }
        show_out_ <- bxp_params$show_outliers

        draw_fn_ <- local({
          bd__   <- bxp_data_
          yl__   <- yl_
          ttl__  <- ttl_
          xv__   <- xvar_
          rp__   <- rp75_
          so__   <- show_out_
          function() {
            bxp(bd__,
                ylim     = yl__,
                xlab     = xv__,
                ylab     = "reward",
                main     = ttl__,
                outline  = so__,
                col      = "white",
                border   = "black",
                las      = 2,
                cex.axis = 0.9,
                cex.lab  = 1.1,
                cex.main = 1.1
                )
            abline(h = 0,   lty = 3, col = "grey60")
            abline(h = rp__, lty = 2, col = "black")
            legend("topright",
                   legend = paste0("P75 = ", round(rp__, 3)),
                   lty    = 2,
                   bty    = "n",
                   cex    = 0.9)
          }
        })

        plots_this[[plot_id_]] <- list(
          type    = "reward",
          xvar    = xvar_,
          iter    = iter_num,
          draw_fn = draw_fn_,
          title   = ttl_
        )
      }

      # Filter by reward P75
      current_df <- current_df[
        !is.na(current_df$reward) &
          current_df$reward > reward_p75, ]

      if (nrow(current_df) < 10 && iter_num < as.integer(cfg_num("n_iter_max"))) {
        msgs_ <- paste0("Iteration ", iter_num,
                        ": after reward filter, ",
                        nrow(current_df),
                        " configs remain (< 10). Stopping early.")
        rv$current_df  <- current_df
        rv$iter        <- iter_num
        rv$iter_plots  <- c(rv$iter_plots, plots_this)
        rv$status_analysis <- msgs_
        shinyjs::show("div_save")
        return()
      }

      # ------ Process-time boxplots ------
      process_p50 <- quantile(current_df$process_time,
                               0.50, na.rm = TRUE)

      for (xvar_ in expl_vars) {
        groups_    <- sort(unique(current_df[[xvar_]]))
        n_grp_     <- length(groups_)
        stats_mat_ <- matrix(NA_real_, nrow = 5, ncol = n_grp_)
        n_vec_     <- integer(n_grp_)
        out_vals_  <- numeric(0)
        out_grps_  <- integer(0)

        for (gi_ in seq_len(n_grp_)) {
          g_   <- groups_[gi_]
          y_g_ <- current_df$process_time[
            !is.na(current_df[[xvar_]]) &
              current_df[[xvar_]] == g_]
          s_   <- compute_boxplot_stats(
            y_vals        = y_g_,
            lower_pct     = bxp_params$lower_pct,
            lower_box_pct = bxp_params$lower_box_pct,
            center_type   = bxp_params$center_type,
            upper_box_pct = bxp_params$upper_box_pct,
            upper_pct     = bxp_params$upper_pct)
          stats_mat_[, gi_] <- s_$stats
          n_vec_[gi_]        <- s_$n
          if (bxp_params$show_outliers && length(s_$out) > 0) {
            out_vals_ <- c(out_vals_, s_$out)
            out_grps_ <- c(out_grps_, rep(gi_, length(s_$out)))
          }
        }

        bxp_data_ <- list(
          stats = stats_mat_,
          n     = n_vec_,
          out   = out_vals_,
          group = out_grps_,
          names = as.character(groups_)
        )

        plot_id_  <- paste0("process_", xvar_, "_iter", iter_num)
        ttl_      <- paste0("Process time vs ", xvar_,
                            " \u2013 Iteration ", iter_num)
        pp50_     <- process_p50
        if (adaptive_y) {
          pt_iter_ymin_ <- min(c(0, current_df$process_time), na.rm = TRUE)
          pt_iter_ymax_ <- max(current_df$process_time,        na.rm = TRUE)
          yl_ <- c(pt_iter_ymin_ * ifelse(pt_iter_ymin_ < 0, 1.15, 1),
                   pt_iter_ymax_ * ifelse(pt_iter_ymax_ > 0, 1.15, 1))
          rm(pt_iter_ymin_, pt_iter_ymax_)
        } else {
          yl_ <- global_pt_ylim
        }
        show_out_ <- bxp_params$show_outliers

        draw_fn_ <- local({
          bd__   <- bxp_data_
          yl__   <- yl_
          ttl__  <- ttl_
          xv__   <- xvar_
          pp__   <- pp50_
          so__   <- show_out_
          function() {
            bxp(bd__,
                ylim     = yl__,
                xlab     = xv__,
                ylab     = "process_time",
                main     = ttl__,
                outline  = so__,
                col      = "white",
                border   = "black",
                las      = 2,
                cex.axis = 0.9,
                cex.lab  = 1.1,
                cex.main = 1.1
                )
            abline(h = 0,   lty = 3, col = "grey60")
            abline(h = pp__, lty = 2, col = "black")
            legend("topright",
                   legend = paste0("P50 = ", round(pp__, 3)),
                   lty    = 2,
                   bty    = "n",
                   cex    = 0.9)
          }
        })

        plots_this[[plot_id_]] <- list(
          type    = "process_time",
          xvar    = xvar_,
          iter    = iter_num,
          draw_fn = draw_fn_,
          title   = ttl_
        )
      }

      # Filter by process_time P50
      current_df <- current_df[
        !is.na(current_df$process_time) &
          current_df$process_time < process_p50, ]

      # ------ Frequency bar charts ------
      for (fg_ in names(freq_groups)) {
        vf_  <- freq_groups[[fg_]]
        if (length(vf_) == 1) {
          ft_  <- table(current_df[[vf_]])
        } else {
          cf_  <- do.call(
            paste,
            c(lapply(vf_, function(v) current_df[[v]]),
              list(sep = "_")))
          ft_  <- table(cf_)
        }
        lbls_  <- names(ft_)
        yvals_ <- as.integer(ft_)
        yl_f_  <- c(0, max(as.integer(yvals_), 1L) * 1.1)
        xlab_  <- if (length(vf_) == 1) vf_ else
          paste(vf_, collapse = " x ")
        ttl_   <- paste0("Frequency: ", fg_,
                         " \u2013 Iteration ", iter_num)
        show_out_ <- bxp_params$show_outliers

        draw_fn_ <- local({
          yl__    <- yl_f_
          lbl__   <- lbls_
          yv__    <- yvals_
          xl__    <- xlab_
          ttl__   <- ttl_
          function() {
            old_m_ <- par(mar = c(8, 4, 4, 2))
            on.exit(par(old_m_), add = TRUE)
            barplot(yv__,
                    names.arg = lbl__,
                    xlab      = "",
                    ylab      = "Frequency",
                    main      = ttl__,
                    col       = "black",
                    ylim      = yl__,
                    las       = 2,
                    cex.axis  = 0.9,
                    cex.lab   = 1.1,
                    cex.main  = 1.1
                    )
            mtext(xl__, side = 1, line = 6, cex = 1.0)
          }
        })

        plot_id_ <- paste0("freq_", fg_, "_iter", iter_num)
        plots_this[[plot_id_]] <- list(
          type    = "freq",
          group   = fg_,
          iter    = iter_num,
          draw_fn = draw_fn_,
          title   = ttl_
        )
      }

      rv$current_df  <- current_df
      rv$iter        <- iter_num
      rv$iter_plots  <- c(rv$iter_plots, plots_this)
      rv$status_analysis <- paste0(
        "Iteration ", iter_num, " complete. ",
        nrow(current_df), " configurations remain.")

      shinyjs::show("div_save")
    }

    observeEvent(input$btn_run_iter, {
      run_one_iter()
    })

    observeEvent(input$btn_run_all, {
      n_iter_max_ <- as.integer(cfg_num("n_iter_max"))
      for (i_ in seq_len(n_iter_max_)) {
        if (rv$iter >= n_iter_max_) break
        if (rv$iter > 0 && nrow(rv$current_df) < 10) break
        run_one_iter()
      }
    })

    output$status_analysis <- renderText(rv$status_analysis)
  }

  # -----------------------------------------------------------
  # 5.6. Reset analysis
  # Resets current_df to analysis_df and clears iteration state.
  # -----------------------------------------------------------
  {
    observeEvent(input$btn_reset, {
      req(rv$analysis_df)
      rv$current_df     <- rv$analysis_df
      rv$iter           <- 0
      rv$iter_plots     <- list()
      rv$status_analysis <- paste0(
        "Reset. Ready with ",
        nrow(rv$analysis_df), " configurations.")
      shinyjs::hide("div_save")
    })
  }

  # -----------------------------------------------------------
  # 5.7. Dynamic plot rendering
  # Creates one plotOutput per stored draw function and renders
  # them via renderPlot, grouped by iteration in a tabsetPanel.
  # -----------------------------------------------------------
  {
    output$ui_plots <- renderUI({

      plots <- rv$iter_plots
      if (length(plots) == 0) return(NULL)

      # Group by iteration
      iters <- sort(unique(sapply(plots, function(p) p$iter)))

      tab_panels <- lapply(iters, function(it_) {

        plots_it_ <- plots[sapply(plots,
                                   function(p) p$iter == it_)]

        plot_outs_ <- lapply(names(plots_it_), function(pid_) {
          tagList(
            h5(plots_it_[[pid_]]$title),
            plotOutput(pid_,
                       height = "400px",
                       width  = "100%")
          )
        })

        tabPanel(
          paste("Iteration", it_),
          br(),
          do.call(tagList, plot_outs_)
        )
      })

      do.call(tabsetPanel, tab_panels)
    })

    observe({
      plots <- rv$iter_plots
      for (pid_ in names(plots)) {
        local({
          pid__    <- pid_
          draw_fn_ <- plots[[pid__]]$draw_fn
          output[[pid__]] <- renderPlot({
            draw_fn_()
          })
        })
      }
    })
  }

  # -----------------------------------------------------------
  # 5.8. Save outputs
  # Saves all generated plots as JPEG files and saves the
  # current selected configurations dataframe. Also saves
  # global_df if available.
  # -----------------------------------------------------------
  {
    observeEvent(input$btn_save, {

      req(rv$global_df, rv$current_df, length(rv$iter_plots) > 0)

      result <- tryCatch({

        out_dir_ <- input$output_dir
        if (!dir.exists(out_dir_)) {
          out_dir_ <- file.path(repo_root, out_dir_)
        }
        if (!dir.exists(out_dir_)) {
          dir.create(out_dir_, recursive = TRUE)
        }

        # Save global_df
        write.csv(rv$global_df,
                  file.path(out_dir_, "global_df.csv"),
                  row.names = FALSE)
        saveRDS(rv$global_df,
                file.path(out_dir_, "global_df.rds"))

        # Save selected configurations
        write.csv(rv$current_df,
                  file.path(out_dir_,
                            "selected_configurations.csv"),
                  row.names = FALSE)
        saveRDS(rv$current_df,
                file.path(out_dir_,
                          "selected_configurations.rds"))

        # Save all plots as JPEG
        plots_   <- rv$iter_plots
        n_saved_ <- 0
        for (pid_ in names(plots_)) {
          p_      <- plots_[[pid_]]
          fpath_  <- file.path(out_dir_,
                               paste0(pid_, ".jpg"))
          w_      <- if (p_$type == "freq") 900L else 800L
          plot_and_save(p_$draw_fn, fpath_, width = w_)
          n_saved_ <- n_saved_ + 1
        }

        paste0("Saved ", n_saved_, " plots and dataframes to: ",
               out_dir_)

      }, error = function(e) {
        paste("Error saving:", conditionMessage(e))
      })

      rv$status_save <- result
    })

    output$status_save <- renderText(rv$status_save)
  }

} # end server

# -------------------------------------------------------------
# 6. Launch app
# -------------------------------------------------------------
shinyApp(ui = ui, server = server)
