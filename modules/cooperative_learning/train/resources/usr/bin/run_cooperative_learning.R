#!/usr/bin/env Rscript

# Script to run cooperative learning (simulate now)
doc <- "This script is to run cooperative learning method from multiview package,
train only. Tt could possibly be ran on a inner CV model, output is a model for
prediction usage in downstream.

classification: multiview binomial with default lambda path.
survival:       multiview cox, lambda chosen by inner CV (cv.multiview) on the
                train fold, plus the baseline survival S0(t) at the horizons.

Usage:
  run_cooperative_learning.R [options]

Options:
  --mae_path=MAE_PATH     Path to read full mae data
  --label=LABEL           Label of id and fold of data [default: data]
  --fold_path=FOLD_PATH   Path to read current test fold
  --inner_cv              Run inner cv with train data or not [default: false]
  --prefix=PREFIX         Prefix to read HDF5 [default: pre]
  --rho=RHO               Weight on the agreement penalty, rho=0 is a form of early fusion, and rho=1 is a form of late fusion.  [default: 0.5]
  --alpha=ALPHA           Elastic net mixing param with 0 <= alpha <=1, when 1 = lasso, when 0 ridge. [default: 1]
  --outcome_type=TYPE     classification or survival [default: classification]
  --time_col=TIME_COL     colData column of survival time [default: time]
  --status_col=STAT_COL   colData column of event indicator [default: status]
  --horizons=HORIZONS     Comma separated days to predict S(t) at [default: 365,548,730,1095,1461,1826]
"
# Parase docopt
opt <- docopt::docopt(doc)

# Load libraries
library(multiview)
library(dplyr)
library(here)
library(stringr)

# Gather the pipeline dir (THIS IS VERY UGGLY FIX)
bin_dir <- Sys.getenv("PATH") |> 
  strsplit(":") |>
  unlist() |>
  tail(1)
pipeline_dir <- gsub("/bin", "", bin_dir)

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


run_cplr_classification <- function(train_data, rho, alpha) {
  # use default settings
  model <- multiview(x_list=train_data$X, 
                      y=train_data$Y, 
                      rho=rho, 
                      family=binomial(), 
                      alpha=alpha
                      )
  return(model)
}

# Breslow estimate of the baseline survival S0(t) = S(t | lp = 0) at the horizons:
#   H0(t) = sum over event times t_i <= t of  d_i / sum_{j: t_j >= t_i} exp(lp_j)
#   S0(t) = exp(-H0(t))
# NA after the last event: the curve is flat there, as in sksurv_predict.py
breslow_baseline <- function(lp, time, status, horizons) {
  event_times <- sort(unique(time[status == 1]))
  risk <- exp(lp)
  dH <- sapply(event_times, function(t) sum(status[time == t]) / sum(risk[time >= t]))
  H0 <- cumsum(dH)
  idx <- findInterval(horizons, event_times)
  baseline_surv <- exp(-ifelse(idx == 0, 0, H0[pmax(idx, 1)]))
  baseline_surv[horizons > max(event_times)] <- NA
  names(baseline_surv) <- horizons
  return(baseline_surv)
}




run_cplr_survival <- function(train_data, rho, alpha, horizons) {
  train_x <- train_data$X
  train_y <- train_data$Y
    # glmnet cox rejects time <= 0 (e.g. TCGA patients with 0 days of follow-up):
  # for fitting only, move them to half of the smallest positive time
  train_time <- train_y$time
  if (any(train_time <= 0)) {
    eps <- min(train_time[train_time > 0]) / 2
    message("\n", sum(train_time <= 0), " train samples with time <= 0 set to ", eps)
    train_time <- pmax(train_time, eps)
  }
  # lambda chosen by CV C-index: with rho > 0 the CV partial likelihood deviance
  # of multiview cox increases from the first lambda on, so lambda.min would
  # always be the all-zero model. S(t) stays calibrated since S0 is refitted below
  model <- cv.multiview(x_list = train_x,
                        y = as.matrix(train_y),
                        family = "cox", rho = rho, alpha = alpha,
                        type.measure = "C")
  coefs <- coef(model, s = "lambda.min")
  cat("\nFitted model,", sum(coefs != 0), "non-zero coefficients at lambda.min\n")

  # Baseline survival from the train fold, predict then only needs
  # S(t | x) = S0(t) ^ exp(lp)
  train_lp <- as.numeric(predict(model, newx = train_x, s = "lambda.min", type = "link"))
  baseline_surv <- breslow_baseline(train_lp, train_time, train_y$status, horizons)
  message("\nBaseline S0(t) at ", paste(horizons, collapse = ", "), ": ",
          paste(round(baseline_surv, 3), collapse = ", "))

  model <- list(outcome_type = "survival", cvfit = model, baseline_surv = baseline_surv)
  return(model)
}



# This the main function to execute
main <- function(mae_path, label, fold_path, inner_cv, prefix, rho, alpha, outcome_type="classification") {
  seed <- get_seed(label) # Set seed based on dataset name
  set.seed(seed)
  args_used <- c(as.list(environment()))
  logging_params(args_used)
  cat("\nLooking at this fold:", fold_path, "\n")
  d <- list.files(path=fold_path, full.names = TRUE)
  train_path <- d[str_detect(d, pattern = "_tr")]
  test_path <- d[str_detect(d, pattern = "_te")]
  # Then should read in the MAE and convert it to list of X and Y
  train_data <- load_MAE(train_path, prefix="train") |> extract_Xy(outcome_type=outcome_type)
  test_data <- load_MAE(test_path, prefix="test") |> extract_Xy(outcome_type=outcome_type)
  sample_names <- check_common_samples(train_data)
  cat("\nTotal of", length(sample_names), "samples:\n", sample_names)
  # Train a model to run inner cv or not
  # TODO: CALL THE inner cv model instead
  if (inner_cv) {
    cat("\nTraining with inner cv per single fold, this could take more time\n")
    model <- "A"
  } else {
    cat("\nNot running inner cv per fold\n")
    if (outcome_type == "survival") {
      horizons <- c(365,548,730,1095,1461,1826) # Fixed for now
      model <- run_cplr_survival(train_data, rho=rho, alpha=alpha, horizons=horizons)
    } else if (outcome_type == "classification") {
      model <- run_cplr_classification(train_data, rho=rho, alpha=alpha)
    } else {
      stop("Outcome type must be either 'classification' or 'survival'")
    }

    cat("\nFitted model\n")
  }
  # Files names to write out
  model_file <- paste(label, "cooperative_learning_model.rds", sep="-")
  weight_file <-  paste(label, "model_weights.txt", sep="-")
  test_file <- paste(label, "test_data.rds", sep="-")
  cat("\nSaving files to", label, "\n")
  # Write out to disk
  saveRDS(object=model, file=model_file)
  write.table(x=data.frame(a0 = model$a0), file=weight_file)
  saveRDS(object=test_data, file=test_file)
  return(model)  
}

# Call the function here
main(mae_path     = opt$mae_path,
     label        = opt$label,
     fold_path    = opt$fold_path,
     inner_cv     = opt$inner_cv,
     prefix       = opt$prefix,
     rho          = as.numeric(opt$rho),
     alpha        = as.numeric(opt$alpha),
     outcome_type = opt$outcome_type
)