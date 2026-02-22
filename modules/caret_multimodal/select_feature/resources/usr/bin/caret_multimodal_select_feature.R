#!/usr/bin/env Rscript

doc <- "This script is for running one single cv on full portion of data
to select relevant features out from caret_multimodal for downstream comparisons with
other methods selected features.

Usage:
  caret_multimodal_select_feature.R [options]

Options:
  --data_path=DATA_PATH     Path to read the full data in
  --dataset_name=DNAME      Dataset name used as identification
  --output_ext=EXT          Extension of output table to save [default: csv]
  --nfolds=NFOLDS           Number of folds to perform CV to perform feature selection [default: 5]
  --criteria_order=CRT      Variable to sort feature coeffcients, one of standardized_coef or coef [default: coef]
"
# Parse cli docs
opt <- docopt::docopt(doc)

# Load libraries
library(here)
library(MultiAssayExperiment)
library(tidyr)
library(dplyr)
library(magrittr)
library(tibble)
library(caret)

bin_dir <- Sys.getenv("PATH") |> 
  strsplit(":") |>
  unlist() |>
  tail(1)

# Determine if running on cluster deploy mode or local mode
is_scratch <- stringr::str_detect(bin_dir, pattern = "scratch")
if (is_scratch) {
  pipeline_dir <- gsub("/bin", "", bin_dir)
} else {
  pipeline_dir <- ""
}


# Source custom functions
source(here(pipeline_dir, "bin/rhelpers.R")) # This is included in nextflow bin path
# Loading generic utils from directories
load_utils(here(pipeline_dir, "bin/logging"))
load_utils(here(pipeline_dir, "bin/misc_utils"))
load_utils(here(pipeline_dir, "bin/plotting"))

# Helper functions to run cv, fit final model, and extract features
run_caret_multimodal_cv <- function(X, Y, nfolds=5) {
  # NOTE: this is not the same as the normal train process, as it has different parameters here
  # Caret relies on tuneGrid and trainControl for hyperparameter tuning
  message("Running without inner cross-validation, using default hyperparameters")
  # Default with no inner cv, simple train-test 
  trControl <- caret::trainControl(
    method = "cv",
    number = nfolds,
    classProbs = TRUE,
    summaryFunction = caret::twoClassSummary,
    savePredictions = "final"
  )
  # Default hyperparameters
  #alpha_vals <- c(0.7, 0.775, 0.850, 0.925, 1)
  #   lambda_vals <- seq(0.001, 0.1, by = 0.01)
  alpha_vals <- c(0) # Ridge regression only, no Lasso or elastic-net, since we have many features and want to keep them all
  lambda_vals <- 10^seq(-4, 3, length = 20) # Use log space lambda values
  tuneGrid <- expand.grid(alpha = alpha_vals, lambda = lambda_vals)
  # =========================================================
  # First fit individual models for each modality
  message("Fitting base models for each modality...")
  base_models <- caretMultimodal::caret_list(
    target = Y,
    data_list = X,
    method = "glmnet",
    tuneGrid = tuneGrid,
    trControl = trControl
  )
  # Then fit the ensemble model
  message("Fitting stacked model...")
  stack_model <- caretMultimodal::caret_stack(
    caret_list = base_models,
    method = "glmnet",
    tuneGrid = tuneGrid,
    trControl = trControl
  )
  # Return the stacked model
  return(stack_model)
}



# Main entrance of the script
main <- function(mae_path, dataset_name, nfolds, criteria_order="coef") {
  # ---------------------------------------------------------------------------
  # PARAMS
  # ---------------------------------------------------------------------------
  method <- "caret_multimodal"
  # ---------------------------------------------------------------------------
  # IMPLEMENTATION
  # ---------------------------------------------------------------------------
  # Log the params used
  args_used <- c(as.list(environment()))
  logging_params(args_used)
  # Load the mae and extract to X and y comp, this would transpose it to n x P_i
  data_list <- loadHDF5MultiAssayExperiment(mae_path) |> extract_Xy(verbose_target=TRUE)
  # Split them to X and Y (and factor this)
  X <- data_list$X
  Y <- as.factor(data_list$Y)
  # Get the first 10 rownames and colnames, and print it to file as sanity check
  logging_head_names(X=X, n = 10)
  # TODO: Run a cv on X and Y to get hyperparameters
  # Then fit the model
  cv_model <- run_caret_multimodal_cv(X, Y, nfolds = nfolds)
  # TODO: Extract the features out from your final model and wrangle to df for downstream usage
  feature_weights <- caretMultimodal:::compute_feature_contributions.caret_stack(cv_model, n_features = Inf)
  feats_df <- feature_weights %>%
              dplyr::rename(
                "view" = "Model",
                "coef" = "Relative Contribution"
              ) %>%
              dplyr::rename_with(tolower) %>%
              as_tibble() %>%
              # Add more metadata
              mutate(method = method,
                    dataset_name = dataset_name
              ) %>%
              group_by(view) %>%
              # Sort by descending order of some weights
              arrange(desc(abs( !!sym( criteria_order ) ))) %>%
              # These are the required columns for downstream process
              dplyr::select(feature, view, coef, method, dataset_name)

  # write it to disk
  comb_name <- paste(method, dataset_name, sep = "-")
  output_format <- "csv"
  feats_file <- paste0(comb_name , "_", "features_selected", ".", output_format)
  write.csv(x=feats_df, file=feats_file, row.names=FALSE)


  return(feats_df)
}

# Set seed for reproducibility
set.seed(1)

# Then call the function above
main(
  mae_path=opt$data_path, 
  dataset_name=opt$dataset_name,
  nfolds=as.numeric(opt$nfolds),
  criteria_order=opt$criteria_order
)