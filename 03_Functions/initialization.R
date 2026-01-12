initialization <- function(library_file,
                           functions_path,
                           lib_path = NULL) {
  # Loading libraries
  {
    raw_lines <- readLines(library_file)
    raw_lines <- raw_lines[!grepl("^#", raw_lines)]  # remove comments
    raw_lines <- raw_lines[nchar(raw_lines) > 0]     # remove empty lines
    
    required_libraries <- raw_lines
    
    for (pkg in required_libraries) {
      if (is.null(lib_path)) {
        library(pkg, character.only = TRUE)
      } else {
        library(pkg, lib.loc = lib_path, character.only = TRUE)
      }
    }
  }
  
  cat("libraries loaded\n")
  
  # Load functions
  {
    files.source <- list.files(functions_path)
    for (i in seq_along(files.source)) {
      source(file.path(functions_path, files.source[i]))
    }
    rm(files.source, i)
  }
  
  cat("functions loaded\n")
}
