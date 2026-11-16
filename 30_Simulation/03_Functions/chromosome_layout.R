# -------------------------------------------------------------
# Function: chromosome_layout.R
# Part of the Model Predictive Control in buildings repository
# <https://github.com/robgaray/Model-Predictive-Control-in-Buildings>
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the layout of the chromosome of the genetic algorithm: which
# genes belong to which asset, and the bounds of each gene.
# The chromosome is made of blocks, one per asset with genes, in the
# order of the asset registry (parameters$assets), one block after
# the other. A block holds one gene per market interval of the
# horizon, in the order of the intervals. Each gene is a whole
# number from 1 to the number of options of the genes of its asset,
# which the operation gene_options of its type of model gives
# (model_type_contract()). An asset whose type has no genes (0
# options) has no block: the genetic algorithm decides nothing for
# it.
# With a single asset with genes, the chromosome is its block: one
# gene per market interval. When no asset has genes, the chromosome
# is empty: blocks has no rows, n_genes is 0 and the bounds are empty.
# -------------------------------------------------------------
# Inputs
#   parameters  : Named list. Must contain parameters$assets, the
#                 asset registry, one entry per asset with its
#                 asset_id and its asset_type.
#   n_intervals : Integer scalar. Number of market intervals of the
#                 optimization horizon, one gene per asset block.
# -------------------------------------------------------------
# Outputs
#   Named list with the elements:
#     - blocks : data frame, one row per asset with genes, in the
#                order of the chromosome, with the columns:
#                  - asset_id: the asset of the block
#                  - gene_options: the number of options of each
#                    gene of the block
#                  - first_gene: position of the first gene of the
#                    block in the chromosome
#                  - last_gene: position of its last gene
#     - n_genes : integer scalar, the length of the chromosome (0
#                 when no asset has genes)
#     - lower   : numeric vector, the lower bound of each gene (1)
#     - upper   : integer vector, the upper bound of each gene, the
#                 number of options of its asset
# -------------------------------------------------------------
# Code outline
# 1. Check the number of intervals
# 2. The number of options of the genes of each asset
# 3. The blocks one after the other
# 4. The bounds of each gene
# -------------------------------------------------------------
# Usage instructions
# layout <- chromosome_layout(
#   parameters  = parameters,
#   n_intervals = length(timestamps$target_periods)
# )
# -------------------------------------------------------------

chromosome_layout <- function(parameters,
                              n_intervals
                              ) {

  # -------------------------------------------------------------
  # 1. Check the number of intervals
  # -------------------------------------------------------------
  {
    if (!is.numeric(n_intervals) || length(n_intervals) != 1 ||
        is.na(n_intervals) || n_intervals < 1 ||
        n_intervals != round(n_intervals)) {
      stop("chromosome_layout: n_intervals must be a whole number of ",
           "market intervals, at least 1")
    }
  }

  # -------------------------------------------------------------
  # 2. The number of options of the genes of each asset
  # Each asset is asked through the contract of its type of model,
  # in the order of the asset registry.
  # -------------------------------------------------------------
  {
    asset_ids    <- names(parameters$assets)
    gene_options <- integer(length(asset_ids))

    for (CONT_001 in seq_along(asset_ids)) {
      asset <- parameters$assets[[CONT_001]]

      # model_type_contract is called to take the operations of the
      # type of model of this asset, through which its genes are
      # counted.
      model <- model_type_contract(asset$asset_type)

      # The operation gene_options of the model is called to give the
      # number of options of each gene of this asset, the upper bound
      # of the genes of its block.
      options_of_asset <- model$gene_options(asset)

      if (!is.numeric(options_of_asset) ||
          length(options_of_asset) != 1 ||
          is.na(options_of_asset) || options_of_asset < 0 ||
          options_of_asset != round(options_of_asset)) {
        stop("chromosome_layout: the operation gene_options of asset ",
             asset_ids[CONT_001], " must give a whole number of ",
             "options, 0 or more")
      }
      gene_options[CONT_001] <- as.integer(options_of_asset)
      rm(list = c("asset", "model", "options_of_asset"))
    }
    rm(list = "CONT_001")
  }

  # -------------------------------------------------------------
  # 3. The blocks one after the other
  # Only the assets with genes take a block. When no asset has genes,
  # there are no blocks and the chromosome is empty.
  # -------------------------------------------------------------
  {
    with_genes <- gene_options > 0

    n_blocks   <- sum(with_genes)
    first_gene <- (seq_len(n_blocks) - 1L) * as.integer(n_intervals) + 1L
    last_gene  <- first_gene + as.integer(n_intervals) - 1L

    blocks <- data.frame(
      asset_id         = asset_ids[with_genes],
      gene_options     = gene_options[with_genes],
      first_gene       = first_gene,
      last_gene        = last_gene,
      stringsAsFactors = FALSE
    )
    rm(list = c("with_genes", "n_blocks", "first_gene", "last_gene",
                "asset_ids", "gene_options"))
  }

  # -------------------------------------------------------------
  # 4. The bounds of each gene
  # -------------------------------------------------------------
  {
    n_genes <- nrow(blocks) * as.integer(n_intervals)
    lower   <- rep(1, n_genes)
    upper   <- rep(blocks$gene_options, each = as.integer(n_intervals))
  }

  return(list(
    blocks  = blocks,
    n_genes = n_genes,
    lower   = lower,
    upper   = upper
  ))
}
