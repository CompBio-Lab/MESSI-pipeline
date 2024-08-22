#!/usr/bin/env Rscript

doc <- "This script is for running one single cv on full portion of data
to select relevant features out for downstream comparisons with
other methods selected features

Usage:
  rgcca_select_features.R [options]

Options:
  --mae_path=MAE_PATH           Path to read the full data in
  --dataset_name=DNAME          Dataset name used as identification
  --output_ext=EXT              Extension of output table to save [default: csv]
  --n_percent=N_PER             N percent of features to be selected [default: 10]
  --nfolds=NFOLDS               Number of folds to perform CV to perform feature selection [default: 5]
  --prediction_model=PRED_MOD   Prediction model from caret [default: lda]
  --metric=METRIC               Metric to perform CV on [default: Balanced_Accuracy]
"
# Parse cli docs
opt <- docopt::docopt(doc)

# Load libraries
library(RGCCA)
library(MultiAssayExperiment)
library(tibble)
library(dplyr)
library(here)
library(magrittr)

# Source custom functions
source(here(pipeline_dir, "bin/rhelpers.R")) # This is included in nextflow bin path
# Loading generic utils from directories
load_utils(here(pipeline_dir, "bin/logging"))
load_utils(here(pipeline_dir, "bin/misc_utils"))
load_utils(here(pipeline_dir, "bin/plotting"))

# Main entrypoint of the script
# prediction_model should be glm to accord with rest of methods?
main <- function(mae_path, dataset_name, n_percent, prediction_model = "lda", par_type="sparsity", 
                 validation = "kfold", nfolds=5, reps=1, metric="Balanced_Accuracy",
                 criteria_order = "top") {
  # PARAMS
  method <- "rgcca"
  # Log the params used
  args_used <- c(as.list(environment()))
  logging_params(args_used)
  # Load the mae and extract to X and y comp, this would transpose it to n x P_i
  data_list <- loadHDF5MultiAssayExperiment(mae_path) |> extract_Xy()
  # Get the X out as it being used a lot of times
  X <- data_list$X
  view_names <- names(X) # Save its names to use later
  # Split them to X and Y (and factor this)
  # It should now look like list(X1=X1, X2=X2, ... , XN=XN, response=Y)
  rgcca_input <- X
  rgcca_input[["response"]] <- as.factor(data_list$Y)
  # Get the first 10 rownames and colnames, and print it to file as sanity check
  logging_head_names(X=X, n = 10)
  # Also get the dimensions, since it sometimes might fail
  message("\nDimension of rows here: ", X |> sapply(nrow))
  message("\nDimension of cols here: ", X |> sapply(ncol))

  # Runs the cv 
  cv_out <- rgcca_cv(
    blocks = rgcca_input, response = length(rgcca_input),
    par_type = par_type,
    prediction_model = prediction_model,
    validation = validation,
    k = nfolds, n_run = reps, metric = metric)
  
  # Plot cv result
  par(mar=c(1,1,1,1))
  getPlotDevice(name = paste0(method, "_cv_plot"), dataset_name=dataset_name, 
                height=8, width=8, device="svg")
  plot(cv_out)
  dev.off()
  


  # Then fit rgcca on the cv_out
  fit <- rgcca(cv_out)
  
  # Get stable variables out
  stab <- rgcca_stability(fit)
  
  
  # Now wrangle this to dataframe for downstream usage
  feats_df <- stab$top %>%
    as.data.frame() %>% 
    rownames_to_column(var="feature") %>%
    # Drops na, since the response gets added into the var list
    filter(!is.na( !!sym ( criteria_order) ))  %>%
    # Add metadata in for downstream merge
    mutate(
      method = method, 
      dataset_name = dataset_name
    ) %>%
    dplyr::rename(view = block) %>%
    # Remap the view name since it changed to number from rgcca
    mutate(view = purrr::map_chr(view, ~ view_names[.x])) %>%
    group_by(view) %>%
    # Sort the top value
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
  prediction_model = opt$prediction_model, metric=opt$metric)



