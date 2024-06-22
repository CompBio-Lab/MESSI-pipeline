#!/usr/bin/env Rscript
doc <- "
This script is used to read in R lists and vector to combine real data
and convert it to MAE and MuData

Author: Tony Liang

Usage:
  transform_mae_format.R [options]

Options:
  --mae_path=MAE_PATH       Path to the MultiAssayExperiment [default: empty]
  --dataset_name=DNAME      Name of dataset to provide as id [default: empty]
  --replace_na_val=NA_VAL   Value to replace NAs inside the data [default: 0]
"
library(here)
library(mixOmics)
# Load scripts
source(here("bin/rhelpers.R"))
source(here("bin/misc_utils/load_MAE.R"))
# Other related files to this script
rp <- resource_helper_path("modules/prepare_data/prepare_mae_data")
source(here(rp, "check_long_wide.R"))
source(here(rp, "check_response.R"))
source(here(rp, "preprocess_view.R"))
source(here(rp, "save_mae.R"))

# Parse docopt
opt <- docopt::docopt(doc)

# Requirements of the MAE data
# 1. Needs to be in bioconductor way, p_i (distinct num vars) x N (observations)
# 2. Response stays at factor yes or no
# 3. Need to have a common observations names set as sample_names
# 4. Also requires to supply a dataset_name

main <- function(mae_path, dataset_name, prefix="", replace_na_val=0, center=TRUE, scale=FALSE) {
  # Fail quickly
  if (mae_path == "empty") stop ("Need to provide a path to directory containing MAE")
  if (dataset_name == "empty") stop("Need to provide a dataset name")
  # More serious stuff here
  # Try loading MAE
  mae <- load_MAE(mae_path, prefix)
  # Need to check if long wide format for the experimentlist
  # Make sure X follows bioc format
  X <- check_long_wide(X=mae@ExperimentList@listData)
  # TODO: This is NOT thoroughly tested yet
  # Another preprocessing step
  X <- preprocess_view(X, replace_na_val=replace_na_val, scale=scale)
  # This would transform response to factor chr
  y <- check_response(y=mae$response)
  # Put together these inputs and resave
  dat <- list(blocks=X, response=y)
  # Save each of this to both MAE and Mu
  new_mae <- save_mae(dat, dataset_name=dataset_name, prefix=prefix)
  return(new_mae)
}


# Execute the main function here
main(mae_path=opt$mae_path, dataset_name=opt$dataset_name, 
replace_na_val=as.numeric(opt$replace_na_val))
