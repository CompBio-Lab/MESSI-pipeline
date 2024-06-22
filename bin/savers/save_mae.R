# mae related
save_mae <- function(object, name, prefix, message, ...) {
  blocks <- object$blocks
  metadata <- object$metadata
  # Check if all matrices have the same number of rows (n)
  same_n <- all(sapply(blocks, nrow) == nrow(blocks[[1]]))
  # Check if all matrices have different numbers of columns (p)
  match_dim <- nrow(metadata) == nrow(blocks[[1]])
  # ---------------------------------------------------------------------
  if (same_n & match_dim) {
    # Need to transpose it to p_i * n for MAE use
    blocks <- lapply(blocks, t)
  } else {
    cat("\nRight format, nothing done\n")
  }
  mae <- MultiAssayExperiment::MultiAssayExperiment(
    experiments = blocks,
    metadata    = metadata
  )
  # Note, the delayed matrix is affecting the subset of metadata
  # so manually add response here
  mae$response <- metadata$response
  # Save to HDF5 format
  MultiAssayExperiment::saveHDF5MultiAssayExperiment(
    mae, dir=paste0(name, "_", "mae_data"), 
    prefix=prefix, 
    replace=TRUE)
  return(mae)
}