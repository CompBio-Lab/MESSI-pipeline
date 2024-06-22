check_long_wide <- function(X) {
  # TODO: NEED to check if X is those of summarized experiment in each
  # Check if rowwise same dim
  first_e <- X[[1]] # Take the first omics out for later use
  #same_row <- all(sapply(X, nrow) == nrow(first_e))
  bioc_format <- all(sapply(X, ncol) == ncol(first_e))
  # If we know same row, then input X must be this:
  # n x p1 ,n x p2, n x pJ where J is number of omics
  # If we know  same col, the this input X should be from bioconductor
  # way of longer format
  if (!bioc_format) {
    message("\nTransposing the omics to bioconductor dim format\n")
    X <- lapply(X, t)
  }
  X <- lapply(X, as.matrix)
  return(X)
}
