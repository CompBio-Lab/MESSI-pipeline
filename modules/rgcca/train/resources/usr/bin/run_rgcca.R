#!/usr/bin/env Rscript

# Script to run Diablo (simulate now)
doc <- "This script is to run RGCCA method from RGCCA package, train only.
It could possibly be ran on a inner CV model, output is a model for prediction
usage in downstream.

Usage:
  run_rgcca.R [options]

Options:
  --mae_path=MAE_PATH     Path to read full mae data
  --label=LABEL           Label of id and fold of data [default: data]
  --fold_path=FOLD_PATH   Path to read current test fold
  --inner_cv              Run inner cv with train data or not [default: false]
  --prefix=PREFIX         Prefix to read HDF5 [default: pre]
  --method=METHOD         RGCCA method to run [default: rgcca]
"

# Load libraries
library(RGCCA)
library(dplyr)
library(here)
library(MultiAssayExperiment)
library(stringr)
# Gather the pipeline dir (THIS IS VERY UGGLY FIX)
bin_dir <- Sys.getenv("PATH") |> 
  strsplit(":") |>
  unlist() |>
  tail(1)
pipeline_dir <- gsub("/bin", "", bin_dir)

# Load scripts ========================================================
source(here(pipeline_dir, "bin/rhelpers.R")) # This is included in nextflow bin path
# Loading generic utils
load_utils(here(pipeline_dir, "bin/logging"))
load_utils(here(pipeline_dir, "bin/preprocessing"))
load_utils(here(pipeline_dir, "bin/misc_utils"))
# Load specific util
rp <- resource_helper_path(here(pipeline_dir, "modules/rgcca/train"))
source(here(rp, "parse_rgcca_input.R"))
# Parase docopt
opt <- docopt::docopt(doc)

# Main function to run
main <- function(mae_path, label, fold_path, inner_cv, prefix, method, tau=1) {
  # Log the params used
  args_used <- c(as.list(environment()))
  logging_params(args_used)
  cat("\nLooking at this fold:", fold_path, "\n")
  d <- list.files(path=fold_path, full.names = TRUE)
  train_path <- d[str_detect(d, pattern = "_tr")]
  test_path <- d[str_detect(d, pattern = "_te")]
  # Then should read in the MAE and convert it to list of X and Y
  # A little bit more special when reading in data, we get the X and Y altogether
  train_data <- load_MAE(train_path, prefix="train") |> 
                extract_Xy() |> 
                parse_rgcca_input()
  test_data <- load_MAE(test_path, prefix="test") |> 
                extract_Xy() |> 
                parse_rgcca_input()

  # TODO: THIS IS VERY UGGLY FIX, that need to force coerce the data into factor
  train_data$response <- as.factor(train_data$response)
  test_data$response <- as.factor(test_data$response)

  # Get common sample names
  sample_names <- check_common_samples(train_data)
  cat("\nTotal of", length(sample_names), "samples:\n", sample_names)
  
  # Train a modelel modele to run inner cv or not
  if (inner_cv) {
    cat("\nTraining with inner cv per single fold, this could take more time\n")
    message("\nNot implemented inner cv yet\n")
    model <- "A"
  } else {
    message("\nNot running inner cv per fold\n")
    # use default settings
    # The response block is always set at the end of the list of data
    model <- rgcca(train_data, tau=tau, method=method, response=length(train_data))
    message("\nFitted model\n")
  }

  # Filenames to write out
  model_file <- paste(label, paste0(method, "_model.rds"), sep="-")
  test_file <- paste(label, paste0(method, "_test_data.rds"), sep="-")
  cat("\nSaving files to", label, "\n")
  # Write out to disk
  saveRDS(object = model, model_file)
  saveRDS(object = test_data, test_file)
  return(model)
}
# Call the function here
main(mae_path  = opt$mae_path,
     label     = opt$label,
     fold_path = opt$fold_path,
     inner_cv  = opt$inner_cv,
     prefix    = opt$prefix,
     method    = opt$method
     )

message("Done")

