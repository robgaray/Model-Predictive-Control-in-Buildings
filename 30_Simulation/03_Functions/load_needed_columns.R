# -------------------------------------------------------------
# Function: load_needed_columns.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads the list of the columns of the simulation data,
# 02_Needed_cols.csv, and validates it against the parameter
# catalogue. It is the one list of those columns:
#   - the row @System_variables_df stands for every column of
#     System_variables_df, and the row @<type>_variables_df (for
#     example @Building_variables_df) for every column of the
#     variable registry of that type of model. Each registry is read
#     from where its type says (the operation variable_registry of
#     model_type_contract()), so the columns are declared there only;
#   - the stage of each column says whether the assembled table must
#     hold it (assembly), which validate_Main_df() and
#     validate_asset_df() check, whether the preparation of the
#     run adds it (preparation), or whether it is an input of the
#     assets of a type (input): a column of Main_df that the table
#     of every asset of the type holds a copy of during the whole
#     run;
#   - the table of each column says whether it is a column of
#     Main_df (system) or of the table of the assets of a type of
#     model (the name of the type, for example Building). Each type
#     has its own list of columns.
# The table of an asset holds time too, the key of its rows, which
# is a column of Main_df in the file.
# A column may be in both Main_df and the table of a type only when
# it is the net electricity of the system in an itinerary
# (system_net_energy_columns()), or an input of the type. Main_df
# holds the sum over the assets of the net electricity the table of
# each asset holds, and an input is the same column in both tables.
# The order of the file is the order of the output tables:
# Main_df_computed takes the columns of Main_df in it, and the table
# of each asset takes time and then the columns of its type. The
# pieces the markets work on join them in that order, with a column
# that several tables hold once.
# -------------------------------------------------------------
# Inputs
#   needed_cols_path  : Character. Path to 02_Needed_cols.csv, a
#                       table with the columns column, stage and
#                       table, and a units row.
#   paths             : List. The paths of the simulator. It holds
#                       the variable registry of the system,
#                       paths$system_variables_file, and the
#                       registries of the types of model, which the
#                       contract of each type names.
#   validation_config : Named list. The parameter catalogue, as
#                       load_parameter_catalogue() returns it. Its
#                       options for the table column are system and
#                       the types of model.
# -------------------------------------------------------------
# Outputs
#   Named list:
#     - all            : Character vector. Every column of Main_df, in
#                        the order of the file.
#     - assembly       : Character vector. The columns of Main_df of
#                        stage assembly, in the same order.
#     - asset          : Named list, one element per type of model.
#                        Each one is a character vector: every column
#                        of the table of an asset of the type, time
#                        first, then in the order of the file.
#     - asset_assembly : Named list, one element per type of model.
#                        Each one is a character vector: the columns
#                        of that table of stage assembly, time
#                        included.
#     - joined         : Character vector. Every column of Main_df
#                        and of the tables of every type, once, in
#                        the order of the file, the order of the
#                        pieces the markets work on.
#     - asset_input    : Named list, one element per type of model.
#                        Each one is a character vector: the inputs
#                        of the type (stage input), in the order of
#                        the file. They are in asset too, and not in
#                        asset_assembly.
#     - itinerary_variables : Named list, one element per type of
#                        model. Each one is a character vector: the
#                        variables of the registry of the type
#                        expanded into the four itineraries
#                        (scenario == "yes"), in registry order.
# -------------------------------------------------------------
# Code outline
# 1. Read the table and check its columns, its stages and its tables
# 2. Expand the columns of the registries
# 3. The columns of each table, and the columns of all
# -------------------------------------------------------------
# Usage instructions
# needed <- load_needed_columns(
#   needed_cols_path  = paths$needed_cols_file,
#   paths             = paths,
#   validation_config = validation_config
# )
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - A column named twice in the same table, an empty name, a stage
#     or a table outside the options of the catalogue, or a column in
#     both Main_df and the table of a type that is neither the net
#     electricity of the system nor an input of that type stops the
#     run.
#   - A row of stage input whose table is system, whose column is
#     not a column of Main_df, or whose column is the net
#     electricity of the system stops the run.
# -------------------------------------------------------------

load_needed_columns <- function(needed_cols_path,
                                paths,
                                validation_config
                                ) {

  # -------------------------------------------------------------
  # 1. Read the table and check its columns, its stages and its
  #    tables
  # -------------------------------------------------------------
  {
    file_name <- basename(needed_cols_path)
    table     <- read.csv(needed_cols_path, comment.char = "#",
                          colClasses = "character",
                          stringsAsFactors = FALSE)

    required_cols <- c("column", "stage", "table")
    missing_cols  <- setdiff(required_cols, names(table))
    if (length(missing_cols) > 0) {
      stop(file_name, " is missing required columns: ",
           paste(missing_cols, collapse = ", "))
    }

    # The allowed stages and tables are the options of the stage and
    # table columns in the parameter catalogue.
    rules   <- validation_config$rules
    options_of <- function(parameter) {
      options <- rules$options[rules$file == file_name &
                               rules$parameter == parameter]
      if (length(options) != 1) {
        stop("The parameter catalogue has no rule for the column ",
             parameter, " of ", file_name)
      }
      return(trimws(strsplit(options, ",")[[1]]))
    }
    stages <- options_of("stage")
    tables <- options_of("table")

    # The tables other than the system are those of the types of
    # model.
    types <- setdiff(tables, "system")

    # drop_unit_row is called to remove the units row, the first row
    # under the header, after checking it is not a column.
    table <- drop_unit_row(
      table             = table,
      file_name         = file_name,
      number_columns    = character(0),
      reference_columns = "stage",
      reference_values  = stages
    )

    table$column <- trimws(table$column)
    table$stage  <- trimws(table$stage)
    table$table  <- trimws(table$table)

    bad_stage <- setdiff(unique(table$stage), stages)
    if (length(bad_stage) > 0) {
      stop(file_name, " has invalid stage value(s): ",
           paste(bad_stage, collapse = ", "), ". Allowed: ",
           paste(stages, collapse = ", "))
    }
    bad_table <- setdiff(unique(table$table), tables)
    if (length(bad_table) > 0) {
      stop(file_name, " has invalid table value(s): ",
           paste(bad_table, collapse = ", "), ". Allowed: ",
           paste(tables, collapse = ", "))
    }
    if (any(!nzchar(table$column))) {
      stop(file_name, " has a row with no column name")
    }

    rm(list = c("required_cols", "missing_cols", "rules", "options_of",
                "stages", "tables", "bad_stage", "bad_table"))
  }

  # -------------------------------------------------------------
  # 2. Expand the columns of the registries
  # The registry of the system is named in the paths, and that of
  # each type by the contract of the type.
  # -------------------------------------------------------------
  {
    # variable_registry_columns is called to read the columns of
    # System_variables_df from the variable registry of the system,
    # the one place they are declared.
    registry_columns <- list(
      "@System_variables_df" =
        variable_registry_columns(paths$system_variables_file)$column
    )

    type_tables <- list()
    for (CONT_001 in types) {
      # model_type_contract is called to get the operations of the
      # type of model, one of which names its variable registry.
      model <- model_type_contract(CONT_001)

      # variable_registry_columns is called to read the columns of the
      # registry of the type, the one place they are declared.
      type_tables[[CONT_001]] <- variable_registry_columns(
        model$variable_registry(paths)
      )
      registry_columns[[paste0("@", CONT_001, "_variables_df")]] <-
        type_tables[[CONT_001]]$column
      rm(list = "model")
    }

    expanded <- lapply(seq_len(nrow(table)), function(CONT_002) {
      one_column <- table$column[CONT_002]
      columns    <- if (one_column %in% names(registry_columns)) {
        registry_columns[[one_column]]
      } else {
        one_column
      }
      data.frame(column = columns, stage = table$stage[CONT_002],
                 table = table$table[CONT_002],
                 stringsAsFactors = FALSE)
    })
    expanded <- do.call(rbind, expanded)

    rm(list = c("registry_columns", "CONT_001"))
  }

  # -------------------------------------------------------------
  # 3. The columns of each table, and the columns of all
  # A column named twice in the same table stops the run. A column of
  # Main_df and of the table of a type has to be the net electricity
  # of the system, which Main_df holds as the sum over the assets, or
  # an input of that type, a copy of the column of Main_df. A column
  # may be in the tables of two types: each asset holds its own.
  # -------------------------------------------------------------
  {
    for (CONT_003 in unique(expanded$table)) {
      in_table   <- expanded$column[expanded$table == CONT_003]
      duplicated_columns <- unique(in_table[duplicated(in_table)])
      if (length(duplicated_columns) > 0) {
        stop(file_name, " names these columns more than once: ",
             paste(duplicated_columns, collapse = ", "))
      }
    }

    # system_net_energy_columns is called to name the columns of the
    # net electricity of the system.
    net_energy_columns <- system_net_energy_columns()
    system_columns <- expanded$column[expanded$table == "system"]

    # An input is a copy of a column of Main_df, held by the table of
    # the assets of a type. It cannot be a column of the system, and
    # it cannot be the net electricity, which is a sum.
    input_rows <- expanded$stage == "input"
    if (any(input_rows & expanded$table == "system")) {
      stop(file_name, ": a row of stage input must name the table of ",
           "a type of model, not system")
    }
    not_system <- setdiff(expanded$column[input_rows], system_columns)
    if (length(not_system) > 0) {
      stop(file_name, ": an input must be a column of Main_df. ",
           "Found: ", paste(not_system, collapse = ", "))
    }
    input_net <- intersect(expanded$column[input_rows],
                           net_energy_columns)
    if (length(input_net) > 0) {
      stop(file_name, ": an input cannot be the net electricity of ",
           "the system. Found: ", paste(input_net, collapse = ", "))
    }
    rm(list = c("input_net", "not_system"))

    not_allowed <- character(0)
    for (CONT_004 in types) {
      in_both     <- intersect(system_columns,
                               expanded$column[expanded$table == CONT_004])
      type_inputs <- expanded$column[input_rows &
                                       expanded$table == CONT_004]
      not_allowed <- c(not_allowed,
                       setdiff(in_both, c(net_energy_columns,
                                          type_inputs)))
      rm(list = c("in_both", "type_inputs"))
    }
    if (length(not_allowed) > 0) {
      stop(file_name, ": a column of both Main_df and the table of an ",
           "asset must be the net electricity of the system or an ",
           "input of the type. Found: ",
           paste(unique(not_allowed), collapse = ", "))
    }
    rm(list = c("not_allowed", "CONT_004", "system_columns"))

    system_rows <- expanded$table == "system"

    needed <- list(
      all            = expanded$column[system_rows],
      assembly       = expanded$column[system_rows &
                                         expanded$stage == "assembly"],
      asset          = list(),
      asset_assembly = list(),
      asset_input    = list(),
      joined         = unique(expanded$column),
      itinerary_variables = list()
    )
    for (CONT_005 in types) {
      type_rows <- expanded$table == CONT_005
      needed$asset[[CONT_005]]          <- c("time",
                                             expanded$column[type_rows])
      needed$asset_assembly[[CONT_005]] <- c(
        "time",
        expanded$column[type_rows & expanded$stage == "assembly"]
      )
      needed$asset_input[[CONT_005]]    <- expanded$column[
        type_rows & expanded$stage == "input"
      ]
      needed$itinerary_variables[[CONT_005]] <- unique(
        type_tables[[CONT_005]]$variable[
          type_tables[[CONT_005]]$scenario == "yes"
        ]
      )
      rm(list = "type_rows")
    }

    rm(list = c("file_name", "table", "types", "type_tables", "expanded",
                "CONT_003", "in_table", "duplicated_columns",
                "net_energy_columns", "input_rows", "system_rows", "CONT_005"))
  }

  return(needed)
}
