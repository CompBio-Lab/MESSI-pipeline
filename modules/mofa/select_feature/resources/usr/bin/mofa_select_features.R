#!/usr/bin/env Rscript

doc <- "This script is for running feature selection on MOFA, provided option to
run cross validation on glmnet to find which factors to look at

Usage:
  mofa_select_features.R [options]

Options:
  --mae_path=MAE_PATH         Path to read the full data in
  --dataset_name=DNAME        Dataset name used as identification
  --output_ext=EXT            Extension of output table to save [default: csv]
  --n_percent=N_PER           N percent of features to be selected [default: 10]
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
mofa_pre <- function(mae, scale_views=FALSE) {
  # TODO: Could add more options here
  # See https://du-bii.github.io/module-6-Integrative-Bioinformatics/2019/Session2-3/practical_MOFA.html
  mofa_obj <- create_mofa(mae)
  data_opts <- get_default_data_options(mofa_obj)
  # Options of data
  data_opts$scale_views <- scale_views
  
  model_opts <- get_default_model_options(mofa_obj)
  train_opts <- get_default_training_options(mofa_obj)
  # Notice this overrides the previous object created
  mofa_obj <- prepare_mofa(
    object = mofa_obj,
    data_options = data_opts,
    model_options = model_opts,
    training_options = train_opts
  )
  return(mofa_obj)
}


# Main entrypoint here
main <- function(mae_path, dataset_name, n_percent, 
                 factor_levels = c("Factor1"), 
                 scale_views=FALSE, method="mofa") {
  # ============================================================================
  raw_mae <- loadHDF5MultiAssayExperiment(mae_path)
  # Then starting to use mofa here
  # TODO: add options into scale view or scale anything
  mofa_obj <- mofa_pre(mae=raw_mae, scale_views=scale_views)
  # Then train on the mofa obj
  mofa_emb_file <- paste(
    paste(method, dataset_name, sep="-"), "emb.hdf5", sep="_"
  )
  mofa_emb <- run_mofa(mofa_obj, outfile = mofa_emb_file)
  
  # TODO: use some kind of cv later to determine which factors to use in 
  # getting features, like getting factor level from glmnet cv lasso
  # For each factor in factor level and view get top n percent ?
  feats_df <- get_weights(mofa_emb, as.data.frame = T) %>%
    filter(factor %in% factor_levels) %>%
    # Sort by descending order of absolute value of the weights 
    arrange(desc(abs( value ))) %>%
    # TODO: need to think keep this or not
    # This is due to the fact feature has <view>_ in front of it
    # mutate(
    #   feature = str_remove(feature, paste0(view, "_"))
    # ) %>%
    group_by(view) %>%
    # This takes top n percent of each view
    group_modify(
      ~ slice_head(
        .x, n = round(n_percent * nrow(.x) / 100, digits=0)
      )
    ) %>% 
    ungroup() %>%
    # Add metadata for downstream usage
    mutate(method = method, dataset_name = dataset_name) %>%
    select(feature, view, method, dataset_name) 
  
  # write it to disk
  feats_file <- paste0(method, "-", dataset_name, "_", "features_selected", ".csv")
  write.csv(x=feats_df, file=feats_file, row.names=FALSE)
  
  return(feats_df)
}

# Call the main function here
main(
  mae_path=opt$mae_path, 
  dataset_name=opt$dataset_name, 
  n_percent=as.numeric(opt$n_percent)
)
# Exit with message
message("\nDone")