# -------------------------------------------------------------
# Function: validate_inputs.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Checks the inputs of one call to optimize_market() and returns them
# in a normalized form. Every vector of the input carries one value
# per market interval, from the interval that starts at i0 to the last
# interval before i_end_horizon. This function checks that:
#   - the four instants are aligned with the market resolution and
#     ordered (i0 <= i_begin_horizon < i_end_control <= i_end_horizon)
#   - every block has the time vector of that interval grid, with no
#     gap and no extra interval
#   - every value has the right type and lies in its range, with the
#     rules of 00_Validation/Validation_Inputs.csv
#   - the plan itinerary gives the state of the building (Ti, Te) at i0
# Any failure stops execution with a message naming the field.
# Missing values of the energy and commitment vectors are read as 0:
# nothing was committed there. Missing setpoints are kept missing and
# are resolved later, where the process needs them.
# The three itineraries are required, with the same format. On a first
# call the two flexibility itineraries carry only missing values.
# -------------------------------------------------------------
# Inputs
#   inputs     : Named list with the blocks market, context, prices
#                and itineraries, as described in the README of the
#                script.
#   parameters : Named list. Uses market$market_resolution and
#                input_validation.
# -------------------------------------------------------------
# Outputs
#   Named list:
#     - market      : list with aim, i0, i_begin_horizon,
#                     i_end_control, i_end_horizon (POSIXct, UTC),
#                     T_ext_24h, Overall_Climate and random_seed
#     - slot_time   : POSIXct vector. Start of every market interval
#                     from i0 to the last one before i_end_horizon
#     - context     : data frame (time, Text, SolarR, Occupancy)
#     - prices      : data frame (time and the 15 price signals)
#     - itineraries : list with plan, plan_flex_down, plan_flex_up,
#                     each a data frame or NULL
# -------------------------------------------------------------
# Code outline
# 1. Blocks and names
# 2. Market block: instants and scalars
# 3. Interval grid of every block
# 4. Types and ranges of the vectors
# 5. State at i0 and missing values
# -------------------------------------------------------------
# Usage instructions
# checked <- validate_inputs(inputs, parameters)
# -------------------------------------------------------------
# Where this function/script is used
#   - optimize_market(): first step of every call.
# -------------------------------------------------------------
# functions/scripts called
#   - parse_utc_time(): reads an instant given as text or POSIXct
#   - validate_parameter_config(): checks the scalars of the market
#     block
#   - validate_dataframe_config(): checks the vectors of the other
#     blocks
# -------------------------------------------------------------

validate_inputs <- function(inputs,
                            parameters
                            ) {

  # -------------------------------------------------------------
  # 1. Blocks and names
  # -------------------------------------------------------------
  {
    required_blocks <- c("market", "context", "prices", "itineraries")
    missing_blocks  <- setdiff(required_blocks, names(inputs))
    if (length(missing_blocks) > 0) {
      stop("Input is missing the block(s): ", paste(missing_blocks, collapse = ", "))
    }
    missing_itineraries <- setdiff(c("plan", "plan_flex_down", "plan_flex_up"),
                                   names(inputs$itineraries))
    if (length(missing_itineraries) > 0) {
      stop("Input is missing the itinerary(ies): ",
           paste0("itineraries$", missing_itineraries, collapse = ", "))
    }
    rm(missing_itineraries)

    itinerary_names   <- c("plan", "plan_flex_down", "plan_flex_up")
    itinerary_columns <- c("Ti", "Te",
                           "STP_heat", "STP_heat_low", "STP_heat_high",
                           "STP_cool", "STP_cool_low", "STP_cool_high",
                           "Elec_total")
    commitment_columns <- c("Elec_flex_down", "Elec_flex_up")
    price_columns <- c("Elec_unit_cost_import_buy", "Elec_unit_cost_import_sell",
                       "Elec_unit_cost_export_buy", "Elec_unit_cost_export_sell",
                       "Elec_unit_cost_distribution",
                       "Flex_unit_cost_down_com_buy", "Flex_unit_cost_down_com_sell",
                       "Flex_unit_cost_down_exec_buy", "Flex_unit_cost_down_exec_sell",
                       "Flex_unit_cost_up_com_buy", "Flex_unit_cost_up_com_sell",
                       "Flex_unit_cost_up_exec_buy", "Flex_unit_cost_up_exec_sell",
                       "Flex_Probab_down", "Flex_Probab_up")
    context_columns <- c("Text", "SolarR", "Occupancy")

    rm(required_blocks, missing_blocks)
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

    # validate_parameter_config is called to check the aim, the climate
    # season and the numeric scalars against Validation_Inputs.csv.
    validate_parameter_config(
      values            = market[c("aim", "T_ext_24h", "Overall_Climate", "random_seed")],
      file_name         = "market",
      validation_config = parameters$input_validation
    )

    market$aim             <- toupper(trimws(as.character(market$aim)))
    market$T_ext_24h       <- as.numeric(market$T_ext_24h)
    market$Overall_Climate <- trimws(as.character(market$Overall_Climate))
    market$random_seed     <- as.numeric(market$random_seed)

    rm(CONT_001, CONT_002, instant_names)
  }

  # -------------------------------------------------------------
  # 3. Interval grid of every block
  # -------------------------------------------------------------
  # Every block is turned into a data frame whose time column must be
  # exactly the grid of intervals from i0 to i_end_horizon.
  # -------------------------------------------------------------
  {
    slot_time <- seq(from = market$i0,
                     to   = market$i_end_horizon - resolution_sec,
                     by   = resolution_sec)

    as_block <- function(block, block_name, columns, required) {
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

    context <- as_block(inputs$context, "context", context_columns, TRUE)
    prices  <- as_block(inputs$prices,  "prices",  price_columns,   TRUE)

    itineraries <- list()
    for (CONT_004 in itinerary_names) {
      block <- inputs$itineraries[[CONT_004]]
      columns <- if (CONT_004 == "plan") c(itinerary_columns, commitment_columns) else itinerary_columns
      itineraries[[CONT_004]] <- as_block(block, CONT_004, columns, FALSE)
    }

    rm(CONT_004, block, columns)
  }

  # -------------------------------------------------------------
  # 4. Types and ranges of the vectors
  # -------------------------------------------------------------
  {
    for (CONT_005 in c(context_columns, price_columns)) {
      block_df <- if (CONT_005 %in% context_columns) context else prices
      if (any(is.na(block_df[[CONT_005]]))) {
        stop("Input '", CONT_005, "' contains missing values")
      }
    }

    # validate_dataframe_config is called once per block to check the
    # type and range of every vector against Validation_Inputs.csv.
    validate_dataframe_config(context, "context", parameters$input_validation)
    validate_dataframe_config(prices,  "prices",  parameters$input_validation)

    for (CONT_006 in names(itineraries)) {
      validate_dataframe_config(itineraries[[CONT_006]], "itinerary",
                                parameters$input_validation)
    }
    validate_dataframe_config(itineraries$plan, "plan_commitments",
                              parameters$input_validation)

    rm(CONT_005, CONT_006, block_df)
  }

  # -------------------------------------------------------------
  # 5. State at i0 and missing values
  # -------------------------------------------------------------
  {
    if (is.na(itineraries$plan$Ti[1]) || is.na(itineraries$plan$Te[1])) {
      stop("The plan itinerary must give Ti and Te at i0 (its first interval)")
    }

    # The "O" and "O+F" aims fly the plan as it is, so its setpoints
    # must be known over the whole optimization horizon.
    if (market$aim %in% c("O", "O+F")) {
      horizon_slots <- slot_time >= market$i_begin_horizon
      setpoints     <- itineraries$plan[horizon_slots,
                                        grep("^STP_", names(itineraries$plan))]
      if (any(is.na(setpoints))) {
        stop("Aim '", market$aim, "' flies the plan as it is: the plan ",
             "itinerary must give every setpoint from i_begin_horizon ",
             "to i_end_horizon")
      }
      rm(horizon_slots, setpoints)
    }

    for (CONT_007 in names(itineraries)) {
      energy_columns <- intersect(c("Elec_total", commitment_columns),
                                  names(itineraries[[CONT_007]]))
      for (CONT_008 in energy_columns) {
        missing_values <- is.na(itineraries[[CONT_007]][[CONT_008]])
        itineraries[[CONT_007]][[CONT_008]][missing_values] <- 0
      }
    }

    rm(CONT_007, CONT_008, energy_columns, missing_values)
  }

  rm(as_block, itinerary_names, itinerary_columns, commitment_columns,
     price_columns, context_columns, resolution_sec)

  return(list(
    market      = market,
    slot_time   = slot_time,
    context     = context,
    prices      = prices,
    itineraries = itineraries
  ))
}
