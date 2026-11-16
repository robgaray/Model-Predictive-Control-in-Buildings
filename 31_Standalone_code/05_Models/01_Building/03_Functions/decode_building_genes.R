# -------------------------------------------------------------
# Function: decode_building_genes.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Turns the genes of a building into its control: one setpoint mode
# per market interval becomes the heating and cooling setpoints of
# each interval, with their hysteresis deadbands. It is the operation
# decode_genes of the type Building (see model_type_contract()).
# -------------------------------------------------------------
# Inputs
#   genes          : Integer vector, one mode index per market
#                    interval of the horizon, from 1 to gene_options.
#   gene_options   : Integer scalar. Number of setpoint modes, as
#                    building_gene_options() gives it.
#   target_periods : POSIXct vector. Start of each market interval of
#                    the horizon, one per gene.
#   parameters     : Named list. The parameters of the system. Not
#                    read: every interval of the horizon has a gene.
#   asset          : Named list. The parameters of the building, its
#                    entry of parameters$assets. Must contain
#                    setpoint_modes, the data frame of the modes, and
#                    control$Deadband, the width of the hysteresis
#                    band [degC].
# -------------------------------------------------------------
# Outputs
#   Data frame, one row per market interval, as
#   convert_modes_to_setpoints() returns it:
#     - period
#     - STP_heat, STP_heat_low, STP_heat_high
#     - STP_cool, STP_cool_low, STP_cool_high
# -------------------------------------------------------------
# Code outline
# 1. Pair each gene with its market interval
# 2. Convert the modes to setpoints
# -------------------------------------------------------------
# Usage instructions
# set_point_df <- decode_building_genes(
#   genes          = x,
#   gene_options   = n_modes,
#   target_periods = timestamps$target_periods,
#   parameters     = parameters,
#   asset          = asset
# )
# -------------------------------------------------------------

decode_building_genes <- function(genes,
                                  gene_options,
                                  target_periods,
                                  parameters,
                                  asset
                                  ) {

  # -------------------------------------------------------------
  # 1. Pair each gene with its market interval
  # -------------------------------------------------------------
  {
    # maxmode is called to pair the mode of each gene with the start
    # of its market interval, so that the modes can be converted to
    # setpoints below.
    set_point_df_inner <- maxmode(
      x              = genes,
      n_modes        = gene_options,
      n_periods      = length(target_periods),
      target_periods = target_periods
    )
  }

  # -------------------------------------------------------------
  # 2. Convert the modes to setpoints
  # -------------------------------------------------------------
  {
    # convert_modes_to_setpoints is called to translate the mode of
    # each interval into the heating and cooling setpoints, with the
    # hysteresis deadbands the building simulation reads.
    set_point_df <- convert_modes_to_setpoints(
      setpoint_modes_df = set_point_df_inner,
      setpoint_modes    = asset$setpoint_modes,
      Deadband          = asset$control$Deadband,
      target_periods    = target_periods
    )
    rm(list = "set_point_df_inner")
  }

  return(set_point_df)
}
