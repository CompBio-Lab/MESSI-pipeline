  if (grepl(ext, mae_path)) {
    cat("Using simulated data instead")
    train_data <- readSimulated(mae_path, binary = FALSE)
    X <- train_data$X
    Y <- train_data$Y
    newdata <- readSimulated(test_path, binary = FALSE)
    test_name <- basename(tools::file_path_sans_ext(test_path))
  } else {
    cat("Using MAE")
    mae <- MultiAssayExperiment::loadHDF5MultiAssayExperiment(
      dir     =   mae_path,
      prefix  =  paste0("mae_", prefix)
    )
    obj <- MultiAssayExperiment::assays(mae)
    # Note need to transpose back to p * n
    X <-  lapply(obj, as.matrix)
    X <-  lapply(X, t)
    Y <- mae$response
  }


  predicted_results <- predictResults(model, newdata = newdata)
  saveRDS(predicted_results, "prediction.rds")
  cat("Predicted for", test_name)
  # CV requires enough number of samples, 20 is not good, perhaps >= 30
  
  
  # Create label to denote id/fold_i
  #fold <- fold_path %>%
  #     stringr::str_split(pattern = "/") %>%
  #     unlist() %>%
  #     tail(1)
  #label <- paste(c(data_id, fold), collapse="/") 