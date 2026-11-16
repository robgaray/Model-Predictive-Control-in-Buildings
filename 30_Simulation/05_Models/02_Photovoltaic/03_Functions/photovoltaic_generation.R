# -------------------------------------------------------------
# Function: photovoltaic_generation.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Computes the electricity a photovoltaic installation produces over
# a chunk, for one itinerary, with the radiation on the plane of its
# modules. It is the operation simulate_itinerary
# of the contract of the type Photovoltaic (see
# model_type_contract()). The installation has no control: its
# production depends only on the solar radiation and the outdoor
# temperature, so the plan and the two flexibility itineraries get
# the same production when they are computed with the same weather.
# The weather is the one of the calculation context:
#   - execution: the measured weather, SolarR and Text.
#   - plan, plan_flex_down and plan_flex_up: the forecast of the
#     weather, SolarR_forec and Text_forec.
# Row 1 of the chunk is the initial condition and it is never
# written. Each row i >= 2 holds the energy of the step that ends in
# it, with the weather of the row and the duration of the step,
# delta_t_h = (time[i] - time[i - 1]) / 3600.
# -------------------------------------------------------------
# The model
# In each step, with G the solar radiation on the horizontal plane
# (W/m2) and T_amb the outdoor temperature (degC), and the reference
# conditions of the modules (reference_conditions of asset):
#   1. G_poa  <- the radiation on the plane of the modules (W/m2),
#                from G and from the geometry of the sun of the row
#                (see plane_of_array_irradiance()). A negative
#                radiation, which a forecast may give, counts as 0.
#   2. T_cell <- T_amb + (NOCT - PV_NOCT_ambient_temperature) *
#                G_poa / PV_NOCT_irradiance
#        The temperature of the cells.
#   3. P_dc   <- Module_area * Module_efficiency * G_poa / 1000 *
#                (1 - DC_losses) * (1 + Temperature_coefficient /
#                100 * (T_cell - PV_STC_cell_temperature))
#        The power of the modules (kW). The 1000 turns W into kW
#        and the 100 turns the coefficient from %/K to 1/K.
#        DC_losses holds the losses of the wiring, the dirt, the
#        mismatch, the first degradation and the tolerance of the
#        modules, and not those of the temperature, which this
#        step computes.
#   4. P_ac   <- pmin(Inverter_efficiency * pmax(P_dc, 0),
#                     Inverter_power)
#        The power the inverter delivers (kW): never negative, with
#        the losses of the inverter, and clipped at its maximum
#        power.
#   5. Elec_PV <- P_ac * delta_t_h; Elec_total <- -Elec_PV
#        The energy of the step (kWh). The production is negative
#        electricity for the system.
# The elevation of the sun and the cosine of the angle of
# incidence of the row come from the table of the installation
# (see photovoltaic_solar_geometry()).
# -------------------------------------------------------------
# Inputs
#   period_chunk        : Data frame. The chunk, with time, the weather
#                         of the context, the columns Sun_elevation
#                         and Cos_incidence, and the columns G_poa,
#                         T_cell, Elec_PV and Elec_total of the
#                         context.
#   asset               : Named list. The parameters of the
#                         installation, its entry of
#                         parameters$assets, with the groups
#                         photovoltaic, reference_conditions and
#                         sun.
#   calculation_mode    : Not read.
#   calculation_context : Character. One of "execution", "plan",
#                         "plan_flex_down" and "plan_flex_up".
#   set_point_df        : Not read.
#   Q_heat_cap          : Not read.
#   Q_cool_cap          : Not read.
#   Every operation simulate_itinerary of the contract receives the
#   same arguments (see model_type_contract()). An installation has
#   no setpoints and no heat or cooling power, so it does not read
#   the last four.
# -------------------------------------------------------------
# Outputs
#   Data frame. period_chunk with G_poa, T_cell, Elec_PV and
#   Elec_total of the context written on rows 2 to n. A chunk of
#   fewer than 2 rows comes back as it was. The run stops if the
#   weather or the geometry of the sun of a row it writes is
#   missing.
# -------------------------------------------------------------
# Code outline
# 1. Check the context and take the weather
# 2. Compute the production
# 3. Write it into the chunk
# -------------------------------------------------------------
# Usage instructions
# period_chunk <- photovoltaic_generation(
#   period_chunk        = period_chunk,
#   asset               = asset,
#   calculation_context = "plan"
# )
# -------------------------------------------------------------

photovoltaic_generation <- function(period_chunk,
                                    asset,
                                    calculation_mode = 1,
                                    calculation_context = "execution",
                                    set_point_df = NULL,
                                    Q_heat_cap = NULL,
                                    Q_cool_cap = NULL) {

  # -------------------------------------------------------------
  # 1. Check the context and take the weather
  # The column suffix and the weather columns depend on the context.
  # A chunk of one row has no step to compute.
  # -------------------------------------------------------------
  {
    n <- nrow(period_chunk)
    if (n < 2) {
      return(period_chunk)
    }

    col_sfx <- switch(calculation_context,
                      "execution"      = "_exec",
                      "plan"           = "_plan",
                      "plan_flex_down" = "_plan_flex_down",
                      "plan_flex_up"   = "_plan_flex_up",
                      stop("photovoltaic_generation: invalid ",
                           "calculation_context '", calculation_context,
                           "'"))

    if (calculation_context == "execution") {
      weather_cols <- c(irradiance = "SolarR", temperature = "Text")
    } else {
      weather_cols <- c(irradiance  = "SolarR_forec",
                        temperature = "Text_forec")
    }

    rows         <- 2:n
    G            <- period_chunk[[weather_cols[["irradiance"]]]][rows]
    T_amb        <- period_chunk[[weather_cols[["temperature"]]]][rows]
    delta_t_h    <- diff(as.numeric(period_chunk$time)) / 3600

    if (anyNA(G) || anyNA(T_amb)) {
      stop("photovoltaic_generation: ",
           paste(weather_cols, collapse = " and "),
           " have missing values in the rows to compute")
    }

    geometry_cols <- c("Sun_elevation", "Cos_incidence")
    if (!all(geometry_cols %in% names(period_chunk)) ||
        anyNA(period_chunk[rows, geometry_cols])) {
      stop("photovoltaic_generation: the geometry of the sun ",
           "(Sun_elevation and Cos_incidence) is missing in the rows ",
           "to compute")
    }
    sun_elevation <- period_chunk$Sun_elevation[rows]
    cos_incidence <- period_chunk$Cos_incidence[rows]

    photovoltaic_parameters <- asset$photovoltaic
    reference_conditions    <- asset$reference_conditions
    solar_constant          <- asset$sun$Solar_constant
  }

  # -------------------------------------------------------------
  # 2. Compute the production
  # The steps of the model, in this order (see the header).
  # -------------------------------------------------------------
  {
    # plane_of_array_irradiance is called to split the radiation of
    # the rows on the horizontal plane and project it on the plane
    # of the modules.
    irradiance <- plane_of_array_irradiance(
      G                 = G,
      sun_elevation     = sun_elevation,
      cos_incidence     = cos_incidence,
      tilt              = photovoltaic_parameters$Tilt,
      albedo            = photovoltaic_parameters$Albedo,
      diffuse_threshold = photovoltaic_parameters$Diffuse_threshold,
      min_sun_elevation = photovoltaic_parameters$Min_sun_elevation,
      solar_constant    = solar_constant
    )
    G_poa <- irradiance$G_poa

    T_cell  <- T_amb + (photovoltaic_parameters$NOCT -
                         reference_conditions$PV_NOCT_ambient_temperature) *
      G_poa / reference_conditions$PV_NOCT_irradiance
    P_dc    <- photovoltaic_parameters$Module_area *
      photovoltaic_parameters$Module_efficiency * G_poa / 1000 *
      (1 - photovoltaic_parameters$DC_losses) *
      (1 + photovoltaic_parameters$Temperature_coefficient / 100 *
         (T_cell - reference_conditions$PV_STC_cell_temperature))
    P_ac    <- pmin(photovoltaic_parameters$Inverter_efficiency *
                      pmax(P_dc, 0),
                    photovoltaic_parameters$Inverter_power)
    Elec_PV <- P_ac * delta_t_h
  }

  # -------------------------------------------------------------
  # 3. Write it into the chunk
  # Row 1 is the initial condition and keeps its value.
  # -------------------------------------------------------------
  {
    period_chunk[[paste0("G_poa", col_sfx)]][rows]      <- G_poa
    period_chunk[[paste0("T_cell", col_sfx)]][rows]     <- T_cell
    period_chunk[[paste0("Elec_PV", col_sfx)]][rows]    <- Elec_PV
    period_chunk[[paste0("Elec_total", col_sfx)]][rows] <- -Elec_PV

    rm(list = c("n", "col_sfx", "weather_cols", "rows", "G", "T_amb",
                "delta_t_h", "geometry_cols", "sun_elevation", "cos_incidence",
                "photovoltaic_parameters", "reference_conditions",
                "solar_constant", "irradiance", "G_poa", "T_cell", "P_dc",
                "P_ac", "Elec_PV"))
  }

  return(period_chunk)
}
