f1_timestep_calculation <- function(df_chunk, set_point_df, parameters) {
  with(parameters,
       {
         # get the hour of the day (0 to 23)
         date_hour <-floor_date(df_chunk$HourUTC[1], unit = "hour")
         
         delta_t<-as.numeric(df_chunk$HourUTC[2]-df_chunk$HourUTC[1])/60
         
         # Retrieve the corresponding data from set_point_df
         df_chunk$set_point_heating_low[2]  <- set_point_df$set_point_heating_low[set_point_df$hour==date_hour]
         df_chunk$set_point_heating_high[2] <- set_point_df$set_point_heating_high[set_point_df$hour==date_hour]
         
         df_chunk$set_point_cooling_low[2]  <- set_point_df$set_point_cooling_low[set_point_df$hour==date_hour]
         df_chunk$set_point_cooling_high[2] <- set_point_df$set_point_cooling_high[set_point_df$hour==date_hour]
         
         
         # Previous timestep values
         Ti <- df_chunk$Ti[1]
         Te <- df_chunk$Te[1]
         act_heat<-df_chunk$act_heat[1]
         act_cool<-df_chunk$act_cool[1]
         
         # Current timestep values
         GHI <- df_chunk$GHI[2]
         act_vent <- df_chunk$act_vent[2]
         air_temperature <- df_chunk$air_temperature[2]
         set_point_heating_low  <- df_chunk$set_point_heating_low[2]
         set_point_heating_high <- df_chunk$set_point_heating_high[2]
         set_point_cooling_low  <- df_chunk$set_point_cooling_low[2]
         set_point_cooling_high <- df_chunk$set_point_cooling_high[2]
         
         
         mean_temp_24h <- df_chunk$mean_temp_24h[2]
         SpotPriceEUR <- df_chunk$SpotPriceEUR[2]
         building_occupied <- df_chunk$building_occupied[2]
           
         
         # Act_heat calculation
         if (Ti < set_point_heating_low) {
              act_heat_new <- 1
              } else if (Ti > set_point_heating_high) {
                act_heat_new <- 0
              } else {
                act_heat_new <- act_heat
              }
         
         # Act_cool calculation
         if (act_heat_new==1){
           act_cool_new <-0
           } else if (Ti > set_point_cooling_high) {
             act_cool_new <- 1
           } else if (Ti < set_point_cooling_low) {
             act_cool_new <- 0
           } else {
             act_cool_new <- act_cool
           }
         
         # Qh calculation
         Delta_temp_h <- set_point_heating_high - Ti
         if (act_heat_new ==1){
           if (Delta_temp_h < AT_hp_heat_1) {
             Qh_new <- Q_hp_heat_1
           } else if (Delta_temp_h > AT_hp_heat_2) {
             Qh_new <- Q_hp_heat_2
           } else {
             Qh_new <- Q_hp_heat_1 + (Q_hp_heat_2-Q_hp_heat_1)*(Delta_temp_h-AT_hp_heat_1)/(AT_hp_heat_2-AT_hp_heat_1)
           }
         } else {
           Qh_new <- 0
         }
         
         # Qc calculation
         if (act_cool==1){
           Qc_new <- Q_hp_cool
         }else{
           Qc_new <- 0
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
    Ti_new <- Ti + ((Te - Ti)/Rie + (air_temperature - Ti)/Rvent + (Aw*GHI*Shading/1000) + (Qh_new - Qc_new)) * (1/Ci) * delta_t
    Te_new <- Te + ((Ti - Te)/Rie + (air_temperature - Te)/Rea + (Ae*GHI/1000)) * (1/Ce) * delta_t
    
    # Calculation of COP for heating
    COP_heat<-COP_hp_heat_1_coef1 + COP_hp_heat_1_coef2*air_temperature + COP_hp_heat_1_coef3*Tsup_hp_heat
    
    # Electricity cost calculation
    elec_heating <- (min(Qh_new, Q_hp_heat_1) * COP_heat + max(Qh_new-Q_hp_heat_1, 0)) * delta_t
    elec_cooling <- Qc_new/COP_hp_cool
    elec_total <- elec_heating + elec_cooling
    elec_cost <- elec_total * SpotPriceEUR
    
    # Comfort
    comfort <- ifelse(Ti_new > confort_low && Ti_new < confort_high, 1, 0)
    
    reward <- f2_reward_function (building_occupied,elec_cost,comfort,delta_t) 
    
    # Update dataframe
    df_chunk$Ti[2] <- Ti_new
    df_chunk$Te[2] <- Te_new
    df_chunk$Qh[2] <- Qh_new
    df_chunk$Qc[2] <- Qc_new
    df_chunk$elec_heating[2] <- elec_heating
    df_chunk$elec_cooling[2] <- elec_cooling
    df_chunk$elec_total[2] <- elec_total
    df_chunk$elec_cost[2] <- elec_cost
    df_chunk$building_comfort[2] <- comfort
    df_chunk$act_heat[2] <- act_heat_new
    df_chunk$act_cool[2] <- act_cool_new
    df_chunk$reward[2] <- reward
    
    return(df_chunk)
  })
}
