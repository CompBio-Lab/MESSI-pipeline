#!/usr/bin/env Rscript
doc <- "
This script is used to split mae data into train and test portion for 
each split provided and saved to file for downstream process

Author: Tony Liang

Usage:
  split_mae.R [options]
  
Options:
  --mae_path=MAE_PATH       Path containing full data inside MAE  [default: empty]
  --split_dir=SPLIT_DIR     Directory containing list of txt file [default: empty]
  --dataset_name=NAME       Name of dataset that is splitting     [default: empty]
  --transpose               Transpose the data as method requires [default: False]
"

# Parase docopt
opt <- docopt::docopt(doc)

# Helper to load all test splits
load_test_splits <- function(split_dir, pattern=".txt", ...) {
  if (split_dir == "empty") {
    stop("You did not provide the directory that contains txt files of indices")
  }
  # Glob pattern
  # The split dir needs to be relative, do NOT use here::here
  # When run with nextflow, as it caches the dir inside a work directory
  idx_files <- list.files(path=split_dir, 
                          pattern=".txt", full.names = TRUE)
  # Read in data
  idx_list <- lapply(idx_files, function(f) {
    data <- scan(f, what = numeric(), quiet = TRUE)
    return(data)
  })
  
  # Check if it contains zero (hence assume it was 0index based)
  zero_indexed <- any(sapply(idx_list, function(vec) any(vec == 0)))
  # Then if true, shift all by 1
  if (zero_indexed) {
    cat("\nIndex founded to be 0 based, shift by 1 for all\n")
    idx_list <- lapply(idx_list, function(x) x + 1)
  }
  
  # Assign names based on loaded files
  idx_list <- setNames(idx_list, 
                       tools::file_path_sans_ext(basename(idx_files)))
  return(idx_list)
}

# get_tr_te_mae <- function(mae, test_split) {
#   response <- mae$response
#   if (is.atomic(response)) {
#     n <- length(response)
#   } else {
#     n <- response$response 
#   }
#   # ========================
#   full_idx <- seq_along(1:n)
#   test_idx <- sort(test_split)
#   train_idx <- setdiff(full_idx, test_idx)
#   # Then the train 

# }

# Use this function to reconstruct mae
reconstruct_mae <- function(mae) {
  # Given an mae with delayed matrices, we could load it into
  # memory and make it of HDF5 arrays instead
  X <- mae@ExperimentList |> lapply(as.matrix)
  y <- mae$response
  # Construct MAE
  new_mae <- MultiAssayExperiment::MultiAssayExperiment(experiments = X)
  new_mae$response <- y
  return(new_mae)
}


# Actual fun to split each MAE to train and test portion
split_mae <- function(mae_path, split_dir, dataset_name) {
  # Read in the MAE
  # Note the prefix "" is required here?
  mae <- MultiAssayExperiment::loadHDF5MultiAssayExperiment(dir=mae_path, prefix="")
  # Should be a list of splits
  cat("Splitting data for", dataset_name, "\n")
  cat("\nThe data is located in:", mae_path, "\n")
  cat("\nThe splits are located in:", split_dir, "\n")
  test_splits <- load_test_splits(split_dir=split_dir)
  fold_names <- names(test_splits)
  
  for (fold_name in fold_names) {
      # First subset both
      split <- test_splits[[fold_name]]
      # TODO: Transpose data only when method requires it to
      tr_mae <- mae[, -split, drop=TRUE] |> reconstruct_mae()
      te_mae <- mae[, split, drop=TRUE] |> reconstruct_mae()
      # Then save each fold's train and test portion as subdirectory of fold name
      cat("\nSaving for", fold_name, "\n")
      if (!dir.exists(fold_name)) {
        dir.create(fold_name)
      }
      tr_path <- file.path(fold_name, paste0(fold_name, "_tr"))
      te_path <- file.path(fold_name, paste0(fold_name, "_te"))
      # The train portion
      MultiAssayExperiment::saveHDF5MultiAssayExperiment(tr_mae, dir=tr_path,
                                                        prefix="train")
      # The test portion
      MultiAssayExperiment::saveHDF5MultiAssayExperiment(te_mae, dir=te_path,
                                                        prefix="test")
      cat("\nSaved for", fold_name, "\n")                                                      
    }
}

split_mae(mae_path=opt$mae_path, split_dir=opt$split_dir, dataset_name=opt$dataset_name)
