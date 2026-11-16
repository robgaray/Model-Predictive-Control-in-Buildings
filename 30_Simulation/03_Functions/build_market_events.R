# -------------------------------------------------------------
# Function: build_market_events.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds the table of the market events of the run: one row per
# clearing of a Scheduling or a Piloting market, read from the
# calendar columns of Main_df that prepare_market_calendar() writes.
# It is computed once, after the calendar, and every preparation that
# needs the events reads them from it:
#   - prepare_market_information(), for the rows of the price
#     matrices
#   - prepare_commitments(), for the rows of the commitment matrices
#   - prepare_economic_analysis(), for the rows of the economic
#     analysis
# A row of Main_df holds an event of a family when the market name of
# that family is set on it (is_market_active()). Each event is keyed
# by the market interval its clearing instant falls in
# (instant_market_slot()). When several rows of one family fall in
# the same interval, the first one is the event.
# -------------------------------------------------------------
# Inputs
#   Main_df           : Data frame. The simulation data frame, with
#                       time and the twelve calendar columns:
#                         - Sched_Market_Name, Pilot_Market_Name
#                         - Sched_Market_Bid_time, Pilot_Market_Bid_time
#                         - Sched_Market_Period_Begin,
#                           Pilot_Market_Period_Begin
#                         - Sched_Market_Period_End,
#                           Pilot_Market_Period_End
#                         - Sched_Optimization_Horizon,
#                           Pilot_Optimization_Horizon
#                         - Sched_Market_Aim, Pilot_Market_Aim
#   market_resolution : Numeric scalar (min). Length of a market
#                       interval, parameters$market$market_resolution.
# -------------------------------------------------------------
# Outputs
#   Data frame, one row per market event, ordered by event_slot and,
#   within one interval, Scheduling before Piloting. Its columns:
#     - family               : "Scheduling" or "Piloting"
#     - name                 : the market name (DA, ID1, cID1...)
#     - time                 : POSIXct. The instant of the row of
#                              Main_df that holds the event
#     - event_slot           : POSIXct. The market interval of the
#                              clearing instant
#     - bid_time             : the bid time of the calendar
#     - period_begin         : the beginning of the traded period
#     - period_end           : the end of the traded period
#     - optimization_horizon : the optimization horizon
#     - aim                  : the aim of the market
# -------------------------------------------------------------
# Code outline
# 1. Read the events of each family
# 2. Order the events
# -------------------------------------------------------------
# Usage instructions
# market_events <- build_market_events(
#   Main_df           = Main_df,
#   market_resolution = parameters$market$market_resolution
# )
# -------------------------------------------------------------

build_market_events <- function(Main_df, market_resolution) {

  # -------------------------------------------------------------
  # 1. Read the events of each family
  # The two families use the same calendar columns, with the prefix
  # Sched_ or Pilot_.
  # -------------------------------------------------------------
  {
    families <- c(Scheduling = "Sched", Piloting = "Pilot")

    events <- lapply(names(families), function(CONT_001) {
      prefix <- families[[CONT_001]]
      column <- function(name) Main_df[[paste0(prefix, name)]]

      # is_market_active is called per row to flag the rows where a
      # market of this family clears.
      active <- which(sapply(column("_Market_Name"), is_market_active))

      family_events <- data.frame(
        family               = rep(CONT_001, length(active)),
        name                 = as.character(column("_Market_Name")[active]),
        time                 = Main_df$time[active],
        # instant_market_slot is called to key each event by the
        # market interval its clearing instant falls in.
        event_slot           = instant_market_slot(
          time              = Main_df$time[active],
          market_resolution = market_resolution
        ),
        bid_time             = column("_Market_Bid_time")[active],
        period_begin         = column("_Market_Period_Begin")[active],
        period_end           = column("_Market_Period_End")[active],
        optimization_horizon = column("_Optimization_Horizon")[active],
        aim                  = column("_Market_Aim")[active],
        stringsAsFactors     = FALSE
      )

      family_events[!duplicated(family_events$event_slot), , drop = FALSE]
    })
    events <- do.call(rbind, events)

    rm(list = "families")
  }

  # -------------------------------------------------------------
  # 2. Order the events
  # By interval, and within one interval Scheduling (1) before
  # Piloting (2), the order the economic analysis is read in.
  # -------------------------------------------------------------
  {
    family_rank <- match(events$family, c("Scheduling", "Piloting"))
    events      <- events[order(events$event_slot, family_rank), ,
                          drop = FALSE]
    rownames(events) <- NULL

    rm(list = "family_rank")
  }

  return(events)
}
