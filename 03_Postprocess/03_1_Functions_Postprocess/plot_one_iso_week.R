plot_one_iso_week <- function(
    data,
    iso_week,
    year = NULL,
    ti_ylim = c(10, 35),
    file = NULL,        # <--- Optional filename for JPG output
    width = 1600,       # width in pixels
    height = 1200,      # height in pixels
    res = 150           # resolution in dpi
) {
  # If file is provided, open jpeg device
  if (!is.null(file)) {
    jpeg(filename = file, width = width, height = height, res = res)
  }
  
  # Ensure HourUTC is POSIXct
  data$HourUTC <- as.POSIXct(data$HourUTC)
  
  # Extract ISO week and ISO year (weeks start on Monday)
  data$iso_week <- as.integer(strftime(data$HourUTC, "%V"))
  data$iso_year <- as.integer(strftime(data$HourUTC, "%G"))
  
  # Optional filter by ISO year
  if (!is.null(year)) {
    data <- data[data$iso_year == year, ]
  }
  
  # Filter selected ISO week
  df_w <- data[data$iso_week == iso_week, ]
  
  if (nrow(df_w) == 0) {
    if (!is.null(file)) dev.off()
    stop("No data available for the selected ISO week/year.")
  }
  
  # Prepare scales for second plot (zero aligned)
  max_qh   <- max(df_w$Qh, na.rm = TRUE)
  price_lim <- max(abs(df_w$SpotPriceEUR), na.rm = TRUE)
  cost_lim  <- max(abs(df_w$cost_heating), na.rm = TRUE)
  
  # Layout: 2 rows, 1 column
  # Increase right margin for multiple right-side axes
  par(
    mfrow = c(2, 1),
    mar = c(4, 5, 3, 9),
    xpd = NA
  )
  
  # ============================================================
  # GRAPH 1 — TEMPERATURE / OCCUPANCY / COMFORT
  # ============================================================
  
  # Ti (left axis in red)
  plot(
    df_w$HourUTC, df_w$Ti,
    type = "l",
    col = "red",
    lwd = 2,
    xlab = "HourUTC",
    ylab = "",
    ylim = ti_ylim,
    main = paste("ISO week", iso_week,
                 if (!is.null(year)) paste("-", year) else "")
  )
  axis(side = 2, col = "red", col.axis = "red", lwd = 2)
  mtext("Ti (°C)", side = 2, line = 3, col = "red")
  
  # Building occupied (right)
  par(new = TRUE)
  plot(
    df_w$HourUTC, df_w$building_occupied,
    type = "l",
    col = "blue",
    lwd = 2,
    axes = FALSE,
    xlab = "",
    ylab = "",
    ylim = c(-0.5, 1.5)
  )
  axis(side = 4, col = "blue", col.axis = "blue", lwd = 2, line = 0)
  mtext("Building occupied", side = 4, line = 2, col = "blue")
  
  # Building comfort (right, shifted)
  par(new = TRUE)
  plot(
    df_w$HourUTC, df_w$building_comfort,
    type = "l",
    col = "darkgreen",
    lwd = 2,
    axes = FALSE,
    xlab = "",
    ylab = "",
    ylim = c(-1, 2)
  )
  axis(side = 4, col = "darkgreen", col.axis = "darkgreen", lwd = 2, line = 4)
  mtext("Building comfort", side = 4, line = 6, col = "darkgreen")
  
  # ============================================================
  # GRAPH 2 — HEATING INPUT / SPOT PRICE / HEATING COST
  # ============================================================
  
  # Heating Input (left axis, firebrick)
  plot(
    df_w$HourUTC, df_w$Qh,
    type = "l",
    col = "firebrick",
    lwd = 2,
    xlab = "HourUTC",
    ylab = "",
    ylim = c(0, max_qh)
  )
  axis(side = 2, col = "firebrick", col.axis = "firebrick", lwd = 2)
  mtext("Heating Input [kW]", side = 2, line = 3, col = "firebrick")
  abline(h = 0, col = "gray40", lty = 2)
  
  # Spot price (right axis, purple)
  par(new = TRUE)
  plot(
    df_w$HourUTC, df_w$SpotPriceEUR,
    type = "l",
    col = "purple",
    lwd = 2,
    axes = FALSE,
    xlab = "",
    ylab = "",
    ylim = c(-price_lim, price_lim)
  )
  axis(side = 4, col = "purple", col.axis = "purple", lwd = 2, line = 0)
  mtext("Spot price [€/kWh]", side = 4, line = 2, col = "purple")
  
  # Heating cost (right axis, black)
  par(new = TRUE)
  plot(
    df_w$HourUTC, df_w$cost_heating,
    type = "l",
    col = "black",
    lwd = 2,
    axes = FALSE,
    xlab = "",
    ylab = "",
    ylim = c(-cost_lim, cost_lim)
  )
  axis(side = 4, col = "black", col.axis = "black", lwd = 2, line = 4)
  mtext("Heating cost [€/timestep]", side = 4, line = 6, col = "black")
  
  # Close the JPEG device if open
  if (!is.null(file)) {
    dev.off()
  }
}
