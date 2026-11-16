# -------------------------------------------------------------
# Function: decode_chromosome.R
# Part of the Model Predictive Control in buildings repository
# <https://github.com/robgaray/Model-Predictive-Control-in-Buildings>
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Turns a chromosome of the genetic algorithm into the control of
# each asset over the horizon. The chromosome is made of one block
# per asset with genes, as chromosome_layout() lays it out. Each
# block is handed to the operation decode_genes of the type of model
# of its asset (model_type_contract()), which turns its genes, one
# per market interval, into the control table of the asset: for a
# Building, the setpoints of each market interval with their
# deadbands.
# -------------------------------------------------------------
# Inputs
#   x              : Integer vector, the chromosome, of length
#                    layout$n_genes.
#   layout         : Named list, as chromosome_layout() returns it.
#                    Its blocks give the asset of each block, the
#                    number of options of its genes and the
#                    positions of its first and last genes.
#   target_periods : POSIXct vector. Start of each market interval of
#                    the horizon, one per gene of each block.
#   parameters     : Named list. Must contain parameters$assets, the
#                    asset registry, and what the operation
#                    decode_genes of each type reads (for a Building:
#                    control$pad_heating and control$pad_cooling).
# -------------------------------------------------------------
# Outputs
#   Named list, one element per asset with genes, named by its
#   asset_id: the control table of the asset, one row per market
#   interval, as the operation decode_genes of its type returns it.
# -------------------------------------------------------------
# Code outline
# 1. Check the chromosome against the layout
# 2. Decode each block with the model of its asset
# -------------------------------------------------------------
# Usage instructions
# controls <- decode_chromosome(
#   x              = x,
#   layout         = layout,
#   target_periods = timestamps$target_periods,
#   parameters     = parameters
# )
# -------------------------------------------------------------

decode_chromosome <- function(x,
                              layout,
                              target_periods,
                              parameters
                              ) {

  # -------------------------------------------------------------
  # 1. Check the chromosome against the layout
  # -------------------------------------------------------------
  {
    if (length(x) != layout$n_genes) {
      stop("decode_chromosome: the chromosome has ", length(x),
           " genes, but its layout has ", layout$n_genes)
    }
  }

  # -------------------------------------------------------------
  # 2. Decode each block with the model of its asset
  # -------------------------------------------------------------
  {
    controls <- vector("list", nrow(layout$blocks))
    names(controls) <- layout$blocks$asset_id

    for (CONT_001 in seq_len(nrow(layout$blocks))) {
      block <- layout$blocks[CONT_001, ]
      asset <- parameters$assets[[block$asset_id]]

      # model_type_contract is called to take the operations of the
      # type of model of the asset of this block, through which its
      # genes are decoded.
      model <- model_type_contract(asset$asset_type)

      # The operation decode_genes of the model is called to turn the
      # genes of this block, one per market interval, into the
      # control of its asset over the horizon.
      controls[[CONT_001]] <- model$decode_genes(
        genes          = x[block$first_gene:block$last_gene],
        gene_options   = block$gene_options,
        target_periods = target_periods,
        parameters     = parameters,
        asset          = asset
      )
      rm(list = c("block", "asset", "model"))
    }
    rm(list = "CONT_001")
  }

  return(controls)
}
