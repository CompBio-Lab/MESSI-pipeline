#!/usr/bin/env Rscript

# Script to predict cooperative learning (simulate now)
doc <- "This script is to make predictions on test data of particular fold, 
using a model trained with any method from RGCCA package

Output type is a path containing the predicted probabilities

Usage:
  predict_rgcca.R [options]

Options:
  --model_path=MODEL_PATH   Path to read the model [default: null]
  --test_path=TEST_PATH     Path containing test data [default: null]
  --label=LABEL             Label of id and fold of data [default: data-fold_i]
  --method=METHOD           Method name input from upstream [default: empty]
  --output_ext=EXT          Extension of output table to save [default: csv]
"

# Helper fun to move later
parse_rgcca_test <- function(test_data) {
  # Given the test data, we need to reconvert this back to X and Y
  
  # Note the last element is the response
  n <- length(test_data)
  # Get the X and Y respectively
  X <- test_data[1:n-1]
  Y <- test_data[[n]]
  # Put these together
  parsed_test_data <- list(X=X, Y=Y)
  return(parsed_test_data)
}

parse_response_col <- function(data, col) {
  # Need to get the factor of the last element (response) of data
  n <- length(data)
  response <- data[[n]]
  if ("yes" %in% levels(response)) {
    suffix <- "yes"
  } else {
    suffix <- "X1"
  }
  output <- paste0(col, ".", suffix)
  return(output)
}


# Load libraries
library(RGCCA)
library(magrittr)
library(dplyr)
# Source scripts
source(here::here("bin/wrangling/get_result_table.R"))
# Parse docopt
opt <- docopt::docopt(doc)
# Default to use AveragedPredict and max.dist
main <- function(model_path, test_path, label, output_ext, method, 
                 prediction_model="glm", response_col="response", digit=3) {

  if (method == "empty") {
    stop("You did not provide method name")
  }
  # Load test data (from same fold test portion)
  test_data <- readRDS(test_path)
  # Load model (from same fold train portion)
  model <- readRDS(model_path)
  # Verbose input
  message("\nRead model from ", model_path, "\n")
  message("\nRead test data from ", test_path, "\n")
  # TODO: NEED a better way to handle this
  # Predict and get result
  pred_obj <- rgcca_predict(model, blocks_test = test_data, prediction_model = prediction_model)
  # Need some parsing here
  response_col <- parse_response_col(test_data, response_col)
  pred_probs <- pred_obj$probs$test |>
              select(response_col) |>
              rename(phat=response_col)  |>             
              tibble::rownames_to_column(var="sample_name") |>
              tibble::as_tibble()
  # Also need to reparse the test data to suitable format
  test_data <- parse_rgcca_test(test_data)
  # Then make some changes to our test data back to the format of X and Y
  # Merge to summary table
  result_table <- get_result_table(probs=pred_probs, label=label, 
                                  method_name=method,
                                  test_data=test_data, digit=digit
                                  )
  
  # Write to files
  message("\nSaving as ", output_ext, " format\n")
  result_file <- paste(label, paste0("result_table", ".", output_ext), sep="-")
  # Save to disk
  write.csv(result_table, result_file, row.names = FALSE)
  return(pred_obj)
}


# Call the function here
main(model_path=opt$model_path, 
     test_path=opt$test_path, 
     label=opt$label,
     output_ext=opt$output_ext,
     method=opt$method
)

message("Done")