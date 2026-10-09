#!/usr/bin/env Rscript

# Script to run mofa predictions
doc <- "This script is to make predictions on test data of particular fold, 
using a model trained with MOFA from MOFA2 package and its embeddings with glmnet.

Output type is a path containing the predicted probabilities

Usage:
  predict_mofa.R [options]

Options:
  --model_path=MODEL_PATH   Path to read the model [default: null]
  --test_path=TEST_PATH     Path containing test data [default: null]
  --label=LABEL             Label of id and fold of data [default: data-fold_i]
  --output_ext=EXT          Extension of output table to save [default: csv]
  --outcome_type=TYPE       Outcome type to PREDICT from. One of 'classification' or 'survival'. [default: classification]
"

library(here)
library(MOFA2)
library(glmnet)
library(magrittr)
library(dplyr)
# Load script

# Gather the pipeline dir (THIS IS VERY UGGLY FIX)
bin_dir <- Sys.getenv("PATH") |> 
  strsplit(":") |>
  unlist() |>
  tail(1)
pipeline_dir <- gsub("/bin", "", bin_dir)

source(here(pipeline_dir, "bin/wrangling/get_result_table.R"))
# Parse docopt
opt <- docopt::docopt(doc)


# Fun for classification
predict_classification <- function(model_path, test_path, label, method_name, digit, s=0) {
    # Load model (from same fold train portion)
  model <- readRDS(model_path)
  # Load test data (from same fold test portion)
  test_data <- readRDS(test_path) # NOTE here data is n x p
  test_x <- test_data$X$embeddings
  print(test_x)
  # Then make predictions using the previous glmnet model
  predictions <- stats::predict(
    object=model,
    s = s,
    newx = test_x,
    type = "response"
    ) |> as.numeric()
  # Join this intermediate result pred prob of P(Y=1)
  
  pred_probs <- data.frame(sample_name = rownames(test_x), phat = predictions)
  # Merge to summary table
  # matching by sample names inside the data
  result_table <- get_result_table(probs=pred_probs, label=label, 
                                  method_name=method_name, 
                                  test_data=test_data, digit=digit
                                  )
  return(result_table)
}

# Survival: risk score and S(t) at the horizons from the coxnet model.
# To be comparable with the sksurv methods (sksurv_predict.py), the output:
#   - lp is the linear predictor, higher = riskier
#   - S(t) at the same horizons (days), NA after the last train event
#     (both handled by baseline_surv from run_mofa.R)
#   - has the same columns: sample_name, lp, surv_<t>, time, status,
#     method_name, dataset, fold
predict_survival <- function(model_path, test_path, label, method_name, digit, s="lambda.min") {
  # Load model (from same fold train portion)
  model <- readRDS(model_path)
  # Load test data (from same fold test portion)
  test_data <- readRDS(test_path) # NOTE here data is n x p
  test_x <- as.matrix(test_data$X$embeddings)
  # Risk score, lambda chosen by inner CV in run_mofa.R
  beta <- coef(model$cvfit, s = s)

  message("test_x: ", paste(dim(test_x), collapse = " x "))
  message("beta:   ", paste(dim(beta), collapse = " x "))

  stopifnot(ncol(test_x) == nrow(beta))

  message("Predicting survival on test data with lambda = ", s)
  lp <- stats::predict(model$cvfit, newx = test_x, s = s,
                       type = "link") |> as.numeric()

  # Cox model: S(t | x) = S0(t) ^ exp(lp), S0 estimated on the train fold
  surv <- outer(exp(lp), model$baseline_surv, function(r, s0) s0 ^ r)

  # Result table, dataset and fold parsed from the label (dataset-..fold_i..)
  result_table <- data.frame(sample_name = rownames(test_x), lp = round(lp, digit))
  for (h in names(model$baseline_surv)) {
    result_table[[paste0("surv_", h)]] <- round(surv[, h], digit)
  }
  # And wrangle here
  result_table$time <- test_data$Y$time
  result_table$status <- test_data$Y$status
  result_table$method_name <- method_name
  result_table$dataset <- sub("-[^-]*fold_[0-9]+.*$", "", label)
  result_table$fold <- regmatches(label, regexpr("fold_[0-9]+", label))
  # Return it out
  return(result_table)
}



main <- function(model_path, test_path, label, output_ext, outcome_type="classification", method_name="mofa",
                digit = 3, s = 0) {
  
  # Init result table to be empty
  result_table <- data.frame()

  if (outcome_type == "classification") {
    result_table <- predict_classification(
      model_path=model_path, test_path=test_path, 
      label=label, method_name=method_name, digit=digit, s=s
    )
  } else if (outcome_type == "survival") {
    s <- "lambda.min" # Coerce it to use lambda min, survival always runs on cv glmnet
    result_table <- predict_survival(
      model_path=model_path, test_path=test_path, 
      label=label, method_name=method_name, digit=digit, s=s
    )
  } else {
    stop("Unsupported outcome_type: ", outcome_type,
         ". Expected 'classification' or 'survival'.",
         call. = FALSE)
  }



  # Write to files
  cat("\nSaving as", output_ext, "format\n")
  result_file <- paste(label, paste0("result_table", ".", output_ext), sep="-")
  # Save to disk
  write.csv(result_table, result_file, row.names = FALSE)
  return(result_table)
}


# Call the function here
main(model_path=opt$model_path, 
     test_path=opt$test_path, 
     label=opt$label,
     outcome_type=opt$outcome_type,
     output_ext=opt$output_ext
     )

cat("Done")