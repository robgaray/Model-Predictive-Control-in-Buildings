# -------------------------------------------------------------
# Function: validate_inputs.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Checks the inputs of one call to optimize_market() and returns them
# in a normalized form. The call operates a system of assets: one or
# more of the assets of the asset registry, which share one
# connection to the grid. Every vector of the input carries one value
# per market interval, from the interval that starts at i0 to the last
# interval before i_end_horizon. This function checks that:
#   - the input has the format of the call: the blocks market,
#     context, prices, system and assets
#   - the assets of the call are in the asset registry, each of them
#     once, and there is at least one
#   - the four instants are aligned with the market resolution and
#     ordered (i0 <= i_begin_horizon < i_end_control <= i_end_horizon)
#   - every block has the time vector of that interval grid, with no
#     gap and no extra interval
#   - every value has the right type and lies in its range, with the
#     rules of 00_Validation/Parameter_catalogue.csv (the scalars of
#     the market block) and 00_Validation/Validation_Inputs.csv (the
#     vectors, which the file groups by scope and block)
#   - the block of each asset meets the checks of its type of model
#     (the operation check_input of its contract)
# Any failure stops execution with a message naming the field.
# Missing values of the energy and commitment vectors are read as 0:
# nothing was committed there. Missing setpoints are kept missing and
# are resolved later, where the process needs them.
# The three itineraries of the system and of each asset are given
# with the same format. On a first call an itinerary may be missing
# altogether (null), or carry only missing values.
# -------------------------------------------------------------
# Inputs
#   inputs     : Named list with the blocks market, context, prices,
#                system and assets, as described in the README of
#                the script.
#   parameters : Named list. Uses market$market_resolution,
#                assets (the asset registry), parameter_catalogue
#                and input_validation.
# -------------------------------------------------------------
# Outputs
#   Named list:
#     - market      : list with aim, i0, i_begin_horizon,
#                     i_end_control, i_end_horizon (POSIXct, UTC),
#                     T_ext_24h and random_seed
#     - slot_time   : POSIXct vector. Start of every market interval
#                     from i0 to the last one before i_end_horizon
#     - context     : data frame (time, Text, SolarR)
#     - prices      : data frame (time and the 15 price signals)
#     - system      : list with itineraries, a list of plan,
#                     plan_flex_down and plan_flex_up. The plan is a
#                     data frame (time, Elec_total, Elec_flex_down,
#                     Elec_flex_up) and each flexibility itinerary a
#                     data frame (time, Elec_total)
#     - assets      : list with one entry per asset of the call, in
#                     the order of the asset registry, named by its
#                     asset id. Each entry holds the scalars of its
#                     block, its context (a data frame, for the types
#                     that have one) and its itineraries (a list with
#                     plan, plan_flex_down and plan_flex_up, each a
#                     data frame), with the vectors its type declares
#                     in Validation_Inputs.csv
# -------------------------------------------------------------
# Code outline
# 1. Blocks and assets
# 2. Market block: instants and scalars
# 3. Interval grid of every block
# 4. Types and ranges of the vectors
# 5. Checks of each asset and missing values
# -------------------------------------------------------------
# Usage instructions
# checked <- validate_inputs(inputs, parameters)
# -------------------------------------------------------------

validate_inputs <- function(inputs,
                            parameters
                            ) {

  # -------------------------------------------------------------
  # 1. Blocks and assets
  # The assets of the call are those of the block assets. Each one
  # shall be in the asset registry and appear once.
  # -------------------------------------------------------------
  {
    required_blocks <- c("market", "context", "prices", "system", "assets")
    missing_blocks  <- setdiff(required_blocks, names(inputs))
    if (!is.null(inputs$itineraries) || "assets" %in% missing_blocks) {
      stop("The input is in the format of one building, which the script ",
           "does not read. The input has the blocks ",
           paste(required_blocks, collapse = ", "), ". The itineraries ",
           "of the system go in the block system, and the climate season, ",
           "the occupancy and the itineraries of each building go in its ",
           "block of assets. The README of the script describes it.")
    }
    if (length(missing_blocks) > 0) {
      stop("Input is missing the block(s): ", paste(missing_blocks, collapse = ", "))
    }

    itinerary_names <- c("plan", "plan_flex_down", "plan_flex_up")
    missing_itineraries <- setdiff(itinerary_names,
                                   names(inputs$system$itineraries))
    if (length(missing_itineraries) > 0) {
      stop("Input is missing the itinerary(ies): ",
           paste0("system$itineraries$", missing_itineraries, collapse = ", "))
    }
    rm(list = "missing_itineraries")

    call_assets <- names(inputs$assets)
    if (length(call_assets) == 0) {
      stop("The block assets of the input names no asset: the call ",
           "operates one or more assets of the asset registry")
    }
    if (anyDuplicated(call_assets) > 0) {
      stop("The block assets names an asset more than once: ",
           paste(unique(call_assets[duplicated(call_assets)]),
                 collapse = ", "))
    }
    unknown_assets <- setdiff(call_assets, names(parameters$assets))
    if (length(unknown_assets) > 0) {
      stop("The block assets names assets that are not in the asset ",
           "registry: ", paste(unknown_assets, collapse = ", "),
           ". The registry has: ",
           paste(names(parameters$assets), collapse = ", "))
    }
    # The assets of the call keep the order of the registry.
    call_assets <- intersect(names(parameters$assets), call_assets)

    price_columns <- parameters$input_validation$parameter_name[
      parameters$input_validation$scope == "system" &
        parameters$input_validation$file_name == "prices"
    ]

    rm(list = c("required_blocks", "missing_blocks", "unknown_assets"))
  }

  # -------------------------------------------------------------
  # 2. Market block: instants and scalars
  # -------------------------------------------------------------
  {
    market <- inputs$market
    instant_names <- c("i0", "i_begin_horizon", "i_end_control", "i_end_horizon")

    for (CONT_001 in instant_names) {
      if (is.null(market[[CONT_001]])) {
        stop("Input market block is missing '", CONT_001, "'")
      }
      # parse_utc_time is called to read each instant, given either as
      # ISO 8601 text or as a POSIXct value, as a UTC time.
      market[[CONT_001]] <- parse_utc_time(market[[CONT_001]], CONT_001)
    }

    resolution_sec <- parameters$market$market_resolution * 60
    for (CONT_002 in instant_names) {
      if (as.numeric(market[[CONT_002]]) %% resolution_sec != 0) {
        stop("Input '", CONT_002, "' is not aligned with the start of a ",
             parameters$market$market_resolution, "-minute market interval")
      }
    }

    if (!(market$i0 <= market$i_begin_horizon &&
          market$i_begin_horizon < market$i_end_control &&
          market$i_end_control <= market$i_end_horizon)) {
      stop("Input instants must satisfy ",
           "i0 <= i_begin_horizon < i_end_control <= i_end_horizon")
    }

    if (is.null(market$random_seed)) {
      market$random_seed <- 0
    }

    # validate_parameter_config is called to check the aim and the
    # numeric scalars against the rules of the parameter catalogue
    # for the market block.
    validate_parameter_config(
      values            = market[c("aim", "T_ext_24h", "random_seed")],
      file_name         = "market",
      validation_config = parameters$parameter_catalogue
    )

    market$aim         <- toupper(trimws(as.character(market$aim)))
    market$T_ext_24h   <- as.numeric(market$T_ext_24h)
    market$random_seed <- as.numeric(market$random_seed)

    rm(list = c("CONT_001", "CONT_002", "instant_names"))
  }

  # -------------------------------------------------------------
  # 3. Interval grid of every block
  # -------------------------------------------------------------
  # Every block is turned into a data frame whose time column must be
  # exactly the grid of intervals from i0 to i_end_horizon. The
  # vectors of a block are those that Validation_Inputs.csv declares
  # for its scope and its name. A block that is missing altogether
  # (null) is allowed where it is not required: its vectors are all
  # missing values.
  # -------------------------------------------------------------
  {
    slot_time <- seq(from = market$i0,
                     to   = market$i_end_horizon - resolution_sec,
                     by   = resolution_sec)

    block_columns <- function(scope, block_name) {
      rules <- parameters$input_validation
      return(rules$parameter_name[rules$scope == scope &
                                    rules$file_name == block_name])
    }

    as_block <- function(block, block_name, columns, required) {
      if (is.null(block) && !required) {
        block <- list(time = format(slot_time, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
      }
      if (is.null(block$time)) {
        stop("Input block '", block_name, "' is missing its time vector")
      }
      block_time <- parse_utc_time(unlist(block$time), paste0(block_name, "$time"))
      if (length(block_time) != length(slot_time) ||
          any(as.numeric(block_time) != as.numeric(slot_time))) {
        stop("Input block '", block_name, "' must have one value per market ",
             "interval, from i0 to the last interval before i_end_horizon (",
             length(slot_time), " intervals)")
      }

      block_df <- data.frame(time = slot_time)
      for (CONT_003 in columns) {
        values <- block[[CONT_003]]
        if (is.null(values)) {
          if (required) {
            stop("Input block '", block_name, "' is missing '", CONT_003, "'")
          }
          values <- rep(NA_real_, length(slot_time))
        }
        values <- unlist(lapply(values, function(x) if (is.null(x)) NA else x))
        if (length(values) != length(slot_time)) {
          stop("Input '", block_name, "$", CONT_003, "' has ", length(values),
               " values; ", length(slot_time), " expected")
        }
        block_df[[CONT_003]] <- suppressWarnings(as.numeric(values))
        if (any(is.na(block_df[[CONT_003]]) & !is.na(values))) {
          stop("Input '", block_name, "$", CONT_003, "' contains non-numeric values")
        }
      }
      return(block_df)
    }

    context <- as_block(inputs$context, "context",
                        block_columns("system", "context"), TRUE)
    prices  <- as_block(inputs$prices, "prices", price_columns, TRUE)

    system_itineraries <- list()
    for (CONT_004 in itinerary_names) {
      columns <- block_columns("system", "system_itinerary")
      if (CONT_004 == "plan") {
        columns <- c(columns, block_columns("system", "system_commitments"))
      }
      system_itineraries[[CONT_004]] <- as_block(
        inputs$system$itineraries[[CONT_004]],
        paste0("system$itineraries$", CONT_004),
        columns,
        FALSE
      )
    }

    assets <- list()
    for (CONT_005 in call_assets) {
      asset_type  <- parameters$assets[[CONT_005]]$asset_type
      asset_block <- inputs$assets[[CONT_005]]
      asset_name  <- paste0("assets$", CONT_005)

      # The scalars of the block (for a building, its climate
      # season) are kept as they come.
      asset_input <- asset_block[setdiff(names(asset_block),
                                         c("context", "itineraries"))]

      context_columns <- block_columns(asset_type, "context")
      if (length(context_columns) > 0) {
        asset_input$context <- as_block(asset_block$context,
                                        paste0(asset_name, "$context"),
                                        context_columns, TRUE)
      }

      asset_input$itineraries <- list()
      for (CONT_006 in itinerary_names) {
        asset_input$itineraries[[CONT_006]] <- as_block(
          asset_block$itineraries[[CONT_006]],
          paste0(asset_name, "$itineraries$", CONT_006),
          block_columns(asset_type, "itinerary"),
          FALSE
        )
      }
      assets[[CONT_005]] <- asset_input
      rm(list = c("asset_type", "asset_block", "asset_name", "asset_input",
                  "context_columns"))
    }

    rm(list = c("CONT_004", "CONT_005", "CONT_006", "columns"))
  }

  # -------------------------------------------------------------
  # 4. Types and ranges of the vectors
  # -------------------------------------------------------------
  {
    system_rules <- parameters$input_validation[
      parameters$input_validation$scope == "system", , drop = FALSE
    ]

    for (CONT_007 in c(names(context)[-1], price_columns)) {
      block_df <- if (CONT_007 %in% names(context)) context else prices
      if (any(is.na(block_df[[CONT_007]]))) {
        stop("Input '", CONT_007, "' contains missing values")
      }
    }

    # validate_dataframe_config is called once per block to check the
    # type and range of every vector against Validation_Inputs.csv.
    validate_dataframe_config(context, "context", system_rules)
    validate_dataframe_config(prices,  "prices",  system_rules)
    for (CONT_008 in itinerary_names) {
      validate_dataframe_config(system_itineraries[[CONT_008]],
                                "system_itinerary", system_rules)
    }
    validate_dataframe_config(system_itineraries$plan,
                              "system_commitments", system_rules)

    for (CONT_009 in names(assets)) {
      type_rules <- parameters$input_validation[
        parameters$input_validation$scope ==
          parameters$assets[[CONT_009]]$asset_type, , drop = FALSE
      ]
      if (!is.null(assets[[CONT_009]]$context)) {
        for (CONT_010 in names(assets[[CONT_009]]$context)[-1]) {
          if (any(is.na(assets[[CONT_009]]$context[[CONT_010]]))) {
            stop("Input 'assets$", CONT_009, "$context$", CONT_010,
                 "' contains missing values")
          }
        }
        validate_dataframe_config(assets[[CONT_009]]$context, "context",
                                  type_rules)
      }
      for (CONT_011 in itinerary_names) {
        validate_dataframe_config(assets[[CONT_009]]$itineraries[[CONT_011]],
                                  "itinerary", type_rules)
      }
      rm(list = "type_rules")
    }

    rm(list = c("CONT_007", "CONT_008", "CONT_009", "system_rules", "block_df"))
  }

  # -------------------------------------------------------------
  # 5. Checks of each asset and missing values
  # The "O" and "O+F" aims fly the plan as it is, so the control of
  # each asset must be known over the whole optimization horizon:
  # the columns of the plan that its operation default_control names
  # (the setpoints of a building) shall have no missing value from
  # i_begin_horizon on.
  # -------------------------------------------------------------
  {
    for (CONT_012 in names(assets)) {
      asset <- parameters$assets[[CONT_012]]

      # model_type_contract is called to take the operations of the
      # type of model of the asset.
      model <- model_type_contract(asset$asset_type)

      # The operation check_input of the model is called to make the
      # checks that belong to the type of the asset.
      assets[[CONT_012]] <- model$check_input(
        asset_input = assets[[CONT_012]],
        parameters  = parameters,
        asset       = asset
      )

      if (market$aim %in% c("O", "O+F")) {
        control_columns <- names(model$default_control(parameters, asset))
        horizon_slots   <- slot_time >= market$i_begin_horizon
        control         <- assets[[CONT_012]]$itineraries$plan[
          horizon_slots, control_columns, drop = FALSE
        ]
        if (any(is.na(control))) {
          stop("Aim '", market$aim, "' flies the plan as it is: the plan ",
               "itinerary of ", CONT_012, " must give every setpoint from ",
               "i_begin_horizon to i_end_horizon")
        }
        rm(list = c("control_columns", "horizon_slots", "control"))
      }

      # Missing energy is read as 0, in every itinerary of the asset.
      for (CONT_013 in itinerary_names) {
        energy_columns <- grep("^Elec_", names(assets[[CONT_012]]$itineraries[[CONT_013]]),
                               value = TRUE)
        for (CONT_014 in energy_columns) {
          missing_values <- is.na(assets[[CONT_012]]$itineraries[[CONT_013]][[CONT_014]])
          assets[[CONT_012]]$itineraries[[CONT_013]][[CONT_014]][missing_values] <- 0
        }
      }
      rm(list = c("asset", "model"))
    }

    # Missing energy and commitments of the system are read as 0.
    for (CONT_015 in itinerary_names) {
      energy_columns <- grep("^Elec_", names(system_itineraries[[CONT_015]]),
                             value = TRUE)
      for (CONT_016 in energy_columns) {
        missing_values <- is.na(system_itineraries[[CONT_015]][[CONT_016]])
        system_itineraries[[CONT_015]][[CONT_016]][missing_values] <- 0
      }
    }

    rm(list = intersect(c("CONT_012", "CONT_013", "CONT_014", "CONT_015",
                          "CONT_016", "energy_columns", "missing_values"),
                        ls()))
  }

  rm(list = c("as_block", "block_columns", "itinerary_names", "price_columns",
              "call_assets", "resolution_sec"))

  return(list(
    market    = market,
    slot_time = slot_time,
    context   = context,
    prices    = prices,
    system    = list(itineraries = system_itineraries),
    assets    = assets
  ))
}
