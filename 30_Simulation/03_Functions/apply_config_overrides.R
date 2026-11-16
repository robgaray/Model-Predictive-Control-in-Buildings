# -------------------------------------------------------------
# Function: apply_config_overrides.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Writes a copy of a configuration folder with some of its values
# changed. The overrides are applied to the files themselves, before
# anything is loaded, so the run that reads the copy validates every
# overridden value against the parameter catalogue, exactly as a
# value written in the original file. An invalid override is
# therefore rejected the same way as an invalid file.
# An override is either a plain parameter assignment on a
# parameter/value file, or an operation on a file.
# -------------------------------------------------------------
# The operations on a file
# A table has no parameter/value shape, so a change to a table is
# declared as an operation on the file:
#   - @keep_rows: keeps only the rows whose first field is in the
#     list given as value, separated by ";"
#   - @set_column:<column>: sets the column to the value in every row
#   - @clear: removes every row of the table
# The table of a file that holds a block of parameters above it is
# the part below the blank line that closes the block: the
# operations never touch the block. A parameter assignment finds its
# parameter in the block as in any other file.
# Two more operations write a defect into a parameter/value file, so
# that the loading of a defective file can be tried:
#   - @duplicate: the parameter given as value is written twice
#   - @rename:<new name>: the parameter given as value is written
#     with another name, as a misspelt name would be
# -------------------------------------------------------------
# The operation that adds an asset
# A new asset needs a row in the asset registry and a configuration
# folder, so it is declared as an operation on the registry:
#   - @add_asset: the file is the registry (@asset_registry_file) and
#     the value is the id of the new asset, for example Building_002.
#     The type of the asset is the id without its underscore and its
#     three digits. The row is appended to the registry, and the
#     folder of the asset is written with the default values, as for
#     any new asset. The rows that follow, written for the new asset
#     (for example @Building_002/model_file), change that folder.
# The operation needs write_asset_template() and the functions it
# calls to be loaded (see its header).
# -------------------------------------------------------------
# Inputs
#   config_path : Character. The configuration folder to copy. It is
#                 not modified.
#   overrides   : Data frame with the text columns:
#                   - file      : the configuration file, as @<key>
#                                 where <key> is a key of
#                                 00_Inner_parameters/04_File_paths.csv
#                                 (for example @reward_file), as
#                                 @<asset_id>/<key> for a file of an
#                                 asset (for example
#                                 @Building_001/model_file), or as
#                                 a file name relative to config_path
#                                 for a folder that has no such table
#                   - parameter : the parameter, or the operation,
#                                 starting with "@"
#                   - value     : the new value, or the argument of
#                                 the operation
#                 The rows are applied in their order.
#   target_path : Character. The folder the copy is written to. It
#                 must not exist yet.
# -------------------------------------------------------------
# Outputs
#   Character. target_path, which holds the whole configuration
#   folder with the overrides applied.
# -------------------------------------------------------------
# Code outline
# 0. Copy the configuration folder
# 1. Resolve the file keys
# 2. Add the assets
# 3. Separate parameter assignments from table operations
# 4. Apply the parameter assignments, one file at a time
# 5. Apply the table operations
# -------------------------------------------------------------
# Usage instructions
# overrides <- data.frame(file      = "@Building_001/comfort_file",
#                         parameter = "alpha_comfort",
#                         value     = "0.5")
# apply_config_overrides(
#   config_path = file.path("30_Simulation", "02_Config"),
#   overrides   = overrides,
#   target_path = tempfile("config_")
# )
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - The comment lines of a configuration file are preserved: the
#     file is rewritten line by line, and only the value field of the
#     overridden parameter changes.
#   - A file given as @<key> or @<asset_id>/<key> is looked up in the
#     file paths table of the configuration folder. A key the table
#     does not hold, a key given with the wrong kind of name, or a
#     folder without the table, stops execution.
#   - @add_asset stops execution if the id is not a type followed by
#     an underscore and three digits, or if the folder of the asset
#     already exists. Its rows are applied before every other
#     override, whatever their place in the table.
#   - An override on a parameter the file does not declare, or on a
#     file the folder does not hold, stops execution. The copy made
#     in target_path is then removed.
# -------------------------------------------------------------

apply_config_overrides <- function(config_path,
                                   overrides,
                                   target_path
                                   ) {

  # 0. Copy the configuration folder
  # -------------------------------------------------------------
  {
    if (dir.exists(target_path)) {
      stop("apply_config_overrides: ", target_path, " already exists")
    }
    dir.create(target_path, recursive = TRUE)

    # The copy is removed if an override stops execution, so that a
    # refused override leaves no folder behind.
    overrides_applied <- FALSE
    on.exit(
      if (!overrides_applied) unlink(target_path, recursive = TRUE),
      add = TRUE
    )
    file.copy(
      from      = list.files(config_path, full.names = TRUE, all.files = TRUE,
                             no.. = TRUE),
      to        = target_path,
      recursive = TRUE
    )
    config_path <- target_path
  }

  # 1. Resolve the file keys
  # -------------------------------------------------------------
  # A file written as @<key> or @<asset_id>/<key> is replaced by the
  # file name the key has in the file paths table of the configuration
  # folder.
  {
    if (nrow(overrides) == 0) {
      overrides_applied <- TRUE
      return(target_path)
    }

    by_key <- startsWith(overrides$file, "@")

    if (any(by_key)) {
      for (CONT_005 in which(by_key)) {
        # resolve_config_key is called to turn the key (or the asset
        # and key) written after the @ into the file name relative to
        # the configuration folder.
        overrides$file[CONT_005] <- resolve_config_key(
          key_name    = sub("^@", "", overrides$file[CONT_005]),
          config_path = config_path
        )
      }
      rm(list = "CONT_005")
    }
    rm(list = "by_key")
  }

  # 2. Add the assets
  # -------------------------------------------------------------
  # Each @add_asset row appends its asset to the registry and writes
  # its folder, before any other override, so that the overrides
  # written for the new asset find its files. The rows are then
  # taken out of the overrides.
  {
    is_add <- overrides$parameter == "@add_asset"

    for (CONT_006 in which(is_add)) {
      new_id   <- overrides$value[CONT_006]
      new_type <- sub("_[0-9]{3}$", "", new_id)
      if (!grepl("^[A-Za-z]+_[0-9]{3}$", new_id)) {
        stop("@add_asset: '", new_id, "' is not an asset id (its type ",
             "followed by an underscore and three digits)")
      }

      registry_path <- file.path(config_path, overrides$file[CONT_006])
      if (!file.exists(registry_path)) {
        stop("@add_asset targets '", overrides$file[CONT_006],
             "', which is not in the configuration folder")
      }

      # write_asset_template is called to write the configuration
      # folder of the new asset from the default values. It stops if
      # the folder already exists or the type has no files.
      write_asset_template(
        config_path = config_path,
        asset_id    = new_id,
        asset_type  = new_type
      )

      # The row is appended once the folder is written, so that a
      # refused asset leaves the registry as it was.
      registry_lines <- readLines(registry_path)
      writeLines(c(registry_lines, paste(new_id, new_type, sep = ",")),
                 registry_path)
      rm(list = c("new_id", "new_type", "registry_path", "registry_lines"))
    }

    overrides <- overrides[!is_add, , drop = FALSE]
    rm(list = c("CONT_006", "is_add"))
  }

  # 3. Separate parameter assignments from table operations
  # -------------------------------------------------------------
  {

    is_operation <- startsWith(overrides$parameter, "@")
    assignments  <- overrides[!is_operation, , drop = FALSE]
    operations   <- overrides[is_operation, , drop = FALSE]
  }

  # 4. Apply the parameter assignments, one file at a time
  # -------------------------------------------------------------
  {
    for (CONT_001 in unique(assignments$file)) {

      file_path <- file.path(config_path, CONT_001)
      if (!file.exists(file_path)) {
        stop("Override targets '", CONT_001, "', which is not in the configuration folder")
      }

      lines     <- readLines(file_path)
      file_rows <- assignments[assignments$file == CONT_001, , drop = FALSE]

      for (CONT_002 in seq_len(nrow(file_rows))) {

        pattern <- paste0("^\\s*", file_rows$parameter[CONT_002], "\\s*,")
        target  <- grep(pattern, lines)

        if (length(target) != 1) {
          stop("Parameter '", file_rows$parameter[CONT_002], "' appears ",
               length(target), " times in ", CONT_001)
        }

        fields    <- strsplit(lines[target], ",", fixed = TRUE)[[1]]
        fields[2] <- file_rows$value[CONT_002]
        lines[target] <- paste(fields, collapse = ",")
      }

      writeLines(lines, file_path)
      rm(list = c("CONT_002", "file_path", "lines", "file_rows", "pattern",
                  "target", "fields"))
    }
    rm(list = "CONT_001")
  }

  # 5. Apply the table operations
  # -------------------------------------------------------------
  {
    for (CONT_003 in seq_len(nrow(operations))) {

      file_path <- file.path(config_path, operations$file[CONT_003])
      if (!file.exists(file_path)) {
        stop("Table operation targets '", operations$file[CONT_003],
             "', which is not in the configuration folder")
      }

      lines <- readLines(file_path)

      # split_config_sections is called to find the lines of the
      # table: the whole file when it holds no block of parameters,
      # and the part below the blank line that closes the block when
      # it does. A flat file of parameters has no table, and its
      # lines that are neither a comment nor blank are taken as one.
      sections   <- split_config_sections(lines)
      table_rows <- if (length(sections$table) > 0) sections$table else
        which(!grepl("^\\s*#", lines) & nzchar(trimws(lines)))
      header_row <- table_rows[1:2]
      body_rows  <- setdiff(table_rows, header_row)

      operation <- operations$parameter[CONT_003]
      value     <- operations$value[CONT_003]

      if (operation == "@duplicate") {
        pattern <- paste0("^\\s*", value, "\\s*,")
        target  <- grep(pattern, lines)

        if (length(target) != 1) {
          stop("Parameter '", value, "' appears ", length(target), " times in ",
               operations$file[CONT_003], "; it cannot be duplicated")
        }

        lines <- append(lines, lines[target], after = target)
        rm(list = c("pattern", "target"))

      } else if (startsWith(operation, "@rename:")) {
        pattern <- paste0("^(\\s*)", value, "(\\s*,)")
        target  <- grep(pattern, lines)

        if (length(target) != 1) {
          stop("Parameter '", value, "' appears ", length(target), " times in ",
               operations$file[CONT_003], "; it cannot be renamed")
        }

        lines[target] <- sub(pattern,
                             paste0("\\1", sub("^@rename:", "", operation), "\\2"),
                             lines[target])
        rm(list = c("pattern", "target"))

      } else if (operation == "@clear") {
        lines <- lines[-body_rows]

      } else if (operation == "@keep_rows") {
        keep      <- trimws(unlist(lapply(strsplit(lines[body_rows], ","), function(x) x[1])))
        wanted    <- trimws(strsplit(value, ";", fixed = TRUE)[[1]])
        lines     <- lines[-body_rows[!keep %in% wanted]]

      } else if (startsWith(operation, "@set_column:")) {
        column_name <- sub("^@set_column:", "", operation)
        header      <- trimws(strsplit(lines[header_row[1]], ",")[[1]])
        column_idx  <- match(column_name, header)

        if (is.na(column_idx)) {
          stop("Column '", column_name, "' is not in ", operations$file[CONT_003])
        }

        for (CONT_004 in body_rows) {
          fields             <- strsplit(lines[CONT_004], ",", fixed = TRUE)[[1]]
          fields[column_idx] <- value
          lines[CONT_004]    <- paste(fields, collapse = ",")
        }
        rm(list = c("CONT_004", "column_name", "header", "column_idx"))

      } else {
        stop("Unknown table operation '", operation, "'")
      }

      writeLines(lines, file_path)
      rm(list = c("file_path", "lines", "sections", "table_rows", "header_row",
                  "body_rows", "operation", "value"))
    }
    rm(list = "CONT_003")
  }

  rm(list = c("is_operation", "assignments", "operations"))

  overrides_applied <- TRUE
  return(target_path)
}
