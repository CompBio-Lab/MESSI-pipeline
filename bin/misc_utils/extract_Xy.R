# little helper here
parseY <- function(Y, verbose = FALSE) {
  if (is.null(Y)) {
    stop("The response variable is not found in MAE")
  }
  if (!is.atomic(Y)) {
    stop("The response variable must be an atomic vector")
  }
  
  ## Convert to numeric 0/1
  Y_numeric <- switch(
    class(Y)[1],
    "factor" = as.integer(as.character(Y) %in% c("1", "yes", "y", "true")),
    "character" = as.integer(tolower(Y) %in% c("yes", "y", "1", "true")),
    "logical" = as.integer(Y),
    "integer" = ,
    "numeric" = {
      if (!all(Y %in% c(0, 1, NA))) {
        stop("Numeric Y must contain only 0, 1, and optionally NA")
      }
      as.integer(Y)
    },
    stop("Unsupported type for Y: ", class(Y)[1])
  )
  
  ## Return factor
  labels <- if (verbose) c("no", "yes") else c("0", "1")
  factor(Y_numeric, levels = c(0, 1), labels = labels)
}

# Convert MAE to list of X and Y
extract_Xy <- function(mae, verbose_target=FALSE) {
  # Note need to transpose back to p * n
  # TODO: add check for dimension match
  # COOP LR do not like delayed matrix, so transform it to S3 matrix
  cat("\nConverting delayed matrix to matrix\n")
  # TODO: this part is actually very bad, given MAE expects the file to
  # be saved and laoded in same directory, i.e. if you saved one place, 
  # and loaded elsewhere, then it would fail
  X <- mae@ExperimentList@listData |> lapply(t) |> lapply(as.matrix)
  cat("\nConverting response to binary\n")
  # COOP LR requires 0 <= y <= 1
  # MAE response would be a dataframe?
  # In simulated data this is always atomic, but in real, they are
  # transformed to dataframe first, so need to pull it
  y_temp <- mae$response
  if (is.data.frame(y_temp)) {
    Y <- parseY(y_temp |> dplyr::pull(response), verbose = verbose_target)
  } else {
    Y <- parseY(y_temp, verbose = verbose_target)
  }
  return(list(X=X, Y=Y))
}
