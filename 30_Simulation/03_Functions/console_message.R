# -------------------------------------------------------------
# Function: console_message.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Writes one line of the console. Every message of the simulation
# goes through it, so that the lines of a run are aligned. A line
# has three columns:
#   - the label, the kind of the message, padded to the width of the
#     longest label
#   - the instant of the simulation the message refers to, as
#     console_time() writes it, or blanks of the same width when
#     the message has no instant
#   - the text
# The labels are LOAD, DATA, PREPARE, RUN, MARKET, TRANSFER and
# WARNING. The width of each column follows from the labels and from
# the format of the instant, so no width is written anywhere else.
# It writes lines only. A warning of the simulation is still raised
# with warning(), and an error with stop().
# -------------------------------------------------------------
# Inputs
# label : Character. One of the labels listed above.
# text  : Character. The text of the line.
# time  : POSIXct of length 1, or NULL. The instant of the line.
# -------------------------------------------------------------
# Outputs
# None. The line is written to the console.
# -------------------------------------------------------------
# Code outline
# 1. Labels and widths
# 2. Check
# 3. Write the line
# -------------------------------------------------------------
# Usage instructions
# console_message(
#   label = "RUN",
#   text  = "Simulation of 1000 steps",
#   time  = Main_df$time[1]
# )
# -------------------------------------------------------------

console_message <- function(label,
                            text,
                            time = NULL) {

  # -------------------------------------------------------------
  # 1. Labels and widths
  # The width of the label column is that of the longest label, and
  # the width of the instant column that of an instant formatted.
  # -------------------------------------------------------------
  {
    labels <- c("LOAD", "DATA", "PREPARE", "RUN", "MARKET", "TRANSFER",
                "WARNING")

    # console_time is called to format a reference instant, whose
    # width is the width of the instant column.
    time_width  <- nchar(console_time(as.POSIXct(0, origin = "1970-01-01")))
    label_width <- max(nchar(labels))
  }

  # -------------------------------------------------------------
  # 2. Check
  # -------------------------------------------------------------
  {
    if (length(label) != 1 || !(label %in% labels)) {
      stop("console_message(): unknown label '",
           paste(label, collapse = ","), "'")
    }
    if (!is.null(time) && length(time) != 1) {
      stop("console_message(): time must be of length 1 or NULL")
    }
  }

  # -------------------------------------------------------------
  # 3. Write the line
  # -------------------------------------------------------------
  {
    # console_time is called to format the instant of the line.
    time_text <- if (is.null(time)) "" else console_time(time)

    cat(formatC(label, width = -label_width), " ",
        formatC(time_text, width = -time_width), " ",
        text, "\n", sep = "")
  }

  rm(list = c("labels", "time_width", "label_width", "time_text"))

  invisible(NULL)
}
