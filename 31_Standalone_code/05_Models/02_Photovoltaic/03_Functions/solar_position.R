# -------------------------------------------------------------
# Function: solar_position.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Computes the position of the sun at a place, and the incidence of
# its rays on a tilted surface, for a vector of instants. It is the
# geometry of the photovoltaic model: photovoltaic_solar_geometry()
# calls it once for the whole time grid of an installation, and the
# model reads its three results from the table of the installation.
# The position follows the algorithm of the NOAA Solar Calculator,
# which is based on Meeus, Astronomical Algorithms (1991). It is
# geometric: it does not include the refraction of the atmosphere.
# Against the NREL Solar Position Algorithm it differs by less than
# 0.02 degrees for the year 2024 at a latitude of 43 degrees.
# The coefficients of the series of the algorithm (the mean
# longitude and anomaly of the sun, the equation of the centre, the
# nutation, the obliquity of the ecliptic, the equation of time) and
# the conversion between degrees and radians belong to the published
# algorithm. They are structural constants of the calculation, not
# parameters of the simulation, and so are the Julian date of the
# Unix epoch and the number of seconds of a day, minutes of a day
# and degrees of a circle.
# -------------------------------------------------------------
# The geometry
# Angles are in degrees at the input and at the output, and in
# radians inside. The azimuth is measured from the south, and it is
# positive to the west: east -90, south 0, west 90. The sun is taken
# at the instant of each row plus time_offset, so that the position
# is that of the instant the radiation of the row stands for.
# 1. The Julian date and the Julian century of the instant.
# 2. The declination of the sun and the equation of time.
# 3. The true solar time, and with it the hour angle.
# 4. The elevation and the azimuth of the sun.
# 5. The cosine of the angle between the rays and the normal of the
#    surface, with the tilt and the azimuth of the surface. It is
#    negative when the sun is behind the surface.
# -------------------------------------------------------------
# Inputs
#   time        : POSIXct vector. The instants, in UTC.
#   latitude    : Number. Latitude of the place (deg), positive to
#                 the north.
#   longitude   : Number. Longitude of the place (deg), positive to
#                 the east.
#   time_offset : Number. Time added to every instant before the
#                 position is computed (min).
#   tilt        : Number. Tilt of the surface from the horizontal
#                 (deg).
#   azimuth     : Number. Direction the surface faces (deg), 0 south,
#                 -90 east, 90 west.
# -------------------------------------------------------------
# Outputs
#   Data frame, one row per element of time, with the columns:
#   - Sun_elevation: elevation of the sun over the horizon (deg),
#     negative with the sun below it.
#   - Sun_azimuth: azimuth of the sun (deg), 0 south, positive to
#     the west.
#   - Cos_incidence: cosine of the angle of incidence of the rays on
#     the surface (-).
# -------------------------------------------------------------
# Code outline
# 1. Julian date and Julian century
# 2. Declination and equation of time
# 3. Hour angle
# 4. Elevation and azimuth of the sun
# 5. Incidence on the surface
# -------------------------------------------------------------
# Usage instructions
# position <- solar_position(
#   time        = time,
#   latitude    = 43.26,
#   longitude   = -2.93,
#   time_offset = -30,
#   tilt        = 30,
#   azimuth     = 0
# )
# -------------------------------------------------------------

solar_position <- function(time,
                           latitude,
                           longitude,
                           time_offset,
                           tilt,
                           azimuth) {

  # -------------------------------------------------------------
  # 1. Julian date and Julian century
  # The instant, shifted by the offset, in seconds since the Unix
  # epoch. The Julian date of the epoch is 2440587.5, and the
  # Julian century starts at the Julian date 2451545 (year 2000).
  # -------------------------------------------------------------
  {
    to_rad <- pi / 180
    to_deg <- 180 / pi

    seconds <- as.numeric(time) + time_offset * 60
    jd      <- seconds / 86400 + 2440587.5
    jc      <- (jd - 2451545) / 36525
  }

  # -------------------------------------------------------------
  # 2. Declination and equation of time
  # The mean longitude, the mean anomaly and the eccentricity of the
  # orbit give the equation of the centre, the true longitude of
  # the sun and, corrected for the nutation, its apparent longitude.
  # With the corrected obliquity of the ecliptic they give the
  # declination. The equation of time (min) is the difference
  # between the apparent and the mean solar time.
  # -------------------------------------------------------------
  {
    L0 <- (280.46646 + jc * (36000.76983 + jc * 0.0003032)) %% 360
    M  <- 357.52911 + jc * (35999.05029 - 0.0001537 * jc)
    e  <- 0.016708634 - jc * (0.000042037 + 0.0000001267 * jc)

    M_rad <- M * to_rad
    C     <- sin(M_rad) * (1.914602 - jc * (0.004817 + 0.000014 * jc)) +
      sin(2 * M_rad) * (0.019993 - 0.000101 * jc) +
      sin(3 * M_rad) * 0.000289

    node_rad    <- (125.04 - 1934.136 * jc) * to_rad
    true_long   <- L0 + C
    apparent    <- true_long - 0.00569 - 0.00478 * sin(node_rad)
    mean_obliq  <- 23 + (26 + (21.448 - jc * (46.815 + jc *
                    (0.00059 - jc * 0.001813))) / 60) / 60
    obliq_rad   <- (mean_obliq + 0.00256 * cos(node_rad)) * to_rad
    declination <- asin(sin(obliq_rad) * sin(apparent * to_rad))

    y        <- tan(obliq_rad / 2)^2
    L0_rad   <- L0 * to_rad
    eq_time  <- 4 * to_deg * (y * sin(2 * L0_rad) -
                              2 * e * sin(M_rad) +
                              4 * e * y * sin(M_rad) * cos(2 * L0_rad) -
                              0.5 * y^2 * sin(4 * L0_rad) -
                              1.25 * e^2 * sin(2 * M_rad))

    rm(list = c("L0", "M", "e", "M_rad", "C", "node_rad", "true_long",
                "apparent", "mean_obliq", "obliq_rad", "y", "L0_rad", "jd",
                "jc"))
  }

  # -------------------------------------------------------------
  # 3. Hour angle
  # The true solar time (min) is the UTC time of the day plus the
  # equation of time plus 4 minutes per degree of longitude. The
  # hour angle is 0 at the solar noon, negative in the morning and
  # positive in the afternoon.
  # -------------------------------------------------------------
  {
    utc_minutes     <- (seconds %% 86400) / 60
    true_solar_time <- (utc_minutes + eq_time + 4 * longitude) %% 1440
    hour_angle      <- (true_solar_time / 4 - 180) * to_rad

    rm(list = c("seconds", "utc_minutes", "true_solar_time", "eq_time"))
  }

  # -------------------------------------------------------------
  # 4. Elevation and azimuth of the sun
  # The cosine of the zenith angle is bounded to [-1, 1] before the
  # elevation is taken. The azimuth from the south comes from the
  # hour angle, the latitude and the declination.
  # -------------------------------------------------------------
  {
    lat_rad   <- latitude * to_rad
    cos_zenith <- sin(lat_rad) * sin(declination) +
      cos(lat_rad) * cos(declination) * cos(hour_angle)
    cos_zenith <- pmin(pmax(cos_zenith, -1), 1)

    sun_elevation <- asin(cos_zenith) * to_deg
    sun_azimuth   <- atan2(sin(hour_angle),
                           cos(hour_angle) * sin(lat_rad) -
                             tan(declination) * cos(lat_rad))

    rm(list = c("lat_rad", "declination", "hour_angle"))
  }

  # -------------------------------------------------------------
  # 5. Incidence on the surface
  # cos(incidence) = cos(zenith) * cos(tilt) + sin(zenith) *
  # sin(tilt) * cos(azimuth of the sun - azimuth of the surface).
  # -------------------------------------------------------------
  {
    tilt_rad     <- tilt * to_rad
    sin_zenith   <- sqrt(1 - cos_zenith^2)
    cos_incidence <- cos_zenith * cos(tilt_rad) +
      sin_zenith * sin(tilt_rad) * cos(sun_azimuth - azimuth * to_rad)

    position <- data.frame(
      Sun_elevation = sun_elevation,
      Sun_azimuth   = sun_azimuth * to_deg,
      Cos_incidence = cos_incidence
    )

    rm(list = c("to_rad", "to_deg", "cos_zenith", "sin_zenith", "sun_elevation",
                "sun_azimuth", "tilt_rad", "cos_incidence"))
  }

  return(position)
}
