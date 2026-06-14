plot(Main_df$time[2:200], Main_df$Ti[2:200],
     type = "n", col = "red",
     xlab = "Time", ylab = "Ti",
     ylim=c(0,50), main=CONT_003)
points(Main_df$time[2:200], Main_df$Ti_plan[2:200], type = "p", col = "blue")
points(Main_df$time[2:200], Main_df$Ti[2:200], type = "p", col = "red")


points(Main_df$time[2:200], Main_df$STP_heat_plan[2:200], type = "l", col = "green")
points(Main_df$time[2:200], Main_df$STP_cool_plan[2:200], type = "l", col = "green")

points(Main_df$time[2:200], Main_df$STP_heat[2:200], type = "p", col = "black")
points(Main_df$time[2:200], Main_df$STP_cool[2:200], type = "p", col = "black")

points(Main_df$time[2:200], Main_df$Occupancy[2:200]*5, type = "l", col = "black")
