# 1. Add calendar variables
add_calendar_vars <- function(df, datetime_col = "HourUTC") {
  df %>%
    mutate(
      hour = hour(.data[[datetime_col]]),
      day_of_week = wday(.data[[datetime_col]],
                         label = TRUE,
                         week_start = 1),
      week_of_year = isoweek(.data[[datetime_col]])
    )
}

# 2. Calculate averages by calendar variable
calc_avg_by_calendar <- function(df, calendar_var, analysis_vars) {
  df %>%
    group_by(.data[[calendar_var]]) %>%
    summarise(across(all_of(analysis_vars), mean, na.rm = TRUE)) %>%
    ungroup()
}

# 3. Base R barplot with custom labels
plot_avg_by_calendar_base <- function(avg_df,
                                      calendar_var,
                                      analysis_var,
                                      col = "steelblue") {
  
  y_label <- switch(
    analysis_var,
    "building_comfort" = "Average Comfort",
    "cost_heating"     = "Average cost [€/timestep]",
    analysis_var
  )
  
  values <- avg_df[[analysis_var]]
  names(values) <- avg_df[[calendar_var]]
  
  barplot(
    values,
    main = paste(y_label, "by", calendar_var),
    xlab = calendar_var,
    ylab = y_label,
    col = col,
    las = 2,
    cex.names = 0.8
  )
}

# 4. Wrapper function with JPG export option
generate_all_calendar_plots <- function(df,
                                        datetime_col = "HourUTC",
                                        calendar_vars = c("hour",
                                                          "day_of_week",
                                                          "week_of_year"),
                                        analysis_vars = c("cost_heating",
                                                          "building_comfort",
                                                          "Ti",
                                                          "air_temperature"),
                                        save_plots = FALSE,
                                        output_dir = "plots",
                                        width = 1200,
                                        height = 800,
                                        res = 150) {
  
  # Create output directory if needed
  if (save_plots && !dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # Create auxiliary dataframe
  aux_df <- add_calendar_vars(df, datetime_col)
  
  # Loop over calendar variables
  for (cal_var in calendar_vars) {
    
    avg_df <- calc_avg_by_calendar(aux_df, cal_var, analysis_vars)
    
    # Loop over analysis variables
    for (an_var in analysis_vars) {
      
      # Visual plot
      # Plot
      plot_avg_by_calendar_base(
        avg_df = avg_df,
        calendar_var = cal_var,
        analysis_var = an_var
      )
      
      # Open JPG device if saving is enabled
      if (save_plots) {
        file_name <- paste0(
          output_dir, "/",
          an_var, "_by_", cal_var, ".jpg"
        )
        
        jpeg(
          filename = file_name,
          width = width,
          height = height,
          res = res
        )
      }
      
      # Plot
      plot_avg_by_calendar_base(
        avg_df = avg_df,
        calendar_var = cal_var,
        analysis_var = an_var
      )
      
      # Close device
      if (save_plots) {
        dev.off()
      }
    }
  }
}