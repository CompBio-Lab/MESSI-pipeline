check_common_samples <- function(data) {
  if (length(data$X) == 0L) {
    stop("data$X is empty.")
  }

  sample_names_list <- lapply(data$X, rownames)

  valid_names <- vapply(
    sample_names_list,
    function(ids) {
      !is.null(ids) &&
        length(ids) > 0L &&
        !anyNA(ids) &&
        all(nzchar(ids)) &&
        anyDuplicated(ids) == 0L
    },
    logical(1)
  )

  if (!all(valid_names)) {
    stop("Each modality must have non-empty, unique sample row names.")
  }

  sample_names <- sample_names_list[[1]]

  matched <- vapply(
    sample_names_list,
    function(ids) identical(ids, sample_names),
    logical(1)
  )

  if (!all(matched)) {
    stop("Sample names or their order differ between modalities.")
  }

  if (is.null(data$Y)) {
    stop("data$Y is missing.")
  }

  y_count <- if (is.null(dim(data$Y))) {
    length(data$Y)
  } else {
    nrow(data$Y)
  }

  message("Found ", length(sample_names), " samples in each modality.")
  message("Found ", y_count, " observations in Y.")

  if (length(sample_names) != y_count) {
    stop("Sample count in X does not match observation count in Y.")
  }

  return(sample_names)
}