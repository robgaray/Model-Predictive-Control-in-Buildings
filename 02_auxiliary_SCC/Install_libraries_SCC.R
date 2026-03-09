# -------------------------------------------------------------
# Script: Install_libraries_SCC.R
# Installs required R libraries to a local directory for
# execution in a super computer (SCC)
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------

rm(list = ls())

WD <- getwd()

# Paths
config_path   <- file.path(WD, "01_Simulation", "02_config_files")
library_file  <- file.path(config_path, "libraries.txt")
library_path  <- file.path(WD, "00_Libraries")

# Create library directory FIRST
if (!dir.exists(library_path)) {
  dir.create(library_path, recursive = TRUE)
}

# Make it the first library path
.libPaths(c(library_path, .libPaths()))

cat("Library path:\n")
print(.libPaths())

# Read package list
raw_lines <- readLines(library_file)
raw_lines <- raw_lines[!grepl("^#", raw_lines)]
raw_lines <- raw_lines[nchar(raw_lines) > 0]
required_libraries <- raw_lines

# Install packages
install.packages(
  required_libraries,
  lib = library_path,
  dependencies = TRUE,
  repos = "https://cloud.r-project.org"
)

# Validate installation (CRITICAL in SCC)
cat("\nChecking installed packages...\n")

failed <- c()

for (pkg in required_libraries) {
  ok <- suppressWarnings(
    suppressMessages(
      try(library(pkg, lib.loc = library_path, character.only = TRUE), silent = TRUE)
    )
  )

  if (inherits(ok, "try-error")) {
    failed <- c(failed, pkg)
  }
}

if (length(failed) > 0) {
  cat("\nThe following packages FAILED to load:\n")
  print(failed)
  stop("Some libraries did not install correctly")
} else {
  cat("\nAll libraries installed and loaded successfully\n")
}
