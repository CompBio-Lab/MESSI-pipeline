#!/usr/bin/env Rscript

doc <- "This script is for running one single cv on full portion of data
to select relevant features out for downstream comparisons with
other methods selected features

Usage:
  cplr_select_features.R [options]

Options:
  --mae_path=MAE_PATH         Path to read the full data in
  --dataset_name=DNAME        Dataset name used as identification
  --output_ext=EXT            Extension of output table to save [default: csv]
  --n_percent=N_PER           N percent of features to be selected [default: 10]
  --nfolds=NFOLDS             Number of folds to perform CV to perform feature selection [default: 5]
  --criteria_order=CRT_ORDER  Variable to sort feature coeffcients, one of standardized_coef or coef [default: standardized_coef]
"
# Parse cli docs
opt <- docopt::docopt(doc)

# Load libraries
library(here)
library(MultiAssayExperiment)
library(multiview)
library(tidyr)
library(dplyr)
library(magrittr)
# Gather the pipeline dir (THIS IS VERY UGGLY FIX)
bin_dir <- Sys.getenv("PATH") |> 
  strsplit(":") |>
  unlist() |>
  tail(1)
pipeline_dir <- gsub("/bin", "", bin_dir)
# Source custom functions
source(here(pipeline_dir, "bin/rhelpers.R")) # This is included in nextflow bin path
# Loading generic utils from directories
load_utils(here(pipeline_dir, "bin/logging"))
load_utils(here(pipeline_dir, "bin/misc_utils"))
load_utils(here(pipeline_dir, "bin/plotting"))

# Main entrypoint of the script
# criteria_order: variable to sort the features, use one of standardized_coef or coef
main <- function(mae_path, dataset_name, n_percent, type.measure="deviance", rho=0.5, useLasso=FALSE,
nfolds=5, criteria_order="standardized_coef") {
  # PARAMS
  method <- "cooperative_learning"
  # Log the params used
  args_used <- c(as.list(environment()))
  logging_params(args_used)
  # Load the mae and extract to X and y comp, this would transpose it to n x P_i
  data_list <- loadHDF5MultiAssayExperiment(mae_path) |> extract_Xy()
  # Split them to X and Y (and factor this)
  X <- data_list$X
  Y <- as.factor(data_list$Y)
  # Get the first 10 rownames and colnames, and print it to file as sanity check
  logging_head_names(X=X, n = 10)
  # RUN a cv model on multiview (alpha 0 = ridge, alpha 1 = lasso)
  if (useLasso) {
    alpha <- 1
  } else {
    alpha <- 0
  }
  # fit the model (but with cv) , note: their default nfolds is actual 10 but that takes long time
  cv_model <- cv.multiview(x_list = X,  y = Y, 
                          family = binomial(), type.measure=type.measure, 
                          rho=rho, alpha=alpha, nfolds=nfolds)
  # Get the lambda to use
  s <- cv_model$lambda.min

  # Plot the loss vs different lambdas, the model under the hood is using glmnet
  par(mar=c(1,1,1,1))
  getPlotDevice(name = "mutlview_feature_selection_plot", dataset_name=dataset_name, 
              height=8, width=8, device="svg")
  plot(cv_model)
  dev.off()

  # Now get those features out by taking top n percent of features in each view
  feats_df <- coef_ordered(cv_model, s=s) %>%
              as_tibble() %>%
              rename(feature=view_col) %>%
              mutate(method = method,
                    dataset_name = dataset_name
              ) %>%
              group_by(view) %>%
              # Option to use coef instead of standardized_coef
              arrange(desc(abs( !!sym( criteria_order ) ))) %>%
              # This takes top N percent of feature from each view
              group_modify(~ slice_head(
                .x, n = round(n_percent * nrow(.x) / 100, digits=0)
                )
              ) %>%
              ungroup() %>%
              select(feature, view, method, dataset_name)
  
  # write it to disk
  feats_file <- paste0(method, "-", dataset_name, "_", "features_selected", ".csv")
  write.csv(x=feats_df, file=feats_file, row.names=FALSE)
  return(feats_df)
}

# Then call the function above
main(mae_path=opt$mae_path, dataset_name=opt$dataset_name, 
  n_percent=as.numeric(opt$n_percent), nfolds=as.numeric(opt$nfolds),
  criteria_order=opt$criteria_order)