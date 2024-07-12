#!/usr/bin/env Rscript

# Script to prepare mofa input
doc <- "This script is to run required preprocessing steps for demo_logit including data transformation
NA handling/imputing, scaling, and split them into fold specific MultiAssayExperiments like the following:

fold1/
  |___ fold1_train_MAE/ # Each MAE dir has an experiments.h5 and rds
  |___ fold1_test_MAE/
...
...
foldK/
  |___ foldK_train_MAE/
  |___ foldK_test_MAE/

Usage:
  demo_logit_preprocess.R [options]

Options:
  --data_path=DATA_PATH     Path to read full mae data
  --split_dir=SPLIT_DIR     Directory containing list of txt file [default: splits]
  --dataset_name=NAME       Name of dataset that is splitting     [default: empty]
"

# TODO: The docopt help message above can be better described or reformatted

# Parse cli args
opt <- docopt::docopt(doc)

# Load libraries
library(MultiAssayExperiment)
library(here)
library(dplyr)

# Helper funs to load splits
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


# Use this function to reconstruct mae after applying some transformation
reconstruct_mae <- function(mae) {
  # Given an mae with delayed matrices, we could load it into
  # memory and make it of HDF5 arrays instead
  # TODO: You could add more transformations inside this lapply
  # The as.matrix is required so it do not becomes DelayedMatrix (buggy)
  exp_list <- mae@ExperimentList
  view_names <- names(exp_list)
  X <- lapply(view_names, function(omics){
      # For each omics, we are going to take first 25 features only
      view <- exp_list[[omics]] |> as.matrix()
      random_25_feats <- rownames(view) |> head(25)
      view_reduced <- view[random_25_feats, ]
      return(view_reduced)
    })
  names(X) <- view_names
  col_data <- colData(mae)
  # Construct MAE
  new_mae <- MultiAssayExperiment::MultiAssayExperiment(experiments = X, colData=col_data)
  return(new_mae)
}

# =================================================================================
# MAIN entrance point
# TODO: You need to implement this function
main <- function(mae_path, split_dir, dataset_name) {
  # Verbose outputs for debugging
  cat("Splitting data for", dataset_name, "\n")
  cat("\nThe data is located in:", mae_path, "\n")
  cat("\nThe splits are located in:", split_dir, "\n")
  # Read in the MAE
  mae <- loadHDF5MultiAssayExperiment(dir=mae_path, prefix="")
  # Then load splits and divide it up into sub MAEs
  test_splits <- load_test_splits(split_dir=split_dir)
  fold_names <- names(test_splits)
  for (fold_name in fold_names) {
    # First subset both
    split <- test_splits[[fold_name]]
    # TODO: You need to apply transpose to your maes if the method requires a different format
    # Or apply other suitable transformations
    # MAE comes in a format of p_i x N , where p_i is number of features, and N is number of observations/patients
    tr_mae <- mae[, -split, drop=TRUE] |> reconstruct_mae()
    te_mae <- mae[, split, drop=TRUE] |> reconstruct_mae()
    # Then save each fold's train and test portion as subdirectory of fold name
    cat("\nSaving for ", fold_name, "\n")
    if (!dir.exists(fold_name)) {
      dir.create(fold_name)
    }
    tr_path <- file.path(fold_name, paste0(fold_name, "_tr"))
    te_path <- file.path(fold_name, paste0(fold_name, "_te"))
    # The train portion
    saveHDF5MultiAssayExperiment(tr_mae, dir=tr_path, prefix="train")
    # The test portion
    saveHDF5MultiAssayExperiment(te_mae, dir=te_path, prefix="test")
    cat("\nSaved for ", fold_name, "\n")                                                      
  }
}

# Then execute the main function here
main(mae_path=opt$data_path, split_dir=opt$split_dir, dataset_name=opt$dataset_name)