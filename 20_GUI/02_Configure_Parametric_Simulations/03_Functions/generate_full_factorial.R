# -------------------------------------------------------------
# Function: generate_full_factorial
# Generates all combinations (full factorial) of parametric
# simulation configurations.
#
# Memory-efficient version: instead of calling expand.grid()
# (which allocates the entire cartesian product at once), this
# function iterates over the parameter lists with nested for
# loops and appends rows in blocks to a pre-allocated list,
# then assembles the final data.frame in a single rbind call.
#
# Arguments:
#   params_list : named list; each element is either:
#     - a numeric vector of values (for min/max/step params), or
#     - an integer vector of selected option codes (for checkbox params)
#   chunk_size  : integer; number of rows to accumulate in each
#                 intermediate chunk before storing (default 50000).
#                 Larger values use more peak memory but are faster.
#   progress_fn : optional function(current_row, total_rows) called
#                 periodically to report progress (default NULL).
#
# Returns a data.frame with one row per combination.
# -------------------------------------------------------------
generate_full_factorial <- function(params_list,
                                    chunk_size  = 50000L,
                                    progress_fn = NULL) {
  
  # --- Validate that all elements are non-empty vectors ------
  for (CONT_001 in names(params_list)) {
    vals <- params_list[[CONT_001]]
    if (length(vals) == 0) {
      stop(sprintf("Parameter '%s' has no values. Select at least one option.", CONT_001))
    }
  }
  
  # --- Compute total number of rows --------------------------
  param_names   <- names(params_list)
  n_params      <- length(param_names)
  lengths_vec   <- vapply(params_list, length, integer(1))
  total_rows    <- prod(as.numeric(lengths_vec))
  
  if (total_rows == 0) {
    stop("No combinations to generate (one or more parameters have zero levels).")
  }
  
  # --- Small case: if total fits comfortably, use expand.grid -
  # Heuristic: 15 columns * 8 bytes * total_rows < 500 MB
  estimated_bytes <- total_rows * n_params * 8
  if (estimated_bytes < 500e6) {
    grid <- do.call(expand.grid, c(params_list, list(stringsAsFactors = FALSE)))
    grid <- grid[, param_names, drop = FALSE]
    rownames(grid) <- NULL
    return(grid)
  }
  
  # --- Large case: iterative generation with nested for loops -
  # Strategy:
  #   1. Pre-allocate a matrix-like list of chunks.
  #   2. Fill a chunk (a pre-allocated matrix of chunk_size rows)
  #      row by row using nested index counters.
  #   3. When the chunk is full, convert it to a data.frame and
  #      store it in the chunks list.
  #   4. After all rows, do.call(rbind, chunks) once.
  # Using a numeric matrix for each chunk is much more memory-
  # friendly than growing a data.frame row by row.
  # ---------------------------------------------------------
  
  # Pre-compute the index vectors for each parameter to avoid
  # repeated list access inside the tight loop.
  param_values <- lapply(params_list, function(x) as.numeric(x))
  
  # Number of chunks we will need
  n_chunks <- ceiling(total_rows / chunk_size)
  chunks   <- vector("list", n_chunks)
  
  # Current position expressed as a vector of indices into each
  # parameter (1-based), initialised to the first combination.
  idx <- rep(1L, n_params)
  
  row_global  <- 0L       # global row counter
  chunk_idx   <- 1L       # which chunk we are filling
  chunk_row   <- 0L       # row counter within the current chunk
  
  # Allocate the first chunk
  current_chunk_size <- min(chunk_size, total_rows)
  mat <- matrix(NA_real_, nrow = current_chunk_size, ncol = n_params)
  
  # --- Main loop: iterate over all combinations ---------------
  # We increment the index vector manually (odometer-style) to
  # avoid creating the full index grid.
  repeat {
    row_global <- row_global + 1L
    chunk_row  <- chunk_row  + 1L
    
    # Write the current combination into the matrix row
    for (CONT_002 in seq_len(n_params)) {
      mat[chunk_row, CONT_002] <- param_values[[CONT_002]][ idx[CONT_002] ]
    }
    
    # --- Report progress (every 10 000 rows) ------------------
    if (!is.null(progress_fn) && (row_global %% 10000L == 0L)) {
      progress_fn(row_global, total_rows)
    }
    
    # --- If chunk is full, store it and allocate a new one ----
    if (chunk_row == current_chunk_size) {
      df_chunk <- as.data.frame(mat, stringsAsFactors = FALSE)
      colnames(df_chunk) <- param_names
      chunks[[chunk_idx]] <- df_chunk
      chunk_idx <- chunk_idx + 1L
      chunk_row <- 0L
      remaining <- total_rows - row_global
      if (remaining > 0) {
        current_chunk_size <- min(chunk_size, remaining)
        mat <- matrix(NA_real_, nrow = current_chunk_size, ncol = n_params)
      }
    }
    
    # --- Check if we are done ---------------------------------
    if (row_global >= total_rows) break
    
    # --- Increment the odometer (rightmost index first) -------
    carry <- TRUE
    for (CONT_003 in n_params:1) {
      if (carry) {
        idx[CONT_003] <- idx[CONT_003] + 1L
        if (idx[CONT_003] > lengths_vec[CONT_003]) {
          idx[CONT_003] <- 1L
          # carry propagates to the next parameter
        } else {
          carry <- FALSE
        }
      }
    }
  } # end repeat
  
  # --- Store last (possibly partial) chunk --------------------
  if (chunk_row > 0L && chunk_row < current_chunk_size) {
    mat <- mat[seq_len(chunk_row), , drop = FALSE]
    df_chunk <- as.data.frame(mat, stringsAsFactors = FALSE)
    colnames(df_chunk) <- param_names
    chunks[[chunk_idx]] <- df_chunk
  }
  
  # --- Assemble final data.frame ------------------------------
  grid <- do.call(rbind, chunks)
  rownames(grid) <- NULL
  
  # --- Report completion --------------------------------------
  if (!is.null(progress_fn)) {
    progress_fn(total_rows, total_rows)
  }
  
  grid
}