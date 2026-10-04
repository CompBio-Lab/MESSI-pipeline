# Use this function instead to save MAE 
# We have checked formats already
save_mae <- function(object, dataset_name, prefix, outcome_type="classification") {
  # Extract from the list with blocks and metadata
  blocks <- object$blocks

  if (outcome_type == "classification") {
    # For classification, we only need the response column
    metadata <- data.frame(response = object$y)
  } else if (outcome_type == "survival") {
    # For survival, we need both time and status columns
    # y here would be df for survival
    # So it already contains the df
    metadata <- data.frame(response = object$y$response,
                           time = object$y$time,
                           status = object$y$status)
    message("\nHead of time: ", head(metadata$time))
    message("\nHead of status: ", head(metadata$status))

  } else {
    stop("Unsupported outcome_type: ", outcome_type,
         ". Expected 'classification' or 'survival'.",
         call. = FALSE)
  }

  # Lastly assign the sample names to rownames of colData
  rownames(metadata) <- colnames(object$blocks[[1]]) # Note, this assumes all blocks have the same sample names

  # Construct new mae
  # TODO: Fix this or make it more robust
  # NOTE: this metadata is solely the response, others are discard
  mae <- MultiAssayExperiment::MultiAssayExperiment(
    experiments = blocks,
    colData     = metadata
  )
  # Note, the delayed matrix is affecting the subset of metadata
  # so manually add response here
  mae$response <- metadata$response
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




