# -------------------------------------------------------------
# Function: decode_battery_genes.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Turns the genes of a battery into its control: one mode per
# market interval, a whole number from 1 to the number of modes of
# battery_modes(), becomes a table with the start of the interval
# and its mode. It is the operation decode_genes of the type
# Battery (see model_type_contract()). The table is the one
# battery_simulate_itinerary() reads as set_point_df.
# -------------------------------------------------------------
# Inputs
#   genes          : Integer vector, one mode per market interval of
#                    the horizon, from 1 to gene_options.
#   gene_options   : Integer scalar. Number of modes, as the
#                    operation gene_options of the battery gives it.
#   target_periods : POSIXct vector. Start of each market interval of
#                    the horizon, one per gene.
#   parameters     : Named list of the parameters of the simulation.
#                    It is not read: a battery needs none to decode
#                    its genes.
#   asset          : Named list. The parameters of the battery, its
#                    entry of parameters$assets. It is not read.
# -------------------------------------------------------------
# Outputs
#   Data frame, one row per market interval, with the columns:
#     - period: the start of the interval
#     - Mode: the mode of the interval, an integer
# -------------------------------------------------------------
# Code outline
# 1. Check the genes
# 2. Pair each gene with its market interval
# -------------------------------------------------------------
# Usage instructions
# control <- decode_battery_genes(
#   genes          = x,
#   gene_options   = 5L,
#   target_periods = timestamps$target_periods,
#   parameters     = parameters,
#   asset          = asset
# )
# -------------------------------------------------------------

decode_battery_genes <- function(genes,
                                 gene_options,
                                 target_periods,
                                 parameters,
                                 asset
                                 ) {

  # -------------------------------------------------------------
  # 1. Check the genes
  # There must be one gene per market interval, and each gene must
  # be a whole number between 1 and the number of modes.
  # -------------------------------------------------------------
  {
    if (length(genes) != length(target_periods)) {
      stop("decode_battery_genes: ", length(genes), " genes for ",
           length(target_periods), " market intervals")
    }
    if (!is.numeric(genes) || anyNA(genes) ||
        any(genes != round(genes)) ||
        any(genes < 1) || any(genes > gene_options)) {
      stop("decode_battery_genes: every gene must be a whole number ",
           "from 1 to ", gene_options)
    }
  }

  # -------------------------------------------------------------
  # 2. Pair each gene with its market interval
  # -------------------------------------------------------------
  {
    control <- data.frame(
      period = target_periods,
      Mode   = as.integer(genes)
    )
  }

  return(control)
}
