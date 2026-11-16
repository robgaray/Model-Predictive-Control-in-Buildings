# -------------------------------------------------------------
# Function: split_config_sections.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Splits the lines of a configuration file into its block of
# parameters and its table. A file holds a block of parameters above
# its table when its first line that is neither a comment nor blank
# is the header parameter,value,unit. The block then runs from that
# header to the first blank line after it, and the table is every
# line after that blank line that is neither a comment nor blank:
# its header, its unit row and its rows.
# A file that does not start with that header has no block: all its
# lines that are neither a comment nor blank are returned as its
# table. A file that starts with the header and has no blank line
# after it is a flat file of parameters: all its lines are returned
# as its block, and it has no table.
# The function never stops: the readers decide what a missing part
# means for them.
# -------------------------------------------------------------
# Inputs
#   lines : Character vector. The lines of the file, as readLines()
#           returns them.
# -------------------------------------------------------------
# Outputs
#   Named list with two integer vectors of line numbers, each one
#   integer(0) when the part is absent:
#     - block : the lines of the block, its header first
#     - table : the lines of the table, its header first
# -------------------------------------------------------------
# Code outline
# 1. Find the lines that are neither a comment nor blank
# 2. Decide whether the file starts with a block, and where it ends
# -------------------------------------------------------------
# Usage instructions
# lines    <- readLines(path)
# sections <- split_config_sections(lines)
# lines[sections$table]
# -------------------------------------------------------------

split_config_sections <- function(lines) {

  # 1. Find the lines that are neither a comment nor blank
  # -------------------------------------------------------------
  {
    is_blank <- !nzchar(trimws(lines))
    content  <- which(!grepl("^\\s*#", lines) & !is_blank)
  }

  # 2. Decide whether the file starts with a block, and where it ends
  # -------------------------------------------------------------
  {
    block <- integer(0)
    table <- content

    if (length(content) > 0) {
      first_fields <- trimws(strsplit(lines[content[1]], ",",
                                      fixed = TRUE)[[1]])

      if (identical(first_fields, c("parameter", "value", "unit"))) {
        closing <- which(is_blank & seq_along(lines) > content[1])[1]
        if (is.na(closing)) {
          block <- content
          table <- integer(0)
        } else {
          block <- content[content < closing]
          table <- content[content > closing]
        }
        rm(list = "closing")
      }
      rm(list = "first_fields")
    }

    rm(list = c("is_blank", "content"))
  }

  return(list(block = block, table = table))
}
