createKeepX <- function(x_list, n_percent = 10, ncomp=2) {
  # For each omics, only get 10% of total features
  # Assume the input list is already after transforming to rows being common
  # samples
  cap <- 100
  if (n_percent > cap) {
    warning("Limited to top 100%, cannot exceed more than original feature count")
    n_percent <- cap
  }
  # Then create the keep x
  keep_list <- lapply(x_list, function(x) {
    # since row now represents samples, col correspond to features
    feat_num <- round(n_percent * ncol(x) / 100 , digits=0)
    # repat the number of features for ncomp times as a vector
    feat_vec <- rep(feat_num, ncomp)
    return(feat_vec)
  })
  # assign to have the matching omics names
  names(keep_list) <- names(x_list)
  return(keep_list)
}