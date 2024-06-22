# little helper here
parseY <- function(Y) {
  lev <- levels(Y)
  if (!is.atomic(Y)) stop("The response variable is not a vector, might be a dataframe")
  if (is.null(Y)) stop("The response variable is not found in MAE")
  if (is.character(Y) || is.character(lev)) {
    Y <- (ifelse(tolower(Y) == "yes", 1,0))
  }
  # TDOD: might not be able to convert as factor anyways
  #Y <- as.factor(Y)
  return(Y)
}

# Convert MAE to list of X and Y
extract_Xy <- function(mae) {
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
    Y <- parseY(y_temp |> dplyr::pull(response))
  } else {
    Y <- parseY(y_temp)
  }
  return(list(X=X, Y=Y))
}
