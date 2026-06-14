# -------------------------------------------------------------
# Script: Install_libraries.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Side-script to install required R libraries in a local directory
# for use on supercomputer cluster (SCC) environments.
# Libraries are installed to the local directory ./00_Libraries
# so that they are available without system-level permissions.
# The list of required packages is read from the same 01_Libraries.txt
# file used by the main simulation.
#
# The script first checks which packages are already installed
# and only installs those that are missing, avoiding redundant
# re-installation on every run.
# -------------------------------------------------------------

rm(list = ls())

WD <- getwd()

# Paths
config_path  <- file.path(WD, "30_Simulation", "02_Config")
library_file <- file.path(config_path, "01_Libraries.txt")
library_path <- file.path(WD, "00_Libraries")

# Create library directory if it does not exist
if (!dir.exists(library_path)) {
  dir.create(library_path, recursive = TRUE)
}

# Place local library first in the search path before any package is loaded.
# This is required on SCC environments where the R module may pre-load
# outdated package versions (e.g. cli 3.3.0) that conflict with
# dependencies of packages such as tidyr (which requires cli >= 3.6.1).
.libPaths(c(library_path, .libPaths()))

cat("Library path:\n")
print(.libPaths())

# Read package list (skip comment lines and blank lines)
raw_lines <- readLines(library_file)
raw_lines <- raw_lines[!grepl("^#", raw_lines)]
raw_lines <- raw_lines[nchar(raw_lines) > 0]
required_libraries <- raw_lines
rm(raw_lines)

cat("\nRequired packages:\n")
print(required_libraries)

# -------------------------------------------------------------
# 1. Check which packages are already installed
# Only install those that are not yet available in library_path
# or any other path on the search path.
# 
# To avoid problems, we only check the local library_path for already installed packages,
# -------------------------------------------------------------
already_installed <- installed.packages(lib.loc = library_path)[, "Package"]
to_install        <- setdiff(required_libraries, already_installed)
rm(already_installed)

if (length(to_install) == 0) {
  cat("\nAll required packages are already installed. Skipping install.\n")
} else {
  cat("\nPackages to install (not yet present):\n")
  print(to_install)
  
  # Install only missing packages to local library directory
  install.packages(
    to_install,
    lib          = library_path,
    dependencies = TRUE,
    repos        = "https://cloud.r-project.org"
  )
}
rm(to_install)

# Validate that all packages installed correctly
cat("\nChecking installed packages...\n")

failed <- c()

for (CONT_001 in required_libraries) {
  ok <- suppressWarnings(
    suppressMessages(
      try(library(CONT_001, lib.loc = library_path, character.only = TRUE), silent = TRUE)
    )
  )
  
  if (inherits(ok, "try-error")) {
    failed <- c(failed, CONT_001)
  }
}

if (length(failed) > 0) {
  cat("\nThe following packages FAILED to load:\n")
  print(failed)
  stop("Some libraries did not install correctly")
} else {
  cat("\nAll libraries installed and loaded successfully\n")
}
