# -------------------------------------------------------------
# Function: fitness_funct_optimize_mode.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function is the fitness function used by the Genetic Algorithm
# in optimize_modes(). It decodes a chromosome, made of one block of
# genes per asset with genes (chromosome_layout()), into the control
# of each asset, through the operation decode_genes of the type of
# model of each asset (decode_chromosome()). For a building, its
# block holds one mode index per market period and becomes its
# setpoints. It then evaluates the simulation, and returns the
# resulting scalar reward.
# -------------------------------------------------------------
# A candidate that cannot be evaluated
# A chromosome carrying NA is not an operation of the assets: it cannot be
# turned into setpoints and there is nothing to simulate. It is scored
# with a penalty large enough to be worse than any reachable reward, so
# the optimizer discards it, instead of being allowed to stop the run
# inside convert_modes_to_setpoints(). The chromosome should never
# arrive in that state - optimize_modes() sizes the elitism so that
# ga() cannot build one - and this is the net under that.
# -------------------------------------------------------------
# Inputs
#   x            : Integer vector of length layout$n_genes, the
#                  chromosome. Each block of it holds one gene per
#                  market period for one asset: for a building, a mode
#                  index (integer value from 1 to its number of modes)
#                  representing the active mode for that market period.
#   layout       : Named list. The layout of the chromosome, as
#                  chromosome_layout() returns it: the asset of each
#                  block and the positions of its genes.
#   timestamps   : Named list. Timestamp metadata. Must contain:
#                    timestamps$target_periods : POSIXct vector of market
#                                               period timestamps.
#   parameters   : Named list. Model and control parameters. Must contain:
#                    parameters$assets : the asset registry. A building
#                                        holds its setpoint_modes: Data
#                                        frame mapping mode indices to
#                                        setpoint values, and its
#                                        control$Deadband [degC].
#                    All other sub-elements required by evaluate_control().
#   piece        : List. The piece of the optimization horizon, as
#                  passed from optimize_modes(): the table of the
#                  system and the table of each asset. Together the
#                  tables hold all columns required by
#                  period_calculation() (called inside evaluate_control()).
#   simulation_control : Named list. Simulation control object passed through
#                        to evaluate_control().
#   marginal_context   : Named list or NULL. Passed through to
#                        evaluate_control().
# -------------------------------------------------------------
# Outputs
#   evaluation : Numeric scalar. Reward value extracted from evaluate_control()
#                return list for the given mode schedule. Higher is better.
# -------------------------------------------------------------
# Code outline
# 1. Decode the chromosome into the control of each asset
# 2. Evaluate control and compute reward
# -------------------------------------------------------------
# Usage instructions
# fitness <- fitness_funct_optimize_mode(x, layout, timestamps,
#                                        parameters, piece,
#                                        simulation_control,
#                                        marginal_context)
# -------------------------------------------------------------
fitness_funct_optimize_mode <- function(x,
                                        layout,
                                        timestamps,
                                        parameters,
                                        piece,
                                        simulation_control,
                                        marginal_context = NULL) {

  # 0. Refuse a chromosome that carries NA
  # -------------------------------------------------------------
  # The penalty is deliberately not a parameter: an unevaluable
  # candidate is not a preference the user can weigh. Its magnitude only
  # has to dominate any reachable reward, and the rewards of this model
  # are of the order of 1e3.
  # -------------------------------------------------------------
  {
    if (any(is.na(x))) {
      return(-1e9)
    }
  }

  # 1. Decode the chromosome into the control of each asset
  # -------------------------------------------------------------
  # x is already an integer vector, one block of genes per asset
  # with genes, each with one gene per period. The meaning of a gene
  # belongs to the type of model of its asset: the genes of a
  # building are setpoint modes.
  # -------------------------------------------------------------
  {
    # decode_chromosome is called to turn each block of this
    # candidate into the control of its asset: for a building, the
    # heating and cooling setpoints of each period, with their
    # deadbands, that evaluate_control() reads.
    controls <- decode_chromosome(
      x              = x,
      layout         = layout,
      target_periods = timestamps$target_periods,
      parameters     = parameters
    )
  }

  # 2. Evaluate control and compute reward
  # -------------------------------------------------------------
  {
    # evaluate_control is called to simulate the assets over this
    # candidate's control and return the scalar reward that the GA
    # uses to rank this individual.
    evaluation <- evaluate_control(
      piece              = piece,
      controls           = controls,
      parameters         = parameters,
      simulation_control = simulation_control,
      marginal_context   = marginal_context
    )
  }

  return(evaluation$reward)
}
