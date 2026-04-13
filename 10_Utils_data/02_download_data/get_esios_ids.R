# -------------------------------------------------------------
# Script: get_esios_ids.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This script retrieves the full catalogue of indicators
# available through the ESIOS API (Red Eléctrica de España
# Information System) and saves the listing to a CSV and a
# Markdown file.
# It queries the ESIOS REST API /indicators endpoint to download
# the complete list of available data series (IDs and names).
# Use the catalogue to identify the indicator IDs you need
# before configuring download_data.R.
# -------------------------------------------------------------
# Usage
#   1. Place your ESIOS API token in 02_Config/esios_api_token.txt
#      (request a token at esios.ree.es).
#   2. Run from the repository root:
#        Rscript 10_Utils_data/02_download_data/get_esios_ids.R
#      Or source from an interactive R session with the repo root
#      as the working directory.
# -------------------------------------------------------------
# Output files (in 10_Utils_data/02_download_data/90_Output/)
#   esios_indicators.csv : full indicator catalogue (id, name, ...)
#   esios_indicators.md  : human-readable Markdown catalogue
# -------------------------------------------------------------

# ---- Initialization ----
{
  rm(list = ls())
  gc()
  options(stringsAsFactors = FALSE)
}

# ---- Required libraries ----
library(httr)
library(jsonlite)

# ----------------------------------------------------------------
# Helper: convert HTML description to plain readable text
# ----------------------------------------------------------------
# Replaces block-level tags with newlines, strips remaining tags,
# decodes common HTML entities (including Spanish accented chars),
# and collapses redundant blank lines.
html_to_text <- function(html) {
  if (is.na(html) || !nzchar(html)) return("")

  # Block-level tags → newline
  text <- gsub("<\\s*/?(p|br|div|li|tr|h[1-6])(\\s[^>]*)?>",
               "\n", html, perl = TRUE, ignore.case = TRUE)

  # Strip all remaining HTML tags
  text <- gsub("<[^>]+>", "", text, perl = TRUE)

  # Decode HTML entities
  entities <- c(
    "&amp;"   , "&lt;"  , "&gt;"  , "&quot;" , "&apos;" ,
    "&aacute;", "&eacute;", "&iacute;", "&oacute;", "&uacute;",
    "&Aacute;", "&Eacute;", "&Iacute;", "&Oacute;", "&Uacute;",
    "&ntilde;", "&Ntilde;",
    "&auml;"  , "&euml;" , "&iuml;" , "&ouml;" , "&uuml;"  ,
    "&Auml;"  , "&Euml;" , "&Iuml;" , "&Ouml;" , "&Uuml;"  ,
    "&agrave;", "&egrave;", "&igrave;", "&ograve;", "&ugrave;",
    "&ccedil;", "&Ccedil;",
    "&nbsp;"  , "&mdash;", "&ndash;", "&laquo;", "&raquo;"
  )
  replacements <- c(
    "&", "<", ">", "\"", "'",
    "\u00e1", "\u00e9", "\u00ed", "\u00f3", "\u00fa",
    "\u00c1", "\u00c9", "\u00cd", "\u00d3", "\u00da",
    "\u00f1", "\u00d1",
    "\u00e4", "\u00eb", "\u00ef", "\u00f6", "\u00fc",
    "\u00c4", "\u00cb", "\u00cf", "\u00d6", "\u00dc",
    "\u00e0", "\u00e8", "\u00ec", "\u00f2", "\u00f9",
    "\u00e7", "\u00c7",
    " ", "\u2014", "\u2013", "\u00ab", "\u00bb"
  )
  for (CONT_001 in seq_along(entities)) {
    text <- gsub(entities[CONT_001], replacements[CONT_001], text, fixed = TRUE)
  }

  # Collapse runs of blank lines to a single blank line, trim overall
  text <- gsub("(\n\\s*){3,}", "\n\n", text, perl = TRUE)
  text <- trimws(text)
  text
}

# ----------------------------------------------------------------
# 0. Paths
# ----------------------------------------------------------------
if (dir.exists("10_Utils_data/02_download_data")) {
  base_dir <- "10_Utils_data/02_download_data"
} else if (dir.exists("02_Config")) {
  base_dir <- "."
} else {
  stop("Cannot locate 10_Utils_data/02_download_data directory. ",
       "Run this script from the repository root or from ",
       "10_Utils_data/02_download_data/.")
}

config_dir <- file.path(base_dir, "02_Config")
output_dir <- file.path(base_dir, "90_Output")

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

cat("Config directory: ", config_dir,  "\n")
cat("Output directory:", output_dir, "\n")

# ----------------------------------------------------------------
# 1. Read API token from config file
# ----------------------------------------------------------------
# Lines starting with '#' and blank lines are ignored.
token_file <- file.path(config_dir, "esios_api_token.txt")
if (file.exists(token_file)) {
  token_lines <- readLines(token_file, warn = FALSE)
  token_lines <- token_lines[!grepl("^\\s*#", token_lines)]
  token_lines <- trimws(token_lines)
  token_lines <- token_lines[nchar(token_lines) > 0]
  token <- if (length(token_lines) > 0) token_lines[1] else ""
} else {
  token <- Sys.getenv("ESIOS_API_TOKEN", unset = "")
  if (nchar(token) == 0) {
    warning(paste(
      "Config file not found:", token_file,
      "\nFalling back to ESIOS_API_TOKEN environment variable (also not set)."
    ))
  }
}

if (nchar(trimws(token)) == 0 || grepl("YOUR_ESIOS_API_TOKEN_HERE", token)) {
  stop(paste(
    "ESIOS API token is not set.",
    "Edit 02_Config/esios_api_token.txt and replace the placeholder with",
    "your actual token (request at https://www.esios.ree.es/en/access-my-esios)."
  ))
}

# ----------------------------------------------------------------
# 2. Request indicator catalogue
# ----------------------------------------------------------------
url <- "https://api.esios.ree.es/indicators"

cat("Connecting to ESIOS API to retrieve indicator catalogue...\n")

response <- tryCatch(
  GET(
    url = url,
    add_headers(
      `Accept`        = "application/json; application/vnd.esios-api-v1+json",
      `x-api-key`     = token,
      `Authorization` = paste0("Token token=\"", token, "\"")
    )
  ),
  error = function(e) {
    message("HTTP request failed: ", conditionMessage(e))
    return(NULL)
  }
)

if (is.null(response)) stop("Request to ESIOS API failed.")

# ----------------------------------------------------------------
# 3. Process response and save output
# ----------------------------------------------------------------
if (status_code(response) == 200) {
  cat("Connection successful. Processing indicator catalogue...\n")

  # Parse JSON response
  raw_content <- content(response, as = "text", encoding = "UTF-8")
  parsed_json  <- fromJSON(raw_content)

  # The indicator list is returned inside the 'indicators' key
  indicators <- parsed_json$indicators

  cat("Total indicators found:", nrow(indicators), "\n\n")

  # Print the first 10 entries (id and name) as a quick preview
  cat("First 10 indicators (id / name):\n")
  print(head(indicators[, c("id", "name")], 10))

  # TIP: To search for a keyword within the catalogue use:
  # matches <- indicators[grepl("PVPC", indicators$name, ignore.case = TRUE), ]
  # View(matches)

  # Save catalogue to CSV
  # The description field is cleaned (HTML stripped, entities decoded,
  # extra blank lines removed) so that every row occupies a single line.
  indicators_csv <- indicators
  indicators_csv$description <- vapply(
    indicators_csv$description, html_to_text, character(1)
  )
  indicators_csv$description <- gsub("[\r\n]+", " ", indicators_csv$description)
  indicators_csv$description <- trimws(indicators_csv$description)
  output_csv <- file.path(output_dir, "esios_indicators.csv")
  write.csv(
    indicators_csv[, c("name", "description", "short_name", "id")],
    output_csv, row.names = FALSE, fileEncoding = "UTF-8"
  )
  cat("\nSaved indicator catalogue to:", output_csv, "\n")

  # Save Markdown catalogue
  # Format per indicator:
  #   # short_name (id)
  #   name
  #
  #   description (plain text, HTML decoded)
  output_md <- file.path(output_dir, "esios_indicators.md")
  has_short <- !is.null(indicators$short_name)
  has_desc  <- !is.null(indicators$description)
  md_lines <- character(0)
  for (CONT_002 in seq_len(nrow(indicators))) {
    short    <- if (has_short) indicators$short_name[CONT_002] else ""
    id_val   <- indicators$id[CONT_002]
    name_val <- indicators$name[CONT_002]
    desc_val <- html_to_text(if (has_desc) indicators$description[CONT_002] else "")
    md_lines <- c(
      md_lines,
      paste0("# ", trimws(short), " (", id_val, ")"),
      trimws(name_val),
      "",
      desc_val,
      "",
      "---",
      ""
    )
  }
  writeLines(enc2utf8(md_lines), con = output_md, useBytes = TRUE)
  cat("Saved Markdown catalogue to:  ", output_md, "\n")

} else {
  # Report HTTP error details
  cat("Connection failed. HTTP status code:", status_code(response), "\n")
  cat("Response body:", content(response, as = "text", encoding = "UTF-8"), "\n")
}
