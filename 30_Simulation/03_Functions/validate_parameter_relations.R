# -------------------------------------------------------------
# Function: validate_parameter_relations.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Checks the relations two parameters have to keep with each other,
# which the range of each one cannot express: a low end below its
# high end, two operating points in order, a horizon that fits in
# another. The relations are the rows of
# Validation_parameter_relations.csv, each one read as
#   left (+ gap) relation right
# A parameter is found in parameters by its name, which is unique
# across the sub-lists; a column of a table (such as the heating
# setpoint of the modes) is checked on every row of the table.
# The parameters of an asset are held by its entry of
# parameters$assets, so the relations are checked once per asset:
# a name is looked for first in the groups of the asset, and then in
# the other sub-lists of parameters. A relation between a parameter
# of the asset and one of the system is so checked for every asset.
# The setpoints of the modes and the Deadband are both parameters of
# the building, found in its groups.
# A relation applies to an asset when its asset_type is "-" or the
# type of the asset. A relation is also checked against
# 04_File_paths.csv: every file it names must be listed there, as a
# file of the system or of the type of the relation, and its
# asset_type must be "-" or a type of that table. A relation that does
# not apply to an asset is not checked for it. Within a relation that
# applies, a parameter that is not found stops the run.
# Every relation is checked, and the run stops listing all of those
# that fail, so that a configuration is corrected in one pass. With
# more than one asset, each failure names its asset.
# -------------------------------------------------------------
# Inputs
#   parameters : Named list. Every parameter, already loaded, with the
#                parameters of each asset in parameters$assets.
#   relations  : Data frame. Content of
#                Validation_parameter_relations.csv, without its
#                comment rows and its units row, with the columns:
#                  - left_file, left_parameter
#                  - relation
#                  - right_file, right_parameter
#                  - gap_file, gap_parameter
#                  - asset_type
#   file_paths_table : Data frame. Content of 04_File_paths.csv, with
#                the columns key, scope and filename, as given by
#                read_file_paths_table().
# -------------------------------------------------------------
# Outputs
#   TRUE, invisibly, when every relation holds. Otherwise it stops,
#   naming each relation that fails and the values it found.
# -------------------------------------------------------------
# Code outline
# 1. Find a parameter, or a column of a table, by its name
# 2. Check each relation, for each asset
# 3. Stop when any fails
# -------------------------------------------------------------
# Usage instructions
# validate_parameter_relations(
#   parameters       = parameters,
#   relations        = relations,
#   file_paths_table = file_paths_table
# )
# -------------------------------------------------------------

validate_parameter_relations <- function(parameters,
                                         relations,
                                         file_paths_table) {

  # 1. Find a parameter, or a column of a table, by its name
  # The groups searched are those of one asset, then the other
  # sub-lists of parameters.
  # -------------------------------------------------------------
  {
    # The groups are walked by position: a group of an asset and a
    # group of the system may share a name (control), and both are
    # searched, the one of the asset first.
    value_of <- function(name, groups) {
      for (CONT_001 in seq_along(groups)) {
        group <- groups[[CONT_001]]
        if (is.data.frame(group)) {
          if (name %in% names(group)) return(as.numeric(group[[name]]))
        } else if (is.list(group) && !is.null(group[[name]])) {
          return(as.numeric(group[[name]]))
        }
      }
      stop("validate_parameter_relations: parameter '", name,
           "' of Validation_parameter_relations.csv was not found")
    }

    # check_files stops when a relation names a file that
    # 04_File_paths.csv does not list, or a file of a type other than
    # the one of the relation, or a type of asset that table does not
    # hold.
    check_files <- function(files, relation_type) {
      if (relation_type != "-" && !(relation_type %in% file_paths_table$scope)) {
        stop("validate_parameter_relations: asset_type '", relation_type,
             "' of Validation_parameter_relations.csv is not a type of ",
             "04_File_paths.csv")
      }
      for (CONT_004 in files) {
        if (CONT_004 == "-") next
        scope <- file_paths_table$scope[basename(file_paths_table$filename) ==
                                          CONT_004]
        if (length(scope) == 0) {
          stop("validate_parameter_relations: file '", CONT_004,
               "' of Validation_parameter_relations.csv is not listed in ",
               "04_File_paths.csv")
        }
        if (!any(scope %in% c("system", relation_type))) {
          stop("validate_parameter_relations: file '", CONT_004,
               "' of Validation_parameter_relations.csv is a file of ",
               "another type than '", relation_type, "'")
        }
      }
    }

    compare <- list(
      "<"  = function(a, b) a <  b,
      "<=" = function(a, b) a <= b,
      ">"  = function(a, b) a >  b,
      ">=" = function(a, b) a >= b
    )

    system_groups <- parameters[setdiff(names(parameters), "assets")]
  }

  # 2. Check each relation, for each asset
  # -------------------------------------------------------------
  {
    failures <- character(0)

    for (CONT_003 in names(parameters$assets)) {
      asset  <- parameters$assets[[CONT_003]]
      groups <- c(asset[setdiff(names(asset), c("asset_id", "asset_type"))],
                  system_groups)
      asset_note <- if (length(parameters$assets) > 1) {
        paste0(" [", CONT_003, "]")
      } else {
        ""
      }

      for (CONT_002 in seq_len(nrow(relations))) {
        relation <- trimws(relations$relation[CONT_002])
        if (is.null(compare[[relation]])) {
          stop("validate_parameter_relations: unknown relation '", relation,
               "' in Validation_parameter_relations.csv")
        }

        relation_type <- trimws(relations$asset_type[CONT_002])
        check_files(
          files         = trimws(c(relations$left_file[CONT_002],
                                   relations$right_file[CONT_002],
                                   relations$gap_file[CONT_002])),
          relation_type = relation_type
        )

        # A relation of another type of asset does not apply to this
        # one.
        if (relation_type != "-" && relation_type != asset$asset_type) {
          next
        }

        left_name  <- trimws(relations$left_parameter[CONT_002])
        right_name <- trimws(relations$right_parameter[CONT_002])
        gap_name   <- trimws(relations$gap_parameter[CONT_002])

        left  <- value_of(left_name, groups)
        right <- value_of(right_name, groups)
        gap   <- if (gap_name == "-") 0 else value_of(gap_name, groups)

        holds <- compare[[relation]](left + gap, right)
        if (!all(holds)) {
          broken <- which(!holds)[1]
          failures <- c(failures, paste0(
            left_name,
            if (gap_name == "-") "" else paste0(" + ", gap_name),
            " ", relation, " ", right_name, " does not hold",
            if (length(holds) > 1) paste0(" on row ", broken) else "",
            ": ", left[min(broken, length(left))],
            if (gap_name == "-") "" else paste0(" + ", gap),
            " against ", right[min(broken, length(right))],
            " (", trimws(relations$left_file[CONT_002]), ", ",
            trimws(relations$right_file[CONT_002]), ")", asset_note
          ))
        }
      }
    }

    # A relation between two parameters of the system fails in the
    # same words for every asset, and is listed once.
    failures <- unique(failures)
  }

  # 3. Stop when any fails
  # -------------------------------------------------------------
  {
    if (length(failures) > 0) {
      stop("Parameters that break a relation of ",
           "Validation_parameter_relations.csv:\n  - ",
           paste(failures, collapse = "\n  - "))
    }
  }

  rm(list = c("value_of", "check_files", "compare", "failures",
              "system_groups"))

  return(invisible(TRUE))
}
