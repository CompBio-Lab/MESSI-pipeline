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
  --outcome_type=TYPE       classification or survival            [default: classification]
  --time_col=TIME_COL       colData column of survival time       [default: time]
  --status_col=STAT_COL     colData column of event indicator     [default: status]
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

reconstruct_mae <- function(
    mae,
    outcome_type = "classification",
    response_col = "response",
    time_col = "time",
    status_col = "status"
) {
  if (!outcome_type %in% c("classification", "survival")) {
    stop("outcome_type must be 'classification' or 'survival'")
  }

  cd <- SummarizedExperiment::colData(mae) |> as.data.frame()

  required_cols <- if (outcome_type == "classification") {
    response_col
  } else {
    c(time_col, status_col)
  }

  missing_cols <- setdiff(required_cols, colnames(cd))
  if (length(missing_cols) > 0L) {
    stop("Missing outcome columns: ", paste(missing_cols, collapse = ", "))
  }

  # Materialize each experiment as an in-memory matrix.
  X <- lapply(
    MultiAssayExperiment::experiments(mae),
    function(x) {
      # For SummarizedExperiment, use its first assay.
      if (methods::is(x, "SummarizedExperiment")) {
        x <- SummarizedExperiment::assay(x)
      }
      as.matrix(x)
    }
  )

  if (outcome_type == "classification") {
    cd$response <- cd[[response_col]]
  } else {
    # Extract both before assignment in case source names overlap.
    time <- cd[[time_col]]
    status <- cd[[status_col]]
    cd$time <- time
    cd$status <- status
  }

  MultiAssayExperiment::MultiAssayExperiment(
    experiments = X,
    colData = cd
  )
}

# Actual fun to split each MAE to train and test portion
split_mae <- function(mae_path, split_dir, dataset_name, outcome_type="classification") {
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
      tr_mae <- mae[, -split, drop=TRUE] |> reconstruct_mae(outcome_type = outcome_type)
      te_mae <- mae[, split, drop=TRUE] |> reconstruct_mae(outcome_type = outcome_type)
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

split_mae(mae_path=opt$mae_path, split_dir=opt$split_dir, dataset_name=opt$dataset_name, outcome_type=opt$outcome_type)
