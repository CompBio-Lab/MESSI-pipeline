#!/usr/bin/env Rscript

# Script to train {{ method|lower }} model
doc <- "This script is to run {{ method|lower }} method, run it only against the train MAE from previously
processed data. Output is the path to this trained model and the test MAE.

Usage:
  {{ method|lower }}_train.R [options]

Options:
  --fold_path=FOLD_PATH       Path to read current test fold
  --label=LABEL               Label of id and fold of data [default: data]
  --prefix=PREFIX             Prefix to read HDF5 [default: pre]
  --run_inner_cv              Run inner cv with train data or not [default: false]
  --method_name=METHOD_NAME   Name of the method [default: {{ method|lower }}]
"

# TODO: You could possibly add more args for the cli


# Load libraries
library(dplyr)
library(here)
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


# TODO: You might need to re-implement the main logic
# Main function to run
main <- function(fold_path, label, prefix, method_name) {
  # Log the params used
  args_used <- c(as.list(environment()))
  logging_params(args_used)
  cat("\nLooking at this fold: ", fold_path, "\n")
  # Finds the subdirectories containing tr and te MAE
  d <- list.files(path=fold_path, full.names = TRUE)
  train_path <- d[str_detect(d, pattern = "_tr")]
  test_path <- d[str_detect(d, pattern = "_te")]
  # Then should read in the MAE and convert it to list of X and Y
  # This converts usual MAE format of p_i x N to N x p_i
  train_data <- load_MAE(train_path, prefix="train") |> extract_Xy()
  test_data <- load_MAE(test_path, prefix="test") |> extract_Xy()
  sample_names <- check_common_samples(train_data)
  # Sanity check for debugging
  cat("\nTotal of", length(sample_names), "samples:\n", sample_names)
  
  # TODO: You need to implement your training logic here
  # Train a model
  # Recommended to use default settings
  model <- "TODO"

  # Filenames to write out
  model_file  <-  paste(label, paste(method_name, "model.rds", sep="_"), sep="-")
  test_file   <-  paste(label, "test_data.rds", sep="-")
  cat("\nSaving files to", label, "\n")
  # Write out to disk
  saveRDS(object = model, model_file)
  saveRDS(object = test_data, test_file)
  return(model)
}
# Call the function here
main(
  fold_path = opt$fold_path,
  label     = opt$label,
  prefix    = opt$prefix,
  method_name= opt$method_name
)
cat("Done")