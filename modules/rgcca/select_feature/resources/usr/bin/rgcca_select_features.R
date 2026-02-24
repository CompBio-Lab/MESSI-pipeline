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
  --nfolds=NFOLDS               Number of folds to perform CV to perform feature selection [default: 5]
  --prediction_model=PRED_MOD   Prediction model from caret [default: lda]
  --metric=METRIC               Metric to perform CV on [default: Balanced_Accuracy]
  --design=DESIGN		            Design matrix of the method one of full or null [default: full]
  --ncomp=NCOMP                 Number of component to run diablo [default: 2]
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

# Source custom functions
source(here(pipeline_dir, "bin/rhelpers.R")) # This is included in nextflow bin path
# Loading generic utils from directories
load_utils(here(pipeline_dir, "bin/logging"))
load_utils(here(pipeline_dir, "bin/misc_utils"))
load_utils(here(pipeline_dir, "bin/plotting"))

# ===============================================


# Main entrypoint of the script
# prediction_model should be glm to accord with rest of methods?
# NOTE: par_type should not be sparsity, as it will filter out most features
main <- function(mae_path, dataset_name, ncomp=2, design="full", prediction_model = "lda", par_type="tau", 
                 validation = "kfold", nfolds=5, reps=1, metric="Balanced_Accuracy",
                 criteria_order = "top") {
  # PARAMS
  #method <- "rgcca"
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
  
  # This is number of omics including the response block, so H + 1
  J <- length(rgcca_input)
  # Set up the connection matrix
  if (design == "full") {
    # Full means 1 everywhere not of diagonal, meaning every omics
    # is related with other
    connection <- 1 - diag(J)
  } else if (design == "null") {
    # Everywhere 0 except diagonal, meaning only associate to itself
    connection <- diag(J)
  } else {
    message("\nProvide another design, one of 'full' or 'null'")
    connection <- NULL
  }
 
  # Get the first 10 rownames and colnames, and print it to file as sanity check
  logging_head_names(X=X, n = 10)
  # Also get the dimensions, since it sometimes might fail
  message("\nDimension of rows here: ", X |> sapply(nrow))
  message("\nDimension of cols here: ", X |> sapply(ncol))

  # Runs the cv 
  # RGGCA library requires sparse method to select method at rcgga_stability
  # hence during cv, need to provide the "sgcca" method instead
  cv_out <- rgcca_cv(
    blocks = rgcca_input, response = length(rgcca_input),
    connection = connection,
    method = "sgcca", # This is bit is must, plain RGCCA would not work
    #par_type = par_type,
    tau = 1, # Fix tau 1 for all components so gets non-zero weights for all features
    ncomp = ncomp,
    prediction_model = prediction_model,
    validation = validation,
    k = nfolds, n_run = reps, metric = metric)
  
  # Plot cv result
  par(mar=c(1,1,1,1))
  getPlotDevice(name = paste0(design, "_cv_plot"), dataset_name=dataset_name, 
                height=8, width=8, device="svg")
  plot(cv_out)
  dev.off()
  


  # Then fit rgcca on the cv_out
  fit <- rgcca(cv_out)
  # Extract the block weights from the fit
  # This is the coefficients of the features in each block
  weights_df <- purrr::imap_dfr(fit$a, function(mat, block_name) {
    as.data.frame(mat) |>
      tibble::rownames_to_column(var = "feature") |>
      mutate(view = block_name)
  }) |>
    # Remove the dummy response block
    filter(view != "response") |>
    as_tibble()

  
  
  # Now wrangle this to dataframe for downstream usage
  feats_df <- weights_df %>%
    tidyr::pivot_longer(
      cols = -c("feature", "view"), names_to = "comp", values_to="coef"
    ) %>%
    # Add metadata in for downstream merge
    mutate(
      # While in here, coerce it as RGCCA for downstream processing
      method = paste("rgcca", design, sep="-"), # Method here is always rgcca
      dataset_name = dataset_name,
      # Remove extra characters in comp
      view = paste(view, paste0("ncomp-", stringr::str_remove(comp, "V")), sep="-")
    ) %>%
    select(feature, view, coef, method, dataset_name)
  
  # write it to disk
  # comb_name <- paste(method, design, dataset_name, sep="-") # Method is not required anymore
  # Since method is included inside 'design' object
  comb_name <- paste(design, dataset_name, sep="-")
  feats_file <- paste0(comb_name, "_", "features_selected", ".", "csv")
  write.csv(x=feats_df, file=feats_file, row.names=FALSE)
  return(feats_df)
}

print("Running rgcca_select_features.R with the following parameters:")
# Print the parameters used
logging_params(as.list(opt))


# Then call the function above
main(mae_path = opt$mae_path, dataset_name = opt$dataset_name, 
  nfolds = as.numeric(opt$nfolds),
  prediction_model = opt$prediction_model, metric=opt$metric,
  design = opt$design,
  ncomp = as.numeric(opt$ncomp)
)



