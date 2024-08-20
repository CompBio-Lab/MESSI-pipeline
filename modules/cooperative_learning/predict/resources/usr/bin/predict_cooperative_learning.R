#!/usr/bin/env Rscript

# Script to predict cooperative learning (simulate now)
doc <- "This script is to make predictions on test data of particular fold, 
using a model trained with cooperative learning method from multiview package

Output type is a path containing the predicted probabilities

Usage:
  predict_cooperative_learning.R [options]

Options:
  --model_path=MODEL_PATH   Path to read the model [default: null]
  --test_path=TEST_PATH     Path containing test data [default: null]
  --label=LABEL             Label of id and fold of data [default: data-fold_i]
  --method_name=METHOD      Method name input from upstream [default: empty]
  --output_ext=EXT          Extension of output table to save [default: csv]
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
# Default to use AveragedPredict and max.dist
main <- function(model_path, test_path, label, output_ext, method_name, 
                 s=0.005, type="response", digit=3) {

  if (method_name == "empty") {
    stop("You did not provide method name")
  }
  # Load test data (from same fold test portion)
  test_data <- readRDS(test_path)
  cat("\nRead model from", model_path, "\n")
  cat("\nRead test data from", test_path, "\n")
  # Load model (from same fold train portion)
  model <- readRDS(model_path)
  # TODO: NEED a better way to handle this
  # Check if model is of cv object or not
  # When its cv
  if ("cv.multivew" %in% class(model)) {
    cat("\nReceived internal CV model, using lambda.1se")
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
  
  # Write to files
  cat("\nSaving as", output_ext, "format\n")
  result_file <- paste(label, paste0("result_table", ".", output_ext), sep="-")
  # Save to disk
  write.csv(result_table, result_file, row.names = FALSE)
  return(pred_probs)
}


# Call the function here
main(model_path=opt$model_path, 
     test_path=opt$test_path, 
     label=opt$label,
     output_ext=opt$output_ext,
     method_name=opt$method_name
)

cat("Done")