#!/usr/bin/env Rscript

# Script to run cooperative learning (simulate now)
doc <- "This script is to run cooperative learning method from multiview package, 
train only. Tt could possibly be ran on a inner CV model, output is a model for 
prediction usage in downstream.

Usage:
  run_cooperative_learning.R [options]

Options:
  --mae_path=MAE_PATH     Path to read full mae data
  --label=LABEL           Label of id and fold of data [default: data]
  --fold_path=FOLD_PATH   Path to read current test fold
  --inner_cv              Run inner cv with train data or not [default: false]
  --prefix=PREFIX         Prefix to read HDF5 [default: pre]
  --rho=RHO               Weight on the agreement penalty, rho=0 is a form of early fusion, and rho=1 is a form of late fusion.  [default: 0.5]
  --alpha=ALPHA           Elastic net mixing param with 0 <= alpha <=1, when 1 = lasso, when 0 ridge. [default: 1]
"
# Parase docopt
opt <- docopt::docopt(doc)

# Load libraries
library(multiview)
library(dplyr)
library(here)
library(stringr)

# Gather the pipeline dir (THIS IS VERY UGGLY FIX)
bin_dir <- Sys.getenv("PATH") |> 
  strsplit(":") |>
  unlist() |>
  tail(1)
pipeline_dir <- gsub("/bin", "", bin_dir)

source(here(pipeline_dir, "bin/rhelpers.R")) # This is included in nextflow bin path
# Loading generic utils
load_utils(here(pipeline_dir, "bin/logging"))
load_utils(here(pipeline_dir, "bin/preprocessing"))
load_utils(here(pipeline_dir, "bin/misc_utils"))


# This the main function to execute
main <- function(mae_path, label, fold_path, inner_cv, prefix, rho, alpha) {
  # Log the params used
  args_used <- c(as.list(environment()))
  logging_params(args_used)
  cat("\nLooking at this fold:", fold_path, "\n")
  d <- list.files(path=fold_path, full.names = TRUE)
  train_path <- d[str_detect(d, pattern = "_tr")]
  test_path <- d[str_detect(d, pattern = "_te")]
  # Then should read in the MAE and convert it to list of X and Y
  train_data <- load_MAE(train_path, prefix="train") |> extract_Xy()
  test_data <- load_MAE(test_path, prefix="test") |> extract_Xy()
  sample_names <- check_common_samples(train_data)
  cat("\nTotal of", length(sample_names), "samples:\n", sample_names)
  # Train a model to run inner cv or not
  # TODO: CALL THE inner cv model instead
  if (inner_cv) {
    cat("\nTraining with inner cv per single fold, this could take more time\n")
    model <- "A"
  } else {
    cat("\nNot running inner cv per fold\n")
    # use default settings
    model <- multiview(x_list=train_data$X, 
                       y=train_data$Y, 
                       rho=rho, 
                       family=binomial(), 
                       alpha=alpha
                       )
    cat("\nFitted model\n")
  }
  # Files names to write out
  model_file <- paste(label, "cooperative_learning_model.rds", sep="-")
  weight_file <-  paste(label, "model_weights.txt", sep="-")
  test_file <- paste(label, "test_data.rds", sep="-")
  cat("\nSaving files to", label, "\n")
  # Write out to disk
  saveRDS(object=model, file=model_file)
  write.table(x=data.frame(a0 = model$a0), file=weight_file)
  saveRDS(object=test_data, file=test_file)
  return(model)  
}

# Call the function here
main(mae_path  = opt$mae_path,
     label     = opt$label,
     fold_path = opt$fold_path,
     inner_cv  = opt$inner_cv,
     prefix    = opt$prefix,
     rho       = as.numeric(opt$rho),
     alpha     = as.numeric(opt$alpha)
)