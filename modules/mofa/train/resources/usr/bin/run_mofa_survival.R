#!/usr/bin/env Rscript
# Survival variant of MOFA training (task = "survival").
# Reads the train fold of the MAE, fits the mofa survival model, saves
# model RDS + test_data RDS (same conventions as the classification scripts).
doc <- "Train mofa survival model.
Usage:
  run_mofa_survival.R [options]
Options:
  --mae_path=MAE_PATH     Path to the train-fold MAE directory
  --label=LABEL           Dataset-fold label
  --fold_path=FOLD_PATH   Path to the fold directory (contains train/test prefixes)
  --prefix=PREFIX         HDF5 prefix [default: pre]
"
opt <- docopt::docopt(doc)
pipeline_dir <- gsub("/bin", "", (Sys.getenv("PATH") |> strsplit(":") |> unlist() |> tail(1)))
# Load scripts ========================================================
source(here(pipeline_dir, "bin/rhelpers.R")) # This is included in nextflow bin path
# Loading generic utils
load_utils(here(pipeline_dir, "bin/logging"))
load_utils(here(pipeline_dir, "bin/preprocessing"))
load_utils(here(pipeline_dir, "bin/misc_utils"))



get_seed <- function(dataset_name) {
  d_int <- utf8ToInt(dataset_name) # Convert dataset name to integer
  seed  <- sum(d_int)
  message("\nSeed used:  ", seed)
  return(seed)
}

# Main function to run
main <- function(mae_path, label, fold_path, run_inner_cv, prefix) {
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
  train_data <- load_MAE(train_path, prefix="train") |> extract_Xy()
  test_data <- load_MAE(test_path, prefix="test") |> extract_Xy()
  sample_names <- check_common_samples(train_data)
  cat("\nTotal of", length(sample_names), "samples:\n", sample_names)
  
  # Filenames to write out
  model_file <-  paste(label, "mofa_cox_survival_model.rds", sep="-") 
  test_file  <-  paste(label, "mofa_cox_survival_test_data.rds", sep="-")

  # Train a model to run inner cv or not
  if (run_inner_cv) {
    message("\nThe inner CV option in each fold is not implemented for MOFA survival yet\n")
    #---------------------------------------------------------------------------
  } else {
    message("\nNot running inner cv per fold\n")
    # The input data are already MOFA embeddings, so we can directly use them to fit a glmnet model for survival
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

    # Glmnet model (ACTUALLY using this to predict)
    model <- glmnet(
      x = train_x,
      y = train_y,
      family = "cox"
    )
  }
  # =========================================
  message("\nSaving files to", label, "\n")
  # Write out to disk
  # Saving the test data for later use
  # The mofa model hdf5 is saved once its training is done
  saveRDS(object = test_data, file=test_file)
  saveRDS(object = model, file=model_file)

  model_file <- paste(opt$label, "mofa_cox_survival_model.rds", sep = "-")
  test_file  <- paste(opt$label, paste0("mofa_cox_survival_test_data.rds"), sep = "-")
  saveRDS(model, model_file)
  saveRDS(list(blocks = d_tr$blocks, time = d_tr$time, status = d_tr$status,
              test_mae_path = test_path), test_file)
  cat("Saved", model_file, "and", test_file, "\n")

  return(model)
}
# Call the function here
main(mae_path  = opt$mae_path,
     label     = opt$label,
     fold_path = opt$fold_path,
     prefix    = opt$prefix,
     run_inner_cv  = opt$run_inner_cv
)
cat("Done") 


train_survival_mofa <- function(blocks, y, n_factors = 10) {
  reticulate::use_virtualenv("/workspace/.venv", required = FALSE)
  blocks_t <- lapply(blocks, t)  # MOFA2 expects features x samples
  mofa <- MOFA2::create_mofa(blocks_t)
  data_opts <- MOFA2::get_default_data_options(mofa)
  model_opts <- MOFA2::get_default_model_options(mofa)
  model_opts$num_factors <- n_factors
  train_opts <- MOFA2::get_default_training_options(mofa)
  train_opts$maxiter <- 1000
  mofa <- MOFA2::prepare_mofa(mofa, data_options = data_opts,
                              model_options = model_opts, training_options = train_opts)
  model <- MOFA2::run_mofa(mofa, outfile = tempfile(fileext = ".hdf5"))
  Z <- MOFA2::get_factors(model, factors = "all")[[1]]
  fit <- glmnet::cv.glmnet(as.matrix(Z), Surv(y$time, y$status), family = "cox", alpha = 0.5)
  # Per-factor linear calibration for manual projection of new data
  calib <- lapply(seq_len(ncol(Z)), function(j) lm(Z[, j] ~ 0)$coef)
  feat_means <- lapply(blocks, colMeans)
  W <- MOFA2::get_weights(model)
  list(method = "mofa_cox", model = model, fit = fit, calib = calib,
       feat_means = feat_means, W = W, factor_names = colnames(Z))
}
