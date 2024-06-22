# Use this function instead to save MAE 
# We have checked formats already
save_mae <- function(object, dataset_name, prefix) {
  # Extract from the list with blocks and metadata
  blocks <- object$blocks
  metadata <- data.frame(response = object$response)
  # Construct new mae
  # TODO: Fix this or make it more robust
  # NOTE: this metadata is solely the response, others are discard
  mae <- MultiAssayExperiment::MultiAssayExperiment(
    experiments = blocks,
    metadata    = metadata
  )
  # Note, the delayed matrix is affecting the subset of metadata
  # so manually add response here
  mae$response <- metadata
  # Save to HDF5 format
  # Hardcode this prefix
  MultiAssayExperiment::saveHDF5MultiAssayExperiment(
    x=mae, 
    dir=paste0(dataset_name, "_", "mae_data"), 
    prefix=prefix,
    replace=TRUE
  )
  return(mae)
}




