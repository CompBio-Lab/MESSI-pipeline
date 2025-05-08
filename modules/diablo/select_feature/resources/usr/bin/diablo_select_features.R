#!/usr/bin/env Rscript

doc <- "This script is for running one single cv on full portion of data
to select relevant features out for downstream comparisons with
other methods selected features

Usage:
  diablo_select_features.R [options]

Options:
  --mae_path=MAE_PATH       Path to read the full data in
  --dataset_name=DNAME      Dataset name used as identification
  --output_ext=EXT          Extension of output table to save [default: csv]
  --n_percent=N_PER         N percent of features per view to select [default: 100]
  --design=DESIGN           Connection in design matrix, one of full or null [default: full]
  --ncomp=NCOMP           Number of component to run diablo [default: 2]
"
# Parse cli docs
opt <- docopt::docopt(doc)

# Load libraries
library(here)
library(MultiAssayExperiment)
library(mixOmics)
library(tidyr)
library(dplyr)
library(magrittr)
library(tibble)


# Gather the pipeline dir (THIS IS VERY UGGLY FIX)
bin_dir <- Sys.getenv("PATH") |> 
  strsplit(":") |>
  unlist() |>
  tail(1)
# Determin if running on cluster deploy mode or local mode
is_scratch <- stringr::str_detect(bin_dir, pattern = "scratch")
if (is_scratch) {
  pipeline_dir <- gsub("/bin", "", bin_dir)
} else {
  pipeline_dir <- ""
}

# Source custom functions
source(here(pipeline_dir, "bin/rhelpers.R")) # This is included in nextflow bin path
# Loading generic utils from directories
load_utils(here(pipeline_dir, "bin/logging"))
load_utils(here(pipeline_dir, "bin/misc_utils"))
load_utils(here(pipeline_dir, "bin/plotting"))
# Load custom util for this current script
rp <- resource_helper_path(here(pipeline_dir, "modules/diablo/select_feature"))
source(here(rp, "createKeepX.R"))
source(here(rp, "extract_feats_df.R"))
source(here(rp, "getDesign.R"))

# Main entrance of the script
main <- function(mae_path, dataset_name, n_percent, design, ncomp) {
  # ---------------------------------------------------------------------------
  # PARAMS
  # ---------------------------------------------------------------------------
  method <- "diablo"
  # ---------------------------------------------------------------------------
  # IMPLEMENTATION
  # ---------------------------------------------------------------------------
  # Log the params used
  args_used <- c(as.list(environment()))
  logging_params(args_used)
  # Load the mae and extract to X and y comp, this would transpose it to n x P_i
  data_list <- loadHDF5MultiAssayExperiment(mae_path) |> extract_Xy()
  # Split them to X and Y (and factor this)
  X <- data_list$X
  Y <- as.factor(data_list$Y)
  # Get the first 10 rownames and colnames, and print it to file as sanity check
  logging_head_names(X=X, n = 10)
  # Then make the list of keepX, now defaults to take 100 percent of it
  keepX <- createKeepX(X, n_percent=n_percent, ncomp=ncomp)
  cat("\nKeep X is the following:", "\n", unlist(keepX), "\n")
  # Then fit the model

  # Get the design matrix first
  
  if (design == "full") {
    corr <- 1
  } else if (design == "null") {
    corr <- 0
  } else {
    stop("Error design")
  }
  design_mat <- getDesign(X, corr = corr)

  model <- block.splsda(X, Y, keepX=keepX, design=design_mat, ncomp=ncomp)

  # Loop over components and extract features
  # Extract the features out from var_list and wrangle to df for downstream usage
  feats_df <- purrr::map_dfr(1:ncomp, function(comp_idx) {
    # Then run the select var part and extract its names for each component
    var_list <- selectVar(model, comp = comp_idx)
    
    feats_df <- extract_feats_df(var_list = var_list) |> 
                  as_tibble() |>
                  # Need a better naming rather than coef?
                  rename("coef" = "value.var") |>
                  #arrange(desc( coef )) |>
                  mutate(
                    method = paste(method, design, sep="-"), 
                    dataset_name = dataset_name,
                    comp = comp_idx
                  ) |>
                  select(feature, view, coef, method, dataset_name, comp)
    return(feats_df)
  }) |>
  # Now add ncomp into the view part
  mutate(view = paste(view, paste0("ncomp-", comp), sep="-")) |>
  select(-c("comp"))


  # write it to disk
  comb_name <- paste(method, design, dataset_name, sep = "-")
  output_format <- "csv"
  feats_file <- paste0(comb_name , "_", "features_selected", ".", output_format)
  write.csv(x=feats_df, file=feats_file, row.names=FALSE)

  # Plot the selected variables out
  if (ncomp < 2) {
    warning("Selected variables plot can only be shown when ncomp >= 1")
  } else {
    par(mar=c(1,1,1,1))
    getPlotDevice(name = "diablo_feature_selection_plot", dataset_name=comb_name, 
                  height=8, width=8, device="svg")
    plotVar(model)
    dev.off()

  }

  return(feats_df)
}

# Then call the function above
main(
  mae_path=opt$mae_path, 
  dataset_name=opt$dataset_name, 
  n_percent=as.numeric(opt$n_percent),
  design=opt$design,
  ncomp=as.numeric(opt$ncomp)
)
