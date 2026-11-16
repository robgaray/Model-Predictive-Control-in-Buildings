# -------------------------------------------------------------
# Function: write_asset_template.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Writes the configuration folder of an asset, with the files of its
# type of model, from the default values. The folder is named by the
# asset id inside the folder of the assets (the file of the key
# asset_config_folder in 00_Inner_parameters/04_File_paths.csv), and
# the files are the rows of the file paths table whose scope is the
# type of the asset.
# There is no template folder: a file that has a default version in
# 00_Validation/ (Default_<file>) is copied from it, and any other
# file is written as a flat parameter,value,unit file from the
# default column of the parameter catalogue, in the order of the
# catalogue, with the blocks of the catalogue as comment lines.
# A file that has a default version and also parameters with a
# default value in the catalogue holds a block of parameters above
# its table: it is written as the block of those parameters, one
# blank line, and the default version, which is its table.
# -------------------------------------------------------------
# Inputs
#   config_path : Character. Path of the configuration folder, the
#                 one that holds 00_Inner_parameters/.
#   asset_id    : Character. The id of the asset, for example
#                 "Building_001".
#   asset_type  : Character. The type of model of the asset, for
#                 example "Building".
# -------------------------------------------------------------
# Outputs
#   Character. The path of the folder written. The run stops, naming
#   the asset, if the folder already exists, if the type has no file
#   in the table, or if a file has neither a default version nor a
#   default value for each of its parameters in the catalogue.
# -------------------------------------------------------------
# Code outline
# 1. Read the table of file names and select the files of the type
# 2. Prepare the content of each file
# 3. Write the folder
# -------------------------------------------------------------
# Usage instructions
# write_asset_template(
#   config_path = file.path("30_Simulation", "02_Config"),
#   asset_id    = "Building_002",
#   asset_type  = "Building"
# )
# -------------------------------------------------------------

write_asset_template <- function(config_path,
                                 asset_id,
                                 asset_type) {

  # -------------------------------------------------------------
  # 1. Read the table of file names and select the files of the type
  # -------------------------------------------------------------
  {
    # read_file_paths_table is called to read the file names of the
    # configuration and the scope of each of them.
    file_paths_table <- read_file_paths_table(config_path = config_path)

    folder_row <- which(file_paths_table$key == "asset_config_folder")
    if (length(folder_row) != 1) {
      stop("04_File_paths.csv must hold the key asset_config_folder ",
           "once, to name the folder of each asset")
    }

    type_files <- file_paths_table[file_paths_table$scope == asset_type, ]
    if (nrow(type_files) == 0) {
      stop("04_File_paths.csv holds no file for the type of model '",
           asset_type, "' of the asset ", asset_id)
    }

    asset_folder <- file.path(config_path,
                              file_paths_table$filename[folder_row],
                              asset_id)
    if (dir.exists(asset_folder)) {
      stop("The configuration folder of the asset ", asset_id,
           " already exists: ", asset_folder)
    }

    # load_parameter_catalogue is called to read the default value,
    # unit and block of every parameter of the files that have no
    # default version.
    rules <- load_parameter_catalogue(
      catalogue_path  = file.path(
        config_path,
        file_paths_table$filename[file_paths_table$key ==
                                    "parameter_catalogue_file"]
      ),
      tolerances_path = file.path(
        config_path,
        file_paths_table$filename[file_paths_table$key ==
                                    "tolerances_validation_file"]
      )
    )$rules

    rm(list = c("file_paths_table", "folder_row"))
  }

  # -------------------------------------------------------------
  # 2. Prepare the content of each file
  # A file with a default version is copied. Any other file is a
  # list of lines written from the catalogue.
  # -------------------------------------------------------------
  {
    file_names    <- basename(type_files$filename)
    default_files <- file.path(config_path, "00_Validation",
                               paste0("Default_", file_names))
    file_lines    <- vector("list", length(file_names))

    # block_lines writes the lines of a block of parameters from the
    # catalogue rows of a file: a header, the header parameter,value,
    # unit, and one line per parameter, with the blocks of the
    # catalogue as comment lines.
    block_lines <- function(file_name, file_rows) {
      if (any(grepl("[,\"]", c(file_rows$parameter, file_rows$unit,
                               file_rows$default)))) {
        stop("The file ", file_name,
             " has a default that cannot be written to a parameter file")
      }

      lines          <- c(
        paste0("# ", file_name),
        paste0("# Configuration file: default values from the ",
               "parameter catalogue"),
        paste0("# ", strrep("-", 61)),
        "parameter,value,unit"
      )
      previous_block <- ""
      for (CONT_002 in seq_len(nrow(file_rows))) {
        if (nzchar(file_rows$block[CONT_002]) &&
            file_rows$block[CONT_002] != previous_block) {
          lines          <- c(lines, "#",
                              paste0("# ", file_rows$block[CONT_002]))
          previous_block <- file_rows$block[CONT_002]
        }
        lines <- c(lines, paste(file_rows$parameter[CONT_002],
                                file_rows$default[CONT_002],
                                file_rows$unit[CONT_002], sep = ","))
      }
      lines
    }

    for (CONT_001 in seq_along(file_names)) {
      file_rows   <- rules[rules$file == file_names[CONT_001], , drop = FALSE]
      block_rows  <- file_rows[!file_rows$default %in% c("", "-"), ,
                               drop = FALSE]
      has_default <- file.exists(default_files[CONT_001])

      if (has_default && nrow(block_rows) == 0) {
        next
      }

      if (has_default) {
        # A file with a default version and parameters with a default
        # in the catalogue holds a block of parameters above its table:
        # the block from the catalogue, one blank line that closes it,
        # and the default version, which is the table.
        file_lines[[CONT_001]] <- c(
          block_lines(file_names[CONT_001], block_rows),
          "",
          readLines(default_files[CONT_001])
        )
        next
      }

      if (nrow(file_rows) == 0 || nrow(block_rows) < nrow(file_rows)) {
        stop("The file ", file_names[CONT_001], " of the type '", asset_type,
             "' has no default version and no default value for each of ",
             "its parameters in the catalogue")
      }
      file_lines[[CONT_001]] <- block_lines(file_names[CONT_001], file_rows)
    }

    rm(list = c("rules", "file_rows", "block_rows", "has_default",
                "block_lines", "CONT_001"))
  }

  # -------------------------------------------------------------
  # 3. Write the folder
  # -------------------------------------------------------------
  {
    dir.create(asset_folder, recursive = TRUE)

    for (CONT_003 in seq_along(file_names)) {
      target <- file.path(asset_folder, type_files$filename[CONT_003])
      if (is.null(file_lines[[CONT_003]])) {
        file.copy(default_files[CONT_003], target)
      } else {
        writeLines(file_lines[[CONT_003]], target)
      }
    }

    rm(list = c("type_files", "file_names", "default_files", "file_lines",
                "target", "CONT_003"))
  }

  return(asset_folder)
}
