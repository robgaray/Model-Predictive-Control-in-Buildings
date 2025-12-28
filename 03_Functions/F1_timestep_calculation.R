f1_timestep_calculation <- function(df_chunk, set_point_df, parameters) {
  with(parameters,
       {
         # get the hour of the day (0 to 23)
         date_hour <-floor_date(df_chunk$HourUTC[1], unit = "hour")
         
         delta_t<-as.numeric(df_chunk$HourUTC[2]-df_chunk$HourUTC[1])/60
         
         # Retrieve the corresponding data from set_point_df
         df_chunk$set_point_low[2]  <- set_point_df$set_point_heating_low[set_point_df$hour==date_hour]
         df_chunk$set_point_high[2] <- set_point_df$set_point_heating_high[set_point_df$hour==date_hour]
         
         # Previous timestep values
         Ti <- df_chunk$Ti[1]
         Te <- df_chunk$Te[1]
         act_heat<-df_chunk$act_heat[1]
         
         # Current timestep values
         GHI <- df_chunk$GHI[2]
         act_vent <- df_chunk$act_vent[2]
         air_temperature <- df_chunk$air_temperature[2]
         set_point_low <- df_chunk$set_point_low[2]
         set_point_high <- df_chunk$set_point_high[2]
         mean_temp_24h <- df_chunk$mean_temp_24h[2]
         SpotPriceEUR <- df_chunk$SpotPriceEUR[2]
         building_occupied <- df_chunk$building_occupied[2]
           
         
         # Act_heat calculation
         if (Ti < set_point_low) {
              act_heat_new <- 1
              } else if (Ti > set_point_high) {
                act_heat_new <- 0
              } else {
                act_heat_new <- act_heat
              }
         
         # Qh calculation
         Delta_temp <- set_point_high - Ti
         if (act_heat_new ==1){
           if (Delta_temp < AT_hp1) {
             Qh_new <- Q_hp1
           } else if (Delta_temp > AT_hp2) {
             Qh_new <- Q_hp2
           } else {
             Qh_new <- Q_hp1 + (Q_hp2-Q_hp1)*(Delta_temp-AT_hp1)/(AT_hp2-AT_hp1)
           }
         } else {
           Qh_new <- 0
         }

         
         # Rvent calculation
         if (act_vent == 1) {
           Rvent <- Rvent2
           } else if ( mean_temp_24h >= 20) {
             Rvent <- Rvent1
           } else {
             Rvent <- Rvent01
           }
    
    # Shading
    Shading <- ifelse(!is.na(mean_temp_24h) && mean_temp_24h > 20, Shading_0, Shading_1)
    
    # Ti & Te calculations
    Ti_new <- Ti + ((Te - Ti)/Rie + (air_temperature - Ti)/Rvent + (Aw*GHI*Shading/1000) + (Qh_new*act_heat_new)) * (1/Ci) * delta_t
    Te_new <- Te + ((Ti - Te)/Rie + (air_temperature - Te)/Rea + (Ae*GHI/1000)) * (1/Ce) * delta_t
    
    # Calculation of COP
    if (Qh_new < Q_hp1){
      COP<-COP_hp1
    } else if (Qh_new > Q_hp2) {
      COP<-COP_hp2
    } else
    {
      COP <- COP_hp1 + (COP_hp2-COP_hp1)*(Qh_new-Q_hp1)/(Q_hp2-Q_hp1)
    }
    
    # Electricity cost calculation
    elec_heating <- (Qh_new / COP) * delta_t
    elec_cost <- elec_heating * SpotPriceEUR
    
    # Comfort
    comfort <- ifelse(Ti_new > confort_low && Ti_new < confort_high, 1, 0)
    
    reward <- f2_reward_function (building_occupied,elec_cost,comfort,delta_t) 
    
    # Update dataframe
    df_chunk$Ti[2] <- Ti_new
    df_chunk$Te[2] <- Te_new
    df_chunk$Qh[2] <- Qh_new * act_heat_new
    df_chunk$elec_heating[2] <- elec_heating
    df_chunk$cost_heating[2] <- elec_cost
    df_chunk$building_comfort[2] <- comfort
    df_chunk$act_heat[2] <- act_heat_new
    df_chunk$reward[2] <- reward
    
    return(df_chunk)
  })
}
