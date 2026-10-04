#!/usr/bin/env Rscript

# Script to predict cooperative learning
doc <- "This script is to make predictions on test data of particular fold,
using a model trained with cooperative learning method from multiview package

classification: output table has the predicted probabilities (phat)
survival:       output table has the risk score (lp) and S(t) at the horizons,
                same format as the Python sksurv methods

Usage:
  predict_cooperative_learning.R [options]

Options:
  --model_path=MODEL_PATH   Path to read the model [default: null]
  --test_path=TEST_PATH     Path containing test data [default: null]
  --label=LABEL             Label of id and fold of data [default: data-fold_i]
  --method_name=METHOD      Method name input from upstream [default: empty]
  --output_ext=EXT          Extension of output table to save [default: csv]
  --outcome_type=TYPE       classification or survival [default: classification]
"
library(multiview)
library(magrittr)
library(dplyr)
# Gather the pipeline dir (THIS IS VERY UGGLY FIX)
bin_dir <- Sys.getenv("PATH") |> 
  strsplit(":") |>
  unlist() |>
  tail(1)
pipeline_dir <- gsub("/bin", "", bin_dir)
# Source scripts
source(here::here(pipeline_dir, "bin/wrangling/get_result_table.R"))
# Parse docopt
opt <- docopt::docopt(doc)



# Classification: predicted probability of the positive class
predict_classification <- function(model_path, test_path, label, method_name, type="response", digit=3,s=0.005) {
  # Load model (from same fold train portion)
  model <- readRDS(model_path)
  test_data <- readRDS(test_path)
  # TODO: NEED a better way to handle this
  # Check if model is of cv object or not
  # When its cv
  if ("cv.multiview" %in% class(model)) {
    message("\nReceived internal CV model, using lambda.1se")
    s <- "lambda.1se"
  }
  # Predict and get result
  pred_probs <- predict(model, newx = test_data$X, s=s, type=type) %>%
                as.data.frame() %>% 
                tibble::rownames_to_column(var="sample_name") %>%
                dplyr::rename(phat = s1)
  # Merge to summary table
  result_table <- get_result_table(probs=pred_probs, label=label, 
                                  method_name=method_name, 
                                  test_data=test_data, digit=digit
                                  )
  return(result_table)
}

# Survival: risk score and S(t) at the horizons from the multiview cox model.
# To be comparable with the sksurv methods (sksurv_predict.py), the output:
#   - lp is the linear predictor, higher = riskier
#   - S(t) at the same horizons (days), NA after the last train event
#     (both handled by baseline_surv from run_cooperative_learning.R)
#   - has the same columns: sample_name, lp, surv_<t>, time, status,
#     method_name, dataset, fold

predict_survival <- function(model_path, test_path, label, method_name, digit=3, type="link") {
  # Load model (from same fold train portion)
  model <- readRDS(model_path)
  test_data <- readRDS(test_path)
  message("\nRead model from", model_path, "\n")
  message("\nRead test data from", test_path, "\n")

  # Risk score, lambda chosen by inner CV in run_cooperative_learning.R
  lp <- predict(model$cvfit, newx = test_data$X, s = "lambda.min",
                type = type) |> as.numeric()
   # Cox model: S(t | x) = S0(t) ^ exp(lp), S0 estimated on the train fold
  surv <- outer(exp(lp), model$baseline_surv, function(r, s0) s0 ^ r)
    # Result table, dataset and fold parsed from the label (dataset-..fold_i..)
  result_table <- data.frame(sample_name = rownames(test_data$X[[1]]),
                             lp = lp)
  for (h in names(model$baseline_surv)) {
    result_table[[paste0("surv_", h)]] <- surv[, h]
  }
  result_table$time <- test_data$Y$time
  result_table$status <- test_data$Y$status
  result_table$method_name <- method_name
  result_table$dataset <- sub("-[^-]*fold_[0-9]+.*$", "", label)
  result_table$fold <- regmatches(label, regexpr("fold_[0-9]+", label))
  return(result_table)

}
# Default to use AveragedPredict and max.dist
main <- function(model_path, test_path, label, output_ext, method_name, 
                 s=0.005, outcome_type="classification", type="response", digit=3) {

  if (method_name == "empty") {
    stop("You did not provide method name")
  }
  # Load test data (from same fold test portion)

  message("\nRead model from", model_path, "\n")
  message("\nRead test data from", test_path, "\n")
  
  if (outcome_type == "classification") {
    message("\nPredicting classification\n")
    
    result_table <- predict_classification(
      model_path = model_path,
      test_path = test_path,
      label = label,
      method_name = method_name,
      type = type,
      digit = digit,
      s = s
    )
  } else if (outcome_type == "survival") {
    message("\nPredicting survival\n")
    
    # For survival let s = lambda.min    
    result_table <- predict_survival(
      model_path = model_path,
      test_path = test_path,
      label = label,
      method_name = method_name,
      digit = digit
    )

  } else {
    stop("Unknown outcome type: ", outcome_type)
  }
  # Write to files
  message("\nSaving as", output_ext, "format\n")
  result_file <- paste(label, paste0("result_table", ".", output_ext), sep="-")
  # Save to disk
  write.csv(result_table, result_file, row.names = FALSE)
  return(result_table)
}


# Call the function here
main(model_path=opt$model_path, 
     test_path=opt$test_path, 
     label=opt$label,
     output_ext=opt$output_ext,
     method_name=opt$method_name,
     outcome_type=opt$outcome_type
)

message("Done")
