#!/usr/bin/env Rscript

doc <- "This script is for running feature selection on MOFA, provided option to
run cross validation on glmnet to find which factors to look at

Usage:
  mofa_select_features.R [options]

Options:
  --mae_path=MAE_PATH         Path to read the full data in
  --dataset_name=DNAME        Dataset name used as identification
  --output_ext=EXT            Extension of output table to save [default: csv]
  --num_factors=NUM_FACTORS   Number of factors [default: 1]
"
# Parse cli docs
opt <- docopt::docopt(doc)

# Load libraries
library(MOFA2)
library(MultiAssayExperiment)
library(here)
library(dplyr)

# Python related
default_python <- "/usr/bin/python"
reticulate::use_python(default_python)

# Fun to prepare mofa object for training
mofa_pre <- function(
  mae,
  num_factors,
  seed,
  scale_views = FALSE
) {
  mofa_obj <- create_mofa(mae)

  # Data options
  data_opts <- get_default_data_options(mofa_obj)
  data_opts$scale_views <- scale_views

  # Model options
  model_opts <- get_default_model_options(mofa_obj)
  model_opts$num_factors <- num_factors

  # Training options
  train_opts <- get_default_training_options(mofa_obj)
  train_opts$seed <- seed

  prepared_obj <- prepare_mofa(
    object = mofa_obj,
    data_options = data_opts,
    model_options = model_opts,
    training_options = train_opts
  )

  return(list(
    object = prepared_obj,
    data_options = data_opts,
    model_options = model_opts,
    training_options = train_opts
  ))
}


get_seed <- function(dataset_name) {
  d_int <- utf8ToInt(dataset_name) # Convert dataset name to integer
  seed  <- sum(d_int)
  message("\nSeed used:  ", seed)
  return(seed)
}

tag_mofa_options <- function(options, prefix, treatment_overrides = NULL) {
  tagged <- lapply(names(options), function(option_name) {
    treatment <- "default"

    if (
      !is.null(treatment_overrides) &&
      option_name %in% names(treatment_overrides)
    ) {
      treatment <- unname(treatment_overrides[[option_name]])
    }

    list(
      value = options[[option_name]],
      treatment = treatment
    )
  })

  names(tagged) <- paste(prefix, names(options), sep = ".")
  return(tagged)
}


write_selected_hyperparameters <- function(
  dataset_name,
  data_options,
  model_options,
  training_options,
  method = "mofa"
) {
  data_parameters <- tag_mofa_options(
    options = data_options,
    prefix = "data",
    treatment_overrides = c(
      scale_views = "fixed",
      views = "data-derived",
      groups = "data-derived"
    )
  )

  model_parameters <- tag_mofa_options(
    options = model_options,
    prefix = "model",
    treatment_overrides = c(
      num_factors = "fixed"
    )
  )

  training_parameters <- tag_mofa_options(
    options = training_options,
    prefix = "training",
    treatment_overrides = c(
      seed = "data-derived"
    )
  )

  result <- list(
    schema_version = "1.0",
    run_id = paste(method, dataset_name, sep = "-"),
    dataset = dataset_name,
    method = method,
    analysis_stage = "model_selection",
    selection = list(
      strategy = "fixed_configuration",
      hyperparameter_tuning = FALSE
    ),
    parameters = c(
      data_parameters,
      model_parameters,
      training_parameters
    )
  )

  output_file <- paste0(
    method,
    "-",
    dataset_name,
    "_selected_hyperparameters.json"
  )

  jsonlite::write_json(
    x = result,
    path = output_file,
    pretty = TRUE,
    auto_unbox = TRUE,
    null = "null",
    na = "null"
  )

  message("\nSelected hyperparameters written to: ", output_file)

  return(output_file)
}



# Main entrypoint here
main <- function(mae_path, dataset_name, num_factors,
                 scale_views=FALSE, method="mofa") {
  # ============================================================================
  seed <- get_seed(dataset_name) # Get seed for reproducibility, this is important for mofa training and cv
  set.seed(seed)
  raw_mae <- loadHDF5MultiAssayExperiment(mae_path)
  # Then starting to use mofa here
  # TODO: add options into scale view or scale anything
  mofa_setup <- mofa_pre(
    mae = raw_mae,
    num_factors = num_factors,
    seed = seed,
    scale_views = scale_views
  )

  mofa_obj <- mofa_setup$object
  # Then train on the mofa obj
  mofa_emb_file <- paste(
    paste(method, dataset_name, sep="-"), "emb.hdf5", sep="_"
  )
  mofa_emb <- run_mofa(mofa_obj, outfile = mofa_emb_file)
  
  # TODO: use some kind of cv later to determine which factors to use in 
  # getting features, like getting factor level from glmnet cv lasso
  # For each factor in factor level and view get top n percent ?

  #ddd <- get_weights(mofa_emb, as.data.frame=T)
  #write.csv(ddd, file=paste0(paste("dummy", method, dataset_name, sep="-"), ".csv"), row.names=FALSE)
  factor_levels = c("Factor1", "Factor2")
  feats_df <- get_weights(mofa_emb, as.data.frame = T) %>%
    filter(factor %in% factor_levels) %>%
    # Add metadata for downstream usage
    mutate(method = method, dataset_name = dataset_name) %>%
    # Add factor inside view to tell which factor feature correspond to
    mutate(view = paste0(view, "-", factor)) %>%
    dplyr::rename(coef = value) %>%
    select(feature, view, coef, method, dataset_name) 
    
    # ===============================================
    # Staled code for select top n percent
    #group_by(view) %>%
    # This takes top n percent of each view
    #group_modify(
    #  ~ slice_head(
    #    .x, n = round(n_percent * nrow(.x) / 100, digits=0)
    #  )
    #) %>% 
    #ungroup()
  
  # write it to disk
  feats_file <- paste0(method, "-", dataset_name, "_", "features_selected", ".csv")
  write.csv(x=feats_df, file=feats_file, row.names=FALSE)
  # And the hyperparams part
  write_selected_hyperparameters(
    dataset_name = dataset_name,
    data_options = mofa_setup$data_options,
    model_options = mofa_setup$model_options,
    training_options = mofa_setup$training_options,
    method = method
  )
  
  return(feats_df)
}

# Call the main function here
main(
  mae_path=opt$mae_path, 
  dataset_name=opt$dataset_name,
  num_factors=as.numeric(opt$num_factors)
)
# Exit with message
message("\nDone")