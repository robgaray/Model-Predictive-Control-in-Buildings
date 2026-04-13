# -------------------------------------------------------------
# Function: write_param_csv
# Writes a parameter CSV preserving a header comment block.
# config_path must be defined in the calling environment.
# -------------------------------------------------------------
write_param_csv <- function(filename, df, header_comment) {
  path <- file.path(config_path, filename)
  con  <- file(path, open = "wt")
  writeLines(header_comment, con)
  write.csv(df, con, row.names = FALSE, quote = FALSE)
  close(con)
}
