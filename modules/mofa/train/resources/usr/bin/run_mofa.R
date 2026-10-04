#!/usr/bin/env Rscript

# Script to run mofa
doc <- "This script is to run MOFA method from MOFA2 package, train only
it could possibly be ran on a inner CV model, output is a modelel for prediction
usage in downstream.

Usage:
  run_mofa.R [options]

Options:
  --mae_path=MAE_PATH     Path to read full mae data
  --label=LABEL           Label of id and fold of data [default: data]
  --fold_path=FOLD_PATH   Path to read current test fold
  --prefix=PREFIX         Prefix to read HDF5 [default: pre]
  --run_inner_cv          Run inner cv with train data or not [default: false]
  --outcome_type=TYPE     classification or survival [default: classification]
  --time_col=TIME_COL     colData column of survival time [default: time]
  --status_col=STAT_COL   colData column of event indicator [default: status]
"

# Load libraries
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(glmnet))
library(here)
suppressPackageStartupMessages(library(MOFA2))
suppressPackageStartupMessages(library(MultiAssayExperiment))
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
# Parase docopt
opt <- docopt::docopt(doc)


get_seed <- function(dataset_name) {
  d_int <- utf8ToInt(dataset_name) # Convert dataset name to integer
  seed  <- sum(d_int)
  message("\nSeed used:  ", seed)
  return(seed)
}



run_survival <- function(train_x, train_y, horizons, alpha=1) {
  # glmnet cox rejects time <= 0 (e.g. TCGA patients with 0 days of follow-up):
  # for fitting only, move them to half of the smallest positive time
  train_time <- train_y$time
  train_status <- train_y$status
  if (any(train_time <= 0)) {
    eps <- min(train_time[train_time > 0]) / 2
    message("\n", sum(train_time <= 0), " train samples with time <= 0 set to ", eps)
    train_time <- pmax(train_time, eps)
  }
  cvfit <- cv.glmnet(train_x, survival::Surv(train_time, train_status),
                    family = "cox", alpha = alpha)
  message("\ncoxnet: ", sum(coef(cvfit, s = "lambda.min") != 0),
          " non-zero coefficients at lambda.min")
  # Baseline survival S0(t) = S(t | lp = 0) at the horizons, estimated on the
  # train fold, so predict_mofa.R only needs S(t | x) = S0(t) ^ exp(lp).
  # NA after the last train event: the curve is flat there, as in sksurv_predict.py
  s0_fit <- survival::survfit(cvfit, s = "lambda.min", x = train_x,
                    y = survival::Surv(train_time, train_y$status),
                    newx = matrix(0, 1, ncol(train_x)))
  idx <- findInterval(horizons, s0_fit$time)
  baseline_surv <- ifelse(idx == 0, 1, s0_fit$surv[pmax(idx, 1)])
  t_max_event <- max(train_time[train_y$status == 1])
  baseline_surv[horizons > t_max_event] <- NA
  names(baseline_surv) <- horizons

  message("\nBaseline S0(t) at ", paste(horizons, collapse = ", "), ": ",
      paste(round(baseline_surv, 3), collapse = ", "))

  model <- list(outcome_type = "survival", cvfit = cvfit, baseline_surv = baseline_surv)
  return(model)
}


# Need to force use python
default_python <- "/usr/bin/python"
reticulate::use_python(default_python)

# Main function to run
main <- function(mae_path, label, fold_path, run_inner_cv, prefix, outcome_type="classification") {
  seed <- get_seed(label) # Get seed for reproducibility, this is important for mofa training and cv
  set.seed(seed)
  # Log the params used
  args_used <- c(as.list(environment()))
  logging_params(args_used)
  cat("\nLooking at this fold:", fold_path, "\n")
  d <- list.files(path=fold_path, full.names = TRUE)
  train_path <- d[str_detect(d, pattern = "_tr")]
  test_path <- d[str_detect(d, pattern = "_te")]
  # Then should read in the MAE
  # When outcome is survival, then the response is a dataframe with time and status columns
  # When outcome is classification, then the response is a factor with 2 levels
  train_data <- load_MAE(train_path, prefix="train") |> extract_Xy(outcome_type=outcome_type)
  message("\nTrain data has ", nrow(train_data$X$embeddings), " samples and ", ncol(train_data$X$embeddings), " features")
  message("\nTrain data has ", length(train_data$Y), " samples in response variable")
  message("\nHead of y is ", train_data$Y |> head())
  test_data <- load_MAE(test_path, prefix="test") |> extract_Xy(outcome_type=outcome_type)
  sample_names <- check_common_samples(train_data)
  cat("\nTotal of", length(sample_names), "samples:\n", sample_names)
  
  # Filenames to write out
  model_file <-  paste(label, "model.rds", sep="-") 
  test_file  <-  paste(label, "test_data.rds", sep="-")

  # Train a modelel modele to run inner cv or not
  if (run_inner_cv) {
    message("\nThe inner CV option in each fold is not implemented for MOFA yet\n")
    #---------------------------------------------------------------------------
  } else {
    message("\nNot running inner cv per fold\n")
  
    train_x <- train_data$X$embeddings
    # Print head of embeddings
    cat( train_x |> head() )
    train_y <- train_data$Y

    # Do an additional check if train_x only has 1 column then add a dummy 0 column
    # to it, since glmnet expect X to be at least N x 2
    if (ncol(train_x) == 1) {
      train_x <- cbind(train_x, dummy_zero=0)
      # Now since adding dummy col, test data needs to be updated too
      test_emb <- as.matrix(test_data$X$embeddings)
      test_emb <- cbind(test_emb, dummy_zero=0)
      test_data$X$embeddings <- test_emb
    } 

    if (outcome_type == "classification") {
        # Glmnet model (ACTUALLY using this to predict)
        model <- glmnet(
          x = train_x,
          y = train_y,
          family = "binomial"
        )
    }

    if (outcome_type == "survival") {
      horizons <- c(365,548,730,1095,1461,1826)
      model <- run_survival(train_x=train_x, train_y=train_y, horizons=horizons)
    }

  }
  # =========================================
  message("\nSaving files to", label, "\n")
  # Write out to disk
  # Saving the test data for later use
  # The mofa model hdf5 is saved once its training is done
  saveRDS(object = test_data, file=test_file)
  saveRDS(object = model, file=model_file)
  return(model)
}
# Call the function here
main(mae_path  = opt$mae_path,
     label     = opt$label,
     fold_path = opt$fold_path,
     prefix    = opt$prefix,
     run_inner_cv  = opt$run_inner_cv,
     outcome_type  = opt$outcome_type
)
cat("Done")