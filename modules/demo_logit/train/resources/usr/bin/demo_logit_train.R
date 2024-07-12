#!/usr/bin/env Rscript

# Script to train demo_logit model
doc <- "This script is to run demo_logit method, run it only against the train MAE from previously
processed data. Output is the path to this trained model and the test MAE.

Usage:
  demo_logit_train.R [options]

Options:
  --fold_path=FOLD_PATH       Path to read current test fold
  --label=LABEL               Label of id and fold of data [default: data]
  --prefix=PREFIX             Prefix to read HDF5 [default: pre]
  --run_inner_cv              Run inner cv with train data or not [default: false]
  --method_name=METHOD_NAME   Name of the method [default: demo_logit]
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


list2df <- function(data) {
  sample_name <- data$X[[1]] |> rownames()
  # Then we merge the X and y back for glm 
  X_df <- do.call(cbind, data$X) |>
          as.data.frame() |>
          tibble::rownames_to_column(var="sample_name")
  y <- data$Y
  names(y) <- sample_name
  y_df <- y |> 
          as.data.frame() |>
          tibble::rownames_to_column(var="sample_name")
  # Use this instead for modelling
  merged_df <- left_join(X_df, y_df, by = "sample_name")
  return(merged_df)
}


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
  train_data_list <- load_MAE(train_path, prefix="train") |> extract_Xy()
  test_data_list <- load_MAE(test_path, prefix="test") |> extract_Xy()
  sample_names <- check_common_samples(train_data_list)
  # Since we using glm, we provide another layer of transforming data
  train_data <- list2df(train_data_list)
  test_data <- list2df(test_data_list)
  
  # Sanity check for debugging
  cat("\nTotal of", length(sample_names), "samples:\n", sample_names)
  
  # TODO: You need to implement your training logic here
  # Train a model
  # Recommended to use default settings
  model <- glm(formula=y~. , family="binomial", data = train_data |> select_if(is.numeric))
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