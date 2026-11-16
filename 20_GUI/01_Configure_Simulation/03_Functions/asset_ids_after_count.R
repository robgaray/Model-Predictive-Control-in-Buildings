# -------------------------------------------------------------
# Function: asset_ids_after_count.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Works out which assets of a type enter and which leave when the
# user changes the number of assets of that type. An asset id is the
# type, an underscore and a number of three digits, for example
# Building_002.
#   - When the number is raised, the new assets take the lowest free
#     numbers. With Building_001 and Building_005, one more asset is
#     Building_002.
#   - When the number is lowered, the assets with the highest numbers
#     leave.
# -------------------------------------------------------------
# Inputs
#   existing_ids : Character vector. The ids of the assets of the
#                  type that exist now, in any order.
#   asset_type   : Character. The type, for example Building.
#   count        : Integer. The number of assets of the type that the
#                  user asks for.
# -------------------------------------------------------------
# Outputs
#   Named list with the elements:
#     - add: Character vector. The ids that enter, in the order of
#       their numbers.
#     - remove: Character vector. The ids that leave, from the
#       highest number down.
#   It stops when the number asked for is not a whole number, or when
#   it does not fit in the three digits of an id.
# -------------------------------------------------------------
# Code outline
# 1. Check the number asked for.
# 2. Lower the number: take the highest numbers out.
# 3. Raise the number: add the lowest free numbers.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   asset_ids_after_count(existing_ids, asset_type, count)
# -------------------------------------------------------------

asset_ids_after_count <- function(existing_ids, asset_type, count) {

  # -------------------------------------------------------------
  # 1. Check the number asked for
  # The ids hold three digits, so a type holds at most 999 assets.
  # -------------------------------------------------------------
  {
    id_digits <- 3
    max_count <- 10^id_digits - 1
    if (length(count) != 1 || is.na(count) || count != round(count) ||
        count < 0 || count > max_count) {
      stop("The number of assets of type ", asset_type,
           " must be a whole number between 0 and ", max_count)
    }

    id_numbers <- as.integer(sub("^.*_", "", existing_ids))
    id_order   <- order(id_numbers)
    existing_ids <- existing_ids[id_order]
    id_numbers   <- id_numbers[id_order]
    to_add       <- character(0)
    to_remove    <- character(0)
    rm(id_order)
  }

  # -------------------------------------------------------------
  # 2. Lower the number: take the highest numbers out
  # -------------------------------------------------------------
  {
    if (count < length(existing_ids)) {
      to_remove <- rev(existing_ids)[seq_len(length(existing_ids) - count)]
    }
  }

  # -------------------------------------------------------------
  # 3. Raise the number: add the lowest free numbers
  # -------------------------------------------------------------
  {
    if (count > length(existing_ids)) {
      free_numbers <- setdiff(seq_len(max_count), id_numbers)
      free_numbers <- free_numbers[seq_len(count - length(existing_ids))]
      to_add <- sprintf(paste0("%s_%0", id_digits, "d"), asset_type,
                        free_numbers)
      rm(free_numbers)
    }
    rm(id_digits, max_count, id_numbers)
  }

  return(list(add = to_add, remove = to_remove))
}
