
pred = "AveragedPredict"
dist = "max.dist"
model_path <- here::here("results/train/GSE2/fold_1/GSE2-fold_1-diablo_model.rds")
test_path <- here::here("results/train/GSE2/fold_1/GSE2-fold_1-test_data.rds")
digit = 3
label <- "GSE2-fold_1"
main <- function(model_path, test_path, label, 
                 pred = "AveragedPredict", dist = "max.dist", digit = 3, method_name="diablo") {

  # Parameters
  pred_class <- paste0(pred, ".class")
  # Load model (from same fold train portion)
  model <- readRDS(model_path)
  # Load test data (from same fold test portion)
  test_data <- readRDS(test_path)
  cat("\nRead model from", model_path, "\n")
  cat("\nRead test data from", test_path, "\n")
  # Other parameters to use
  ncomp <- max(model$ncomp) # Take largest number of component
  dim <- paste0("dim", ncomp) # This is the dimension of predicted vals to get
  # Predict and get result by max of ncomp
  pred_obj <- predict(model, newdata = test_data$X)
  # Gather true labels, and predicted labels, probability, weights
  pred_obj[[pred]][, , dim] %>%
    as.data.frame() %>%
    rename(phat = yes)
  
  pred_probs <- pred_obj[[pred]][, , dim] %>%
    as.data.frame() %>%
    tibble::rownames_to_column(var = "sample_name") %>%
    rename(yhat = yes)
  # The coefficient weights
  weights <- pred_obj$weights %>% round(digits = digit)
  # Merge to summary table
  # matching by sample names inside the data
  result_table <- tibble(sample_name = rownames(test_data$X[[1]]),
                         true_y = test_data$Y) %>%
                  full_join(pred_probs,  by = "sample_name") %>%
                  mutate_if(is.numeric, round, digit) %>%
                  # add labels for grouping later
                  mutate(method_name = "diablo", 
                         dataset = sapply(strsplit(label, "-"), head, 1))
  # Write to files
  result_file <- paste(label, "result_table.txt", sep="-")
  weight_file <- paste(label, "block_weight.txt", sep="-")
  # Save to disk
  write.table(result_table, result_file, row.names = FALSE)
  write.table(weights, weight_file)
  return(pred_obj)
}
