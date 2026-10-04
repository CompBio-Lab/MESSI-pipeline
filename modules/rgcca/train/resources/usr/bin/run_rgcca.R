#!/usr/bin/env Rscript

# Script to run Diablo (simulate now)
doc <- "This script is to run RGCCA method from RGCCA package, train only.
It could possibly be ran on a inner CV model, output is a model for prediction
usage in downstream.

classification: supervised RGCCA with the response as the last block, predicted
                later by rgcca_predict.
survival:       unsupervised RGCCA on the omics blocks of the train fold, train
                and test are transformed into its components and a coxnet
                (cv.glmnet cox) is fitted on the train components.

Usage:
  run_rgcca.R [options]

Options:
  --mae_path=MAE_PATH     Path to read full mae data
  --label=LABEL           Label of id and fold of data [default: data]
  --fold_path=FOLD_PATH   Path to read current test fold
  --inner_cv              Run inner cv with train data or not [default: false]
  --prefix=PREFIX         Prefix to read HDF5 [default: pre]
  --method=METHOD         RGCCA method to run [default: rgcca]
  --design=DESIGN	        Connection matrix of omics, one of full or null [default: full]
  --ncomp=NCOMP           Number of component to run diablo [default: 2]
  --outcome_type=TYPE     classification or survival [default: classification]
  --time_col=TIME_COL     colData column of survival time [default: time]
  --status_col=STAT_COL   colData column of event indicator [default: status]
"


# Load libraries
library(RGCCA)
library(dplyr)
library(here)
library(MultiAssayExperiment)
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
# Load specific util
rp <- resource_helper_path(here(pipeline_dir, "modules/rgcca/train"))
source(here(rp, "parse_rgcca_input.R"))
# Parase docopt
opt <- docopt::docopt(doc)

get_seed <- function(dataset_name) {
  d_int <- utf8ToInt(dataset_name) # Convert dataset name to integer
  seed  <- sum(d_int)
  message("\nSeed used:  ", seed)
  return(seed)
}

get_connection <- function(design, J) {
  if (design == "full") {
    # Full means 1 everywhere not of diagonal, meaning every omics
    # is related with other
    message("\nUsing full design, diagonal 0, 1 everywhere else")
    connection <- 1 - diag(J)
  } else if (design == "null") {
    # Everywhere 0 except diagonal, meaning only associate to itself
    message("\nUsing null design, diagonal 1, 0 everywhere else")
    connection <- diag(J)
  } else {
    message("\nProvide another design, one of 'full' or 'null'")
    message("\nCoerced connection to NULL now")
    connection <- NULL
  }
  return(connection)
}

train_classification <- function(train_data, test_data, tau, connection, method, ncomp, scheme, outcome_type) {
  # These input objects are for rgcca internally usage only
  train_input <- train_data |>
                parse_rgcca_input(outcome_type=outcome_type)
  test_input <- test_data |>
                parse_rgcca_input(outcome_type=outcome_type)

  # TODO: THIS IS VERY UGGLY FIX, that need to force coerce the data into factor
  train_input$response <- as.factor(train_input$response)
  test_input$response <- as.factor(test_input$response)
  
  rgcca_model <- rgcca(train_input, tau=tau, connection=connection, 
                   method=method, response=length(train_input), ncomp=ncomp,
                   scheme=scheme
                   )
  result <- list(model=rgcca_model, test_data=test_input)
  return(result)
}

train_survival <- function(train_data, test_data, tau, connection, method, ncomp,scheme, outcome_type) {
  # These input objects are for rgcca internally usage only
  train_input <- train_data |>
                parse_rgcca_input(outcome_type=outcome_type)
  test_input <- test_data |>
                parse_rgcca_input(outcome_type=outcome_type)
  
  rgcca_model <- rgcca(
    train_input, tau=tau, connection=connection, 
    method=method, response=NULL, ncomp=ncomp,
    scheme=scheme
  )
  
  # Same transformation for train and test (uses the train scaling)
  train_z <- do.call(
    cbind,
    RGCCA::rgcca_transform(rgcca_model, train_input)
  )
  test_z <- do.call(
    cbind,
    RGCCA::rgcca_transform(rgcca_model, train_input)
  )
  # cv.glmnet always tunes lambda by inner CV on the train fold
  coxnet <- glmnet::cv.glmnet(train_z, survival::Surv(train_data$Y$time, train_data$Y$status),
                    family = "cox", alpha = 1)
  model <- list(outcome_type = "survival", method = method, ncomp = ncomp,
                rgcca = rgcca_model, coxnet = coxnet)
  test_output <- list(X = test_z, time = test_data$Y$time, status = test_data$Y$status)
  result <- list(model = model, test_data = test_output)
  return(result)
}

# Main function to run
main <- function(mae_path, label, fold_path, inner_cv, prefix, method, design, ncomp=2, tau=1, outcome_type="classification") {
  seed <- get_seed(label) # Set seed based on dataset name, so that the result is reproducible
  set.seed(seed)
  # Log the params used
  args_used <- c(as.list(environment()))
  logging_params(args_used)
  cat("\nLooking at this fold:", fold_path, "\n")
  d <- list.files(path=fold_path, full.names = TRUE)
  train_path <- d[str_detect(d, pattern = "_tr")]
  test_path <- d[str_detect(d, pattern = "_te")]
  # Then should read in the MAE and convert it to list of X and Y
  # A little bit more special when reading in data, we get the X and Y altogether
  train_data <- load_MAE(train_path, prefix="train") |> 
                extract_Xy(outcome_type=outcome_type)
  test_data <- load_MAE(test_path, prefix="test") |> 
                extract_Xy(outcome_type=outcome_type)
  
  
  # Set scheme to horst for same comparison with diablo
  scheme <- "horst"

  # Also make up the connection matrix based on the design chosen
  # one of full or null
  # This is number of omics including the response block, so H + 1
  # For survival, the response block is not included in the connection matrix, so J = H
  if (outcome_type == "classification") {
    J <- length(train_data$X) + 1
  } else if (outcome_type == "survival") {
    J <- length(train_data$X)
  }
  # Set up the connection matrix
  connection <- get_connection(design, J)
  # Train a modelel modele to run inner cv or not
  if (inner_cv) {
    cat("\nTraining with inner cv per single fold, this could take more time\n")
    message("\nNot implemented inner cv yet\n")
    model <- "A"
  } else {
    message("\nNot running inner cv per fold\n")
    # use default settings
    # The response block is always set at the end of the list of data
    if (outcome_type == "classification") {
      message("\nRunning supervised RGCCA with response block\n")
      result <- train_classification(train_data, test_data, tau, connection, method, ncomp, scheme, outcome_type)
    } else if (outcome_type == "survival") {
      message("\nRunning unsupervised RGCCA without response block\n")
      result <- train_survival(train_data, test_data, tau, connection, method, ncomp, scheme, outcome_type)
    }
    message("\nFitted model\n")
  }

  # Filenames to write out
  model_file <- paste(label, paste(method, design,"model.rds", sep="_"), sep="-")
  test_file <- paste(label, paste0(method, "_test_data.rds"), sep="-")
  cat("\nSaving files to", label, "\n")
  # Write out to disk
  saveRDS(object = result$model, model_file)
  saveRDS(object = result$test_data, test_file)
  return(result$model)
}
# Call the function here
main(mae_path  = opt$mae_path,
     label     = opt$label,
     fold_path = opt$fold_path,
     inner_cv  = opt$inner_cv,
     prefix    = opt$prefix,
     method    = opt$method,
     design    = opt$design,
     ncomp     = as.numeric(opt$ncomp),
     outcome_type = opt$outcome_type
     )

message("Done")

