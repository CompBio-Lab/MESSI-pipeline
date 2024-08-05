#!/usr/bin/env Rscript

# Script to run mofa
doc <- "This script is to run MOFA method from MOFA2 package, train only
it could possibly be ran on a inner CV model, output is a modelel for prediction
usage in downstream.

Usage:
  run_mofa.R [options]

Options:
  --mae_path=MAE_PATH     Path to read full mae data
  --label=LABEL           Label of id and fold of data [default: data]
  --fold_path=FOLD_PATH   Path to read current test fold
  --prefix=PREFIX         Prefix to read HDF5 [default: pre]
  --run_inner_cv          Run inner cv with train data or not [default: false]
"

# Load libraries
library(dplyr)
library(glmnet)
library(here)
library(MOFA2)
library(MultiAssayExperiment)
library(stringr)
# Load scripts ========================================================
source(here("bin/rhelpers.R")) # This is included in nextflow bin path
# Loading generic utils
load_utils(here("bin/logging"))
load_utils(here("bin/preprocessing"))
load_utils(here("bin/misc_utils"))
# Parase docopt
opt <- docopt::docopt(doc)

# Need to force use python
default_python <- "/usr/bin/python"
reticulate::use_python(default_python)

# Main function to run
main <- function(mae_path, label, fold_path, run_inner_cv, prefix) {
  # Log the params used
  args_used <- c(as.list(environment()))
  logging_params(args_used)
  cat("\nLooking at this fold:", fold_path, "\n")
  d <- list.files(path=fold_path, full.names = TRUE)
  train_path <- d[str_detect(d, pattern = "_tr")]
  test_path <- d[str_detect(d, pattern = "_te")]
  # Then should read in the MAE
  train_data <- load_MAE(train_path, prefix="train") |> extract_Xy()
  test_data <- load_MAE(test_path, prefix="test") |> extract_Xy()
  sample_names <- check_common_samples(train_data)
  cat("\nTotal of", length(sample_names), "samples:\n", sample_names)
  
  # Filenames to write out
  model_file <-  paste(label, "model.rds", sep="-") 
  test_file  <-  paste(label, "test_data.rds", sep="-")

  # Train a modelel modele to run inner cv or not
  if (run_inner_cv) {
    message("\nThe inner CV option in each fold is not implemented for MOFA yet\n")
    #---------------------------------------------------------------------------
  } else {
    message("\nNot running inner cv per fold\n")
  
    train_x <- train_data$X$embeddings
    # Print head of embeddings
    cat( train_x |> head() )
    train_y <- train_data$Y
    # Glmnet model (ACTUALLY using this to predict)
    model <- glmnet(
      x = train_x,
      y = train_y,
      family = "binomial"
    )
  }
  # =========================================
  message("\nSaving files to", label, "\n")
  # Write out to disk
  # Saving the test data for later use
  # The mofa model hdf5 is saved once its training is done
  saveRDS(object = test_data, file=test_file)
  saveRDS(object = model, file=model_file)
  return(model)
}
# Call the function here
main(mae_path  = opt$mae_path,
     label     = opt$label,
     fold_path = opt$fold_path,
     prefix    = opt$prefix,
     run_inner_cv  = opt$run_inner_cv
)
cat("Done")