#!/usr/bin/env Rscript

# Script to run Diablo (simulate now)
doc <- "This script is to run DIABLO method from mixOmics package, train only
it could possibly be ran on a inner CV model, output is a modelel for prediction
usage in downstream.

Usage:
  run_diablo.R [options]

Options:
  --mae_path=MAE_PATH     Path to read full mae data
  --label=LABEL           Label of id and fold of data [default: data]
  --fold_path=FOLD_PATH   Path to read current test fold
  --prefix=PREFIX         Prefix to read HDF5 [default: pre]
  --run_inner_cv          Run inner cv with train data or not [default: false]
  --design=DESIGN         Strength of relationship to model blocks. One of full or null [default: full]
"

# Load libraries
library(mixOmics)
library(dplyr)
library(here)
library(MultiAssayExperiment)
library(stringr)

# Gather the pipeline dir (THIS IS VERY UGGLY FIX)
bin_dir <- Sys.getenv("PATH") |> 
  strsplit(":") |>
  unlist() |>
  tail(1)
# Determin if running on cluster deploy mode or local mode
is_scratch <- stringr::str_detect(bin_dir, pattern = "scratch")
if (is_scratch) {
  pipeline_dir <- gsub("/bin", "", bin_dir)
} else {
  pipeline_dir <- ""
}
# Load scripts ========================================================
source(here(pipeline_dir, "bin/rhelpers.R")) # This is included in nextflow bin path
# Load utils specific to simulation data?
rp <- resource_helper_path(here(pipeline_dir, "modules/diablo/train"))
source(here(rp, "genGrid.R"))
source(here(rp, "getDesign.R"))
source(here(rp, "tune_diablo.R"))
#source(here("bin/savers/saveFile.R"))
# Loading generic utils
load_utils(here(pipeline_dir, "bin/logging"))
load_utils(here(pipeline_dir, "bin/preprocessing"))
load_utils(here(pipeline_dir, "bin/misc_utils"))
# Parase docopt
opt <- docopt::docopt(doc)

# Main function to run
main <- function(mae_path, label, fold_path, design, run_inner_cv, prefix) {
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
  
  # Train a modelel modele to run inner cv or not
  if (run_inner_cv) {
    cat("\nTraining with inner cv per single fold, this could take more time\n")
    #---------------------------------------------------------------------------
    X <- train_data$X
    Y <- train_data$Y
    # Train a base model to use this to tune
    base_model <- mixOmics::block.splsda(X = X , Y = Y)
    #---------------------------------------------------------------------------
    # Design matrix, with diagonals 0, rest 0.1 (default)
    # Then this overrides the default full design of the script
    design <- getDesign(X = X)
    # run component number tuning with repeated CV
    tuned_output <- tune_diablo(base_model = base_model, design=design)
    # Train the final model
    model <- mixOmics::block.splsda(X = X, Y = Y, 
                                    ncomp = tuned_output$ncomp, 
                                    keepX = tuned_output$keepX, 
                                    design = design)
    #---------------------------------------------------------------------------
  } else {
    cat("\nNot running inner cv per fold\n")
    # use default settings
    # Use a fully connected design on def , could also use null
    model <- mixOmics::block.splsda(X = train_data$X, Y = train_data$Y, design=design)
    cat("\nFitted model\n")
  }

  # Filenames to write out
  model_file  <-  paste(label, paste("diablo", design, "model.rds", sep="_"), sep="-")
  weight_file <-  paste(label, "model_weights.txt", sep="-")
  test_file   <-  paste(label, "test_data.rds", sep="-")
  cat("\nSaving files to", label, "\n")
  # Write out to disk
  saveRDS(object = model, model_file)
  write.table(x = model$weights, weight_file)
  saveRDS(object = test_data, test_file)
  return(model)
}
# Call the function here
main(mae_path  = opt$mae_path,
     label     = opt$label,
     fold_path = opt$fold_path,
     prefix    = opt$prefix,
     design    = opt$design,
     run_inner_cv  = opt$run_inner_cv
)
cat("Done")

