stratified_kfold <- function(y, k=5) {
  fold_labels <- seq(k)
  # foldid <- sample(rep(fold_labels, length = length(idxs)))
  # Create a vector of unique class labels for stratification
  unique_classes <- unique(y)
  # initialize
  test_split_idxs <- list()
  for (fold in fold_labels) {
    test_idxs <- integer(0)
    for (class in unique_classes) {
      # Get the indices of data points with the current class label
      class_idxs <- which(y == class)
      # Calculate the number of data points for this class in the test set
      num_class_samples <- length(class_idxs)
      num_test_samples <- ceiling(num_class_samples / k)
      # Randomly sample indices for the test set
      sampled_class_idxs <- sample(class_idxs, num_test_samples)
      # # Add the sampled indices to the test set for this fold
      test_idxs <- c(test_idxs, sampled_class_idxs)
    }
    # Shuffle the test indices for this fold
    test_idxs <- sort(test_idxs)
    split_name <- paste0("Fold", fold)
    
    # Store the test set indices in the list
    test_split_idxs[[split_name]] <- test_idxs  
  }
  return(test_split_idxs)
}
