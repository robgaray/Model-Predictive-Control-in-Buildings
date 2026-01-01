# -------------------------------------------------------------
# Script: Install_libraries.R
# Side-script to install libraries in a super computer
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------

WD <- getwd()
ruta_librerias <- file.path(WD, "00_Libraries")
.libPaths(c(ruta_librerias, .libPaths()))

required_libraries <- c(
  "readr","dplyr","tidyr",
  "ggplot2","zoo","GA","lubridate","vctrs"
)

if (!file.exists("00_Libraries")) {
  dir.create("00_Libraries")
}

install.packages(required_libraries,
                 lib = ruta_librerias,
                 dependencies = TRUE,
                 repos = "http://cran.us.r-project.org")
