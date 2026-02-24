#!/usr/bin/env Rscript

# Script to prepare mofa input
doc <- "This script is to run MOFA method from MOFA2 package, train only
it could possibly be ran on a inner CV model, output is a modelel for prediction
usage in downstream.

Usage:
  preprocess_mofa.R [options]

Options:
  --mae_path=MAE_PATH       Path to read full mae data
  --split_dir=SPLIT_DIR     Directory containing list of txt file [default: empty]
  --dataset_name=NAME       Name of dataset that is splitting     [default: empty]
  --num_factors=NUM_FACTOR  Number of factors to supply into MOFA [default: 1]
"

# Parse cli args
opt <- docopt::docopt(doc)

# Load libraries
library(MOFA2)
library(MultiAssayExperiment)
library(here)
library(dplyr)

# Python related
default_python <- "/usr/bin/python"
reticulate::use_python(default_python)

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


get_seed <- function(dataset_name) {
  d_int <- utf8ToInt(dataset_name) # Convert dataset name to integer
  seed  <- sum(d_int)
  message("\nSeed used:  ", seed)
  return(seed)
}


# =================================================================================
# MAIN entrance point
main <- function(mae_path, split_dir, dataset_name, num_factors) {
  # Seed for reproducibility
  seed <- get_seed(dataset_name) # Convert dataset name to integer and sum it to get a seed
  set.seed(seed) 
  # Should be a list of splits
  cat("Splitting data for", dataset_name, "\n")
  cat("\nThe data is located in:", mae_path, "\n")
  cat("\nThe splits are located in:", split_dir, "\n")
  # Read in the MAE
  # Note the prefix "" is required here?
  raw_mae <- MultiAssayExperiment::loadHDF5MultiAssayExperiment(dir=mae_path, prefix="")
  raw_col_data <- raw_mae@colData |> as.data.frame()
  
  # Then starting to use mofa here
  mofa_obj <- create_mofa(raw_mae)
  # TODO: ADD A manual scaling to the train data, possibly in a fun, so that it could be applied on the test data as well
  # NOTE this treats features as rows and samples as columns
  # Get data options
  # TODO: these two could be discussed later
  # scale_groups: if groups ( NOT meaning group of response ) have different ranges/variances, 
  #               it is good practice to scale each group to unit variance. Default is FALSE
  # scale_views: if views (omic) have different ranges/variances, 
  #              it is good practice to scale each view to unit variance. Default is FALSE
  data_opts <- get_default_data_options(mofa_obj)
  # Get model options
  # num_factors might be tuneable
  model_opts <- get_default_model_options(mofa_obj)
  
  # THIS IS LATEST
  # Num factor is default to 1
  model_opts$num_factors <- num_factors # Now this parameter is controlled from nextflow

  # ~~TODO: Currently to use number factors to be 2 x the numbers of views~~
  # model_opts$num_factors <- 2 * mofa_obj@dimensions$M


  # Get train options
  # maxiter: number of iterations. Default is 1000.
  # convergence_mode: fast, medium, slow? not sure which one affects? tuneable?
  # gpu_mode: use gpu, but needs cupy installed?
  train_opts <- get_default_training_options(mofa_obj)
  # Now build and train mofa object
  # Notice this overrides the previous object created
  mofa_obj <- prepare_mofa(
    object = mofa_obj,
    data_options = data_opts,
    model_options = model_opts,
    training_options = train_opts
  )
  # Convert to embeddings
  mofa_emb_file <- "mofa_emb.hdf5"
  mofa_emb_raw <- run_mofa(mofa_obj, outfile = mofa_emb_file)
  # TODO: This is an uggly fix to load "no variance" explained factors, since by default it drops all
  mofa_emb <- load_model(file=mofa_emb_file, remove_inactive_factors = FALSE)
  # Although to make predictions, need its embeddings and use a glmnet on prediction
  factors <- get_factors(mofa_emb, factors="all")
  # Then use this new mae
  mae <- MultiAssayExperiment(experiments = list(embeddings=factors$group1 |> t() ),
                              colData = raw_col_data
                            )
  # Then load splits and divide it up into sub MAEs
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

# Then execute the main function here
main(
  mae_path=opt$mae_path, 
  split_dir=opt$split_dir, 
  dataset_name=opt$dataset_name, 
  num_factors=as.numeric(opt$num_factors)
  )
