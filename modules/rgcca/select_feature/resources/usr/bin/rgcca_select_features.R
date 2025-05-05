#!/usr/bin/env Rscript

doc <- "This script is for running one single cv on full portion of data
to select relevant features out for downstream comparisons with
other methods selected features

Usage:
  rgcca_select_features.R [options]

Options:
  --mae_path=MAE_PATH           Path to read the full data in
  --dataset_name=DNAME          Dataset name used as identification
  --output_ext=EXT              Extension of output table to save [default: csv]
  --nfolds=NFOLDS               Number of folds to perform CV to perform feature selection [default: 5]
  --prediction_model=PRED_MOD   Prediction model from caret [default: lda]
  --metric=METRIC               Metric to perform CV on [default: Balanced_Accuracy]
  --design=DESIGN		Design matrix of the method one of full or null [default: full]
"
# Parse cli docs
opt <- docopt::docopt(doc)

# Load libraries
library(RGCCA)
library(MultiAssayExperiment)
library(tibble)
library(dplyr)
library(here)
library(magrittr)

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

# ===============================================

custom_rgcca_stability <- function (rgcca_res, keep = vapply(rgcca_res$a, function(x) mean(x != 
                                                                                             0), FUN.VALUE = 1), n_boot = 100, n_cores = 1, verbose = TRUE, 
                                    balanced = TRUE, keep_all_variables = FALSE) 
{
  
  # ===========================================
  # rgcca_res = fit
  # keep = vapply(rgcca_res$a, function(x) mean(x != 0), FUN.VALUE = 1)
  # n_boot = 100
  # n_cores = 1
  # verbose = TRUE
  # balanced = TRUE
  # keep_all_variables = FALSE
    
  # ===========================================
  stopifnot(tolower(rgcca_res$call$method) %in% RGCCA:::sparse_methods())
  RGCCA:::check_integer("n_boot", n_boot)
  RGCCA:::check_integer("n_cores", n_cores, min = 0)
  
  boot_sampling <- RGCCA:::generate_resampling(rgcca_res = rgcca_res, 
                                       n_boot = n_boot, balanced = balanced, verbose = verbose, 
                                       keep_all_variables = keep_all_variables)
  sd_null <- boot_sampling$sd_null
  if (!is.null(sd_null)) {
    rgcca_res$call$blocks <- RGCCA:::remove_null_sd(list_m = rgcca_res$call$blocks, 
                                            column_sd_null = sd_null)$list_m
    rgcca_res <- RGCCA::rgcca(rgcca_res)
  }
  
  W <- RGCCA:::par_pblapply(boot_sampling$full_idx, function(b) {
    RGCCA:::rgcca_bootstrap_k(rgcca_res = rgcca_res, inds = b, type = "AVE")
  }, n_cores = n_cores, verbose = verbose)
  
  W <- W[!vapply(W, is.null, logical(1L))]

  res <- RGCCA:::format_bootstrap_list(W, rgcca_res)
  
  J <- length(rgcca_res$blocks)
  
  if (rgcca_res$call$superblock == TRUE) {
    res <- res[res$block != names(rgcca_res$blocks)[J], 
    ]
    rgcca_res$AVE$AVE_X <- rgcca_res$AVE$AVE_X[-J]
    rgcca_res$call$blocks <- rgcca_res$call$blocks[-J]
  }
  
  
  if (rgcca_res$opt$disjunction) {
    res <- res[res$block != names(rgcca_res$blocks)[rgcca_res$call$response], 
    ]
    rgcca_res$AVE$AVE_X <- rgcca_res$AVE$AVE_X[-rgcca_res$call$response]
  }
  
  # NOTE: this is start of manual fix here
  res$block <- factor(res$block, levels = levels(droplevels(res$block)))
  # NOTE: this is end of manual fix
  
  res_AVE <- res[res$type != "weights", ]
  res <- res[res$type == "weights", ]
  var2block <- subset(res, res$comp == 1 & res$boot == 1)[, 
                                                          c("var", "block")]
  rownames(var2block) <- var2block$var
  var2block$var <- NULL
  res$scores <- res$value^2 * res_AVE$value
  

  top <- tapply(res$scores, list(var = res$var), mean)
  top <- cbind(top = top, block = var2block[names(top), ])
  # NOTE: this is start of manual fix
  # remove the NA row which corresponds to the response?
  top <- top[complete.cases(top), ]
  # NOTE: this is end of manual fix
  perc <- RGCCA:::elongate_arg(keep, top)
  if (is.null(dim(rgcca_res$call$sparsity))) {
    if (rgcca_res$call$superblock == TRUE) {
      rgcca_res$call$sparsity <- rgcca_res$call$sparsity[-J]
    }
    perc[which(rgcca_res$call$sparsity == 1)] <- 1
  }
  else {
    if (rgcca_res$call$superblock == TRUE) {
      rgcca_res$call$sparsity <- rgcca_res$call$sparsity[, 
                                                         -J]
    }
    perc[which(rgcca_res$call$sparsity[1, ] == 1)] <- 1
  }
  keepVar <- lapply(seq_along(rgcca_res$AVE$AVE_X), function(j) {
    x <- top[top[, "block"] == j, "top"]
    order(x, decreasing = TRUE)[seq(round(perc[j] * length(x)))]
  })
  if (rgcca_res$opt$disjunction) {
    keepVar[[rgcca_res$call$response]] <- 1
  }
  rgcca_res$call$blocks <- Map(function(x, y) x[, y, drop = FALSE], 
                               rgcca_res$call$blocks, keepVar)
  rgcca_res$call$tau <- rgcca_res$call$sparsity <- rep(1, 
                                                       length(rgcca_res$call$blocks))
  rgcca_res <- rgcca(rgcca_res)
  return(structure(list(top = top, n_boot = n_boot, keepVar = keepVar, 
                        bootstrap = res, rgcca_res = rgcca_res), class = "rgcca_stability"))
}



# Main entrypoint of the script
# prediction_model should be glm to accord with rest of methods?
# NOTE: par_type should not be sparsity, as it will filter out most features
main <- function(mae_path, dataset_name, design="full", prediction_model = "lda", par_type="tau", 
                 validation = "kfold", nfolds=5, reps=1, metric="Balanced_Accuracy",
                 criteria_order = "top") {
  # PARAMS
  #method <- "rgcca"
  # Log the params used
  args_used <- c(as.list(environment()))
  logging_params(args_used)
  # Load the mae and extract to X and y comp, this would transpose it to n x P_i
  data_list <- loadHDF5MultiAssayExperiment(mae_path) |> extract_Xy()
  # Get the X out as it being used a lot of times
  X <- data_list$X
  view_names <- names(X) # Save its names to use later
  # Split them to X and Y (and factor this)
  # It should now look like list(X1=X1, X2=X2, ... , XN=XN, response=Y)
  rgcca_input <- X
  rgcca_input[["response"]] <- as.factor(data_list$Y)
  
  # This is number of omics including the response block, so H + 1
  J <- length(rgcca_input)
  # Set up the connection matrix
  if (design == "full") {
    # Full means 1 everywhere not of diagonal, meaning every omics
    # is related with other
    connection <- 1 - diag(J)
  } else if (design == "null") {
    # Everywhere 0 except diagonal, meaning only associate to itself
    connection <- diag(J)
  } else {
    message("\nProvide another design, one of 'full' or 'null'")
    connection <- NULL
  }
 
  # Get the first 10 rownames and colnames, and print it to file as sanity check
  logging_head_names(X=X, n = 10)
  # Also get the dimensions, since it sometimes might fail
  message("\nDimension of rows here: ", X |> sapply(nrow))
  message("\nDimension of cols here: ", X |> sapply(ncol))

  # Runs the cv 
  # RGGCA library requires sparse method to select method at rcgga_stability
  # hence during cv, need to provide the "sgcca" method instead
  cv_out <- rgcca_cv(
    blocks = rgcca_input, response = length(rgcca_input),
    connection = connection,
    method = "sgcca", # This is bit is must, plain RGCCA would not work
    par_type = par_type,
    prediction_model = prediction_model,
    validation = validation,
    k = nfolds, n_run = reps, metric = metric)
  
  # Plot cv result
  par(mar=c(1,1,1,1))
  getPlotDevice(name = paste0(method, "_cv_plot"), dataset_name=dataset_name, 
                height=8, width=8, device="svg")
  plot(cv_out)
  dev.off()
  


  # Then fit rgcca on the cv_out
  fit <- rgcca(cv_out)
  
  # Get stable variables out
  # TODO: this needs to be reverted to using RGCCA::rgcca_stability instead
  # right now had to add two lines to manually fix an error out of bound
  
  # TODO: This could fail when the response are very imbalanced, resulting in bootstrapping
  # samples of the response that have zero variance, which is complaint and error out
  stab <- custom_rgcca_stability(fit)
  
  
  # Now wrangle this to dataframe for downstream usage
  feats_df <- stab$top %>%
    as.data.frame() %>% 
    rownames_to_column(var="feature") %>%
    # Drops na, since the response gets added into the var list
    filter(!is.na( !!sym ( criteria_order) ))  %>%
    # Add metadata in for downstream merge
    mutate(
      # While in here, coerce it as RGCCA for downstream processing
      method = paste("rgcca", design, sep="-"), # Method here is always rgcca
      dataset_name = dataset_name
    ) %>%
    dplyr::rename(
      view = block,
      coef = top
    ) %>%
    # Remap the view name since it changed to number from rgcca
    mutate(view = purrr::map_chr(view, ~ view_names[.x])) %>%
    select(feature, view, coef, method, dataset_name)
    #group_by(view) %>%
    # Sort the top value
    #arrange(desc(abs( !!sym( criteria_order ) ))) %>%
    # This takes top N percent of feature from each view
    #group_modify(~ slice_head(
    #  .x, n = round(n_percent * nrow(.x) / 100, digits=0)
    #  )
    #) %>%
    #ungroup() %>%
  
  # write it to disk
  # comb_name <- paste(method, design, dataset_name, sep="-") # Method is not required anymore
  # Since method is included inside 'design' object
  comb_name <- paste(design, dataset_name, sep="-")
  feats_file <- paste0(comb_name, "_", "features_selected", ".", "csv")
  write.csv(x=feats_df, file=feats_file, row.names=FALSE)
  return(feats_df)
}

# Then call the function above
main(mae_path=opt$mae_path, dataset_name=opt$dataset_name, 
  nfolds=as.numeric(opt$nfolds),
  prediction_model = opt$prediction_model, metric=opt$metric,
  design=opt$design
)



