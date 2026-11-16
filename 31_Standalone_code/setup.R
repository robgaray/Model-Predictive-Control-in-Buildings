# -------------------------------------------------------------
# Script: setup.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Prepares a computer that only has R installed to run the standalone
# market script. It is run once, before the first call. Running it
# again does no harm: it only installs what is missing.
# The script needs two things that a fresh R installation lacks:
#   - The R packages listed in
#     02_Config/00_Inner_parameters/00_Libraries.txt.
#   - A C++ compiler, because the script compiles the simulation
#     loop of the building (05_Models/01_Building/03_1_Functions_Cpp/)
#     every time it starts.
# On Windows the compiler is Rtools, which this script downloads and
# installs on its own. On macOS and Linux installing a compiler needs
# administrator rights, so the script only says how to do it.
# It ends with a clear message. When run with Rscript, the exit
# status is 0 if everything is ready and 1 otherwise.
# -------------------------------------------------------------
# Inputs
#   02_Config/00_Inner_parameters/00_Libraries.txt: R packages.
#   02_Config/00_Inner_parameters/02_Setup_parameters.csv: where to
#   download from, and how long a download may take.
#   02_Config/00_Inner_parameters/04_Rtools_versions.csv: the Rtools
#   release that each version of R needs (Windows only).
# -------------------------------------------------------------
# Outputs
#   None in this folder. It installs:
#     - the missing R packages, in the first R library folder where
#       the user can write;
#     - on Windows, Rtools, if no C++ file can be compiled.
#   Messages on the console.
# -------------------------------------------------------------
# Code outline
# 1. Folder of the script and configuration
# 2. Library folder
# 3. R packages
# 4. C++ compiler
#    4.1. Compilation check
#    4.2. Rtools (Windows)
#    4.3. Result
# -------------------------------------------------------------
# Usage instructions
# From a console, in any folder:
#   Rscript 31_Standalone_code/setup.R
# Or from R:
#   source("31_Standalone_code/setup.R")
# Run it in a new R session, before any package of the script is
# loaded: on Windows a package that is in use cannot be replaced.
# -------------------------------------------------------------

# -------------------------------------------------------------
# 1. Folder of the script and configuration
# -------------------------------------------------------------
# The folder of this script is found whether it is run with Rscript
# or sourced. Every configuration value is read and checked before
# anything is installed.
# -------------------------------------------------------------
{
  source_files    <- unlist(lapply(sys.frames(), function(frame) frame$ofile))
  script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(source_files) > 0) {
    standalone_path <- dirname(normalizePath(source_files[length(source_files)]))
  } else if (length(script_argument) > 0) {
    standalone_path <- dirname(normalizePath(sub("^--file=", "", script_argument[1])))
  } else {
    stop("Run this script with Rscript or source(), so that it can find its own folder")
  }

  inner_path <- file.path(standalone_path, "02_Config", "00_Inner_parameters")
  paths      <- list(
    library_file = file.path(inner_path, "00_Libraries.txt"),
    setup_file   = file.path(inner_path, "02_Setup_parameters.csv"),
    rtools_file  = file.path(inner_path, "04_Rtools_versions.csv")
  )

  missing_files <- unlist(paths)[!file.exists(unlist(paths))]
  if (length(missing_files) > 0) {
    stop("Missing configuration files:\n", paste(missing_files, collapse = "\n"))
  }

  # R packages: one name per line
  library_lines <- readLines(paths$library_file, warn = FALSE)
  library_lines <- trimws(library_lines[!grepl("^#", library_lines)])
  library_lines <- library_lines[nchar(library_lines) > 0]
  if (length(library_lines) == 0 ||
      any(!grepl("^[A-Za-z][A-Za-z0-9.]*$", library_lines))) {
    stop("00_Libraries.txt must list one valid R package name per line")
  }

  # Setup parameters: parameter, value, unit
  setup_lines <- readLines(paths$setup_file, warn = FALSE)
  setup_lines <- setup_lines[!grepl("^#", setup_lines) & nchar(trimws(setup_lines)) > 0]
  setup_table <- read.csv(text = setup_lines, stringsAsFactors = FALSE, strip.white = TRUE)
  setup       <- as.list(setup_table$value)
  names(setup) <- setup_table$parameter

  required_parameters <- c("cran_repository", "rtools_page",
                           "rtools_install_root", "download_timeout")
  missing_parameters  <- setdiff(required_parameters, names(setup))
  if (length(missing_parameters) > 0) {
    stop("02_Setup_parameters.csv is missing: ", paste(missing_parameters, collapse = ", "))
  }
  if (!grepl("^https?://", setup$cran_repository) || !grepl("^https?://", setup$rtools_page)) {
    stop("cran_repository and rtools_page must be web addresses (http or https)")
  }
  setup$download_timeout <- suppressWarnings(as.numeric(setup$download_timeout))
  if (is.na(setup$download_timeout) || setup$download_timeout <= 0) {
    stop("download_timeout must be a positive number of seconds")
  }

  # Rtools releases: header, units row, then one row per release
  rtools_lines    <- readLines(paths$rtools_file, warn = FALSE)
  rtools_lines    <- rtools_lines[!grepl("^#", rtools_lines) & nchar(trimws(rtools_lines)) > 0]
  rtools_versions <- read.csv(text = rtools_lines[-2], stringsAsFactors = FALSE,
                              strip.white = TRUE, colClasses = "character")
  rtools_from     <- tryCatch(package_version(rtools_versions$r_version_from),
                              error = function(e) NULL)
  if (nrow(rtools_versions) == 0 || is.null(rtools_from) ||
      any(!grepl("^rtools[0-9]+$", rtools_versions$rtools_folder))) {
    stop("04_Rtools_versions.csv must hold rows of an R version (e.g. 4.5.0) ",
         "and an Rtools folder (e.g. rtools45)")
  }

  cat("Standalone market script setup\n")
  cat("  Folder:", standalone_path, "\n")
  cat("  R     :", R.version.string, "\n")

  rm(list = c("source_files", "script_argument", "inner_path", "missing_files",
              "setup_lines", "setup_table", "required_parameters",
              "missing_parameters", "rtools_lines"))
}

# -------------------------------------------------------------
# 2. Library folder
# -------------------------------------------------------------
# Packages go to the first R library folder. When the user cannot
# write there (R installed for all users, without administrator
# rights), they go to the personal library folder of the user,
# which R reads on its own in every later session once it exists.
# -------------------------------------------------------------
{
  library_folder <- .libPaths()[1]
  if (file.access(library_folder, 2) != 0) {
    library_folder <- path.expand(Sys.getenv("R_LIBS_USER"))
    dir.create(library_folder, recursive = TRUE, showWarnings = FALSE)
    if (!dir.exists(library_folder) || file.access(library_folder, 2) != 0) {
      stop("No R library folder where packages can be installed. ",
           "Tried ", .libPaths()[1], " and ", library_folder)
    }
    .libPaths(c(library_folder, .libPaths()))
  }
  cat("  Packages are installed in:", library_folder, "\n")
}

# -------------------------------------------------------------
# 3. R packages
# -------------------------------------------------------------
# Only missing packages are installed, together with the packages
# they depend on. On Windows and macOS, ready-made binary packages
# are used, so that no package has to be compiled.
# -------------------------------------------------------------
{
  options(timeout = max(getOption("timeout"), setup$download_timeout))
  if (.Platform$OS.type == "windows" || Sys.info()[["sysname"]] == "Darwin") {
    options(install.packages.compile.from.source = "never")
  }

  missing_packages <- library_lines[
    !vapply(library_lines, requireNamespace, logical(1), quietly = TRUE)
  ]

  if (length(missing_packages) > 0) {
    cat("  Installing R packages:", paste(missing_packages, collapse = ", "), "\n")

    # install.packages is called to download and install the missing
    # packages and the packages they depend on.
    install.packages(missing_packages,
                     lib   = library_folder,
                     repos = setup$cran_repository,
                     Ncpus = max(1, parallel::detectCores() - 1))
  }

  still_missing <- library_lines[
    !vapply(library_lines, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(still_missing) > 0) {
    stop("These R packages could not be installed: ",
         paste(still_missing, collapse = ", "),
         ". Read the messages of install.packages() above.")
  }
  cat("  R packages ready:", paste(library_lines, collapse = ", "), "\n")

  rm(list = c("missing_packages", "still_missing"))
}

# -------------------------------------------------------------
# 4. C++ compiler
# -------------------------------------------------------------
# The script compiles its C++ module with Rcpp each time it starts.
# The surest check of the compiler is to compile something.
# -------------------------------------------------------------

# -------------------------------------------------------------
# 4.1. Compilation check
# -------------------------------------------------------------
{
  compiles <- function() {
    check_env <- new.env()
    tryCatch(
      {
        # Rcpp::cppFunction is called to compile a one-line C++
        # function and confirm that it runs.
        Rcpp::cppFunction("int setup_check(int x) { return x + 1; }", env = check_env)
        identical(check_env$setup_check(1L), 2L)
      },
      error = function(e) {
        cat("  C++ compilation failed:", conditionMessage(e), "\n")
        FALSE
      }
    )
  }

  cat("  Checking the C++ compiler (this takes a few seconds)\n")
  compiler_ready <- compiles()
}

# -------------------------------------------------------------
# 4.2. Rtools (Windows)
# -------------------------------------------------------------
# On Windows, R compiles with Rtools. Each version of R needs its own
# Rtools release (04_Rtools_versions.csv). The installer is taken
# from the download page of that release and run without questions,
# in the default folder, where R finds it on its own in every later
# session. Windows may still ask for permission to install.
# -------------------------------------------------------------
{
  if (!compiler_ready && .Platform$OS.type == "windows") {
    usable <- which(rtools_from <= getRversion())
    if (length(usable) == 0) {
      stop("R ", getRversion(), " is older than every Rtools release in ",
           "04_Rtools_versions.csv. Install a newer version of R.")
    }
    rtools_folder <- rtools_versions$rtools_folder[usable[which.max(rtools_from[usable])]]
    arch_tag      <- if (R.version$arch == "aarch64") "aarch64-" else ""
    page_url      <- paste(setup$rtools_page, rtools_folder, "rtools.html", sep = "/")

    page           <- paste(readLines(page_url, warn = FALSE), collapse = "\n")
    installer_name <- regmatches(page, regexpr(paste0(rtools_folder, "-", arch_tag,
                                                      "[0-9]+-[0-9]+\\.exe"), page))
    if (length(installer_name) == 0) {
      stop("No Rtools installer found on ", page_url,
           ". Download and install ", rtools_folder, " by hand from that page.")
    }

    installer_url  <- paste(setup$rtools_page, rtools_folder, "files", installer_name, sep = "/")
    installer_file <- file.path(tempdir(), installer_name)
    rtools_home    <- paste0(sub("[/\\\\]+$", "", setup$rtools_install_root), "/", rtools_folder)

    cat("  Downloading", installer_url, "\n")
    download.file(installer_url, installer_file, mode = "wb")

    cat("  Installing", rtools_folder, "in", rtools_home, "(this takes a few minutes)\n")
    # The Rtools installer is run silently, in the default folder.
    install_status <- system2(installer_file,
                              c("/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-",
                                paste0("/DIR=", shQuote(normalizePath(rtools_home, mustWork = FALSE)))))
    unlink(installer_file)
    if (install_status != 0) {
      stop("The Rtools installer ended with status ", install_status,
           ". Download and install ", rtools_folder, " by hand from ", page_url)
    }

    # This R session started before Rtools existed, so it is told
    # where to find it. Later sessions find it on their own.
    Sys.setenv(PATH = paste(normalizePath(file.path(rtools_home, "usr", "bin")),
                            Sys.getenv("PATH"), sep = ";"))
    do.call(Sys.setenv, stats::setNames(list(rtools_home),
                                        paste0(toupper(rtools_folder), "_HOME")))

    compiler_ready <- compiles()

    rm(list = c("usable", "rtools_folder", "arch_tag", "page_url", "page",
                "installer_name", "installer_url", "installer_file",
                "rtools_home", "install_status"))
  }
}

# -------------------------------------------------------------
# 4.3. Result
# -------------------------------------------------------------
{
  if (!compiler_ready) {
    sysname <- Sys.info()[["sysname"]]
    advice  <- if (sysname == "Darwin") {
      "Install the Xcode command line tools: run 'xcode-select --install' in a Terminal."
    } else if (sysname == "Linux") {
      paste("Install a C++ compiler with the package manager, for example",
            "'sudo apt install build-essential' (Debian, Ubuntu) or",
            "'sudo dnf install gcc-c++ make' (Fedora).")
    } else {
      "Install the Rtools release for this version of R from the Rtools page of CRAN."
    }
    stop("No working C++ compiler. ", advice, " Then run setup.R again.")
  }

  cat("  C++ compiler ready\n")
  cat("Setup complete: the standalone market script can be called.\n")

  rm(list = c("compiles", "compiler_ready", "library_lines", "library_folder",
              "setup", "rtools_versions", "rtools_from", "paths",
              "standalone_path"))
}
