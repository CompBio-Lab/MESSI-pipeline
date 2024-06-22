# Check if matched sample names, then return those
check_common_samples <- function(data) {
  sample_names <- lapply(data$X, rownames) |> unlist() |> unique()
  matched <- length(sample_names) == length(data$Y)
  if (matched) {
    return(sample_names)
  } else {
    stop("Failed to find match samples, check!")
  }
}
