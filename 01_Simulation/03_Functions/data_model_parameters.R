# -------------------------------------------------------------
# Script: data_model_parameters.R
# Defines load_data_model_parameters() function
# Called by Main.R and Main_SCC.R
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Arguments:
#   main_file, model_file, reward_file, forecast_file
# Returns a list with:
#   Main_df, model_parameters, reward_parameters,
#   forecast_parameters, forecast_type, parameters
# -------------------------------------------------------------

load_data_model_parameters <- function(main_file,
                                       model_file,
                                       reward_file,
                                       forecast_file) {
  # Load data frame
  {
    Main_df <- readRDS(main_file)
    validate_Main_df(Main_df)
  }

  # Model, forecast & Reward parameters
  {
    model_parameters <- load_parameters(model_file)
    if (is.null(model_parameters)) stop("Model parameters could not be loaded")
    cat("model parameters loaded\n")

    reward_parameters <- load_parameters(reward_file)
    if (is.null(reward_parameters)) stop("Reward parameters could not be loaded")
    cat("reward parameters loaded\n")

    forecast_parameters <- load_parameters(forecast_file)
    if (is.null(forecast_parameters)) stop("Weather forecast parameters could not be loaded")

    if (forecast_parameters$forecast_type == 1){
      forecast_type <- "inaccurate"
    } else {
      forecast_type <- "accurate"
    }

    cat("Weather forecast parameters loaded\n")

    parameters <- c(model_parameters, reward_parameters, forecast_parameters)
  }

  return(list(
    Main_df             = Main_df,
    model_parameters    = model_parameters,
    reward_parameters   = reward_parameters,
    forecast_parameters = forecast_parameters,
    forecast_type       = forecast_type,
    parameters          = parameters
  ))
}
