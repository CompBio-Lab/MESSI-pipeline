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
  --n_percent=N_PER         N percent of features per view to select [default: 10]
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
run_caret_multimodal_cv <- function(X, Y) {
  # NOTE: this is not the same as the normal train process, as it has different parameters here
  # Caret relies on tuneGrid and trainControl for hyperparameter tuning
  if (inner_cv) {
    trControl <- trainControl(
      method = "repeatedcv",
      number = 5,
      repeats = 5,
      classProbs = TRUE,
      summaryFunction = twoClassSummary,
      savePredictions = "final"
    )
    alphas <- c(0.7, 0.775, 0.850, 0.925, 1)
    lambdas <- seq(0.001, 0.1, by = 0.01)
    tuneGrid <- expand.grid(alpha = alphas, lambda = lambdas)
  } else {
    # Default with no inner cv, simple train-test 
    trControl <- trainControl(
      method = "cv",
      number = 5,
      classProbs = TRUE,
      summaryFunction = twoClassSummary,
      savePredictions = "final"
    )
    # Default hyperparameters
    tuneGrid <- expand.grid(alpha = 1, lambda = 0.01)
  }
  # =========================================================
  # First fit individual models for each modality
  base_models <- caretMultimodal::caret_list(
    target = train_data$Y,
    data_list = train_data$X,
    method = "glmnet",
    tuneGrid = tuneGrid,
    trControl = trControl
  )
  # Then fit the ensemble model
  stack_model <- caretMultimodal::caret_stack(
    caret_list = base_models,
    data_list = train_data$X,
    target = train_data$Y, 
    method = "glmnet",
    tuneGrid = tuneGrid,
    trControl = trControl
  )
  # Return the stacked model
  return(stack_model)
}



# Main entrance of the script
# TODO: You need to re-implement the main logic
# 1. Perform some kind of cv to find hyperparameters
# 2. Use those found optimal hyperparams to fit final model
# 3. Then select top weights from the final model
# 4. Take top H percent of each view (omic) features from the dataset input
main <- function(mae_path, dataset_name, n_percent, design) {
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
  cv_model <- run_caret_multimodal_cv(X, Y)
  # TODO: Extract hyperparameters from your cv model to fit final model
  final_model <- fit_final_model(X, Y, hyperparam1, hyperparam2)
  # TODO: Extract the features out from your final model and wrangle to df for downstream usage
  feats_df <- EXTRACT_FEATURES_OUT %>%
              as_tibble() %>%
              # Add more metadata
              mutate(method = method,
                    dataset_name = dataset_name
              ) %>%
              # View should be name of the omics
              group_by(view) %>%
              # Sort by descending order of some weights
              # TODO: put in actual criteria_order column name, i.e. coef, weight
              arrange(desc(abs( !!sym( criteria_order ) ))) %>%
              # This takes top N percent of feature from each view
              group_modify(~ slice_head(
                .x, n = round(n_percent * nrow(.x) / 100, digits=0)
                )
              ) %>%
              ungroup() %>%
              # These are the required columns for downstream process
              select(feature, view, method, dataset_name)

  # write it to disk
  comb_name <- paste(method, dataset_name, sep = "-")
  output_format <- "csv"
  feats_file <- paste0(comb_name , "_", "features_selected", ".", output_format)
  write.csv(x=feats_df, file=feats_file, row.names=FALSE)


  return(feats_df)
}

# Then call the function above
main(
  mae_path=opt$data_path, 
  dataset_name=opt$dataset_name, 
  n_percent=as.numeric(opt$n_percent)
)