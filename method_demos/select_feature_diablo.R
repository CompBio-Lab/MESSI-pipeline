# ===============================================
# DIABLO SELECT FEATURE
# ===============================================

# ------------------------
# CUSTOM FUNCTIONS
# ------------------------
parseY <- function(Y) {
  lev <- levels(Y)
  if (!is.atomic(Y)) stop("The response variable is not a vector, might be a dataframe")
  if (is.null(Y)) stop("The response variable is not found in MAE")
  if (is.character(Y) || is.character(lev)) {
    Y <- (ifelse(tolower(Y) == "yes", 1,0))
  }
  # TDOD: might not be able to convert as factor anyways
  #Y <- as.factor(Y)
  return(Y)
}

# Convert MAE to list of X and Y
extract_Xy <- function(mae) {
  # Note need to transpose back to p * n
  # TODO: add check for dimension match
  # COOP LR do not like delayed matrix, so transform it to S3 matrix
  cat("\nConverting delayed matrix to matrix\n")
  # TODO: this part is actually very bad, given MAE expects the file to
  # be saved and laoded in same directory, i.e. if you saved one place, 
  # and loaded elsewhere, then it would fail
  X <- mae@ExperimentList@listData |> lapply(t) |> lapply(as.matrix)
  cat("\nConverting response to binary\n")
  # COOP LR requires 0 <= y <= 1
  # MAE response would be a dataframe?
  # In simulated data this is always atomic, but in real, they are
  # transformed to dataframe first, so need to pull it
  y_temp <- mae$response
  if (is.data.frame(y_temp)) {
    Y <- parseY(y_temp |> dplyr::pull(response))
  } else {
    Y <- parseY(y_temp)
  }
  return(list(X=X, Y=Y))
}

createKeepX <- function(x_list, n_percent = 10, ncomp=2) {
  # For each omics, only get 10% of total features
  # Assume the input list is already after transforming to rows being common
  # samples
  cap <- 100
  if (n_percent > cap) {
    warning("Limited to top 100%, cannot exceed more than original feature count")
    n_percent <- cap
  }
  # Then create the keep x
  # TODO: should this be better M percent of N or M percent of each n_i ?
  keep_list <- lapply(x_list, function(x) {
    # since row now represents samples, col correspond to features
    feat_num <- floor(n_percent * ncol(x) / 100 )
    # repat the number of features for ncomp times as a vector
    feat_vec <- rep(feat_num, ncomp)
    return(feat_vec)
  })
  # assign to have the matching omics names
  names(keep_list) <- names(x_list)
  return(keep_list)
}

getPlotDevice <- function(name, dataset_name, height, width, res, 
                          units, device) {
  plot_name <- paste0(dataset_name, "-", name)
  if (device == "svg") {
    filename <- paste0(plot_name, ".svg")
    return(svg(filename,
               height=height,
               width=width))
  }
  
  if (device == "png") {
    filename <- paste0(plot_name, ".png")
    return(png(filename,
               height = height,
               width = width,
               res=res,
               units=units))
  }
  
  return(device)
  
}

extract_feats_df <- function(var_list) {
  # Last column is ncomp, so discard that part, hence -1
  n <- length(var_list)
  feat_list <- var_list[1:n - 1]
  # To save stuff
  view_names <- names(feat_list)
  selected_feat_df_list <- lapply(view_names, function(view) {
    # For each omic (which is a list(name, value)), get the value part
    view_feats <- feat_list[[view]]
    view_feats_df <- view_feats$value |> 
      rownames_to_column(var="feature") |>
      mutate(view = view)
    return(view_feats_df)
  })
  
  selected_feat_df <- bind_rows(selected_feat_df_list)
  return(selected_feat_df)
}
# --------------
# LOAD LIBRARY
# --------------
library(MultiAssayExperiment)
library(mixOmics)
library(tidyr)
library(dplyr)
library(tibble)
# --------------
# PARAMS
# --------------
mae_path <- "tenFoldCV_results/prepare_data/prepare_mae_data/breast_tcga/breast_tcga_mae_data"
dataset_name <- "breast_tcga"
method <- "diablo"
n_percent <- 10

# Files naming

# ACTUAL CODING HERE
# -----------------------------------------------------------------------------
# Load the full mae (after prepare_data)
# So this is P_i x n dimension
# response is in mae$response$response of factor yes and no
mae <- loadHDF5MultiAssayExperiment(mae_path)
# After our custom fun, we could get X = [ n x P_i for i matrices ] and Y = numeric vec
big_data_list <- mae |> extract_Xy()
# SO convect the Y to binary num factor of levels 0 and 1
big_data_list$Y <- as.factor(big_data_list$Y)

# DIABLO decides the number of columns in here instead of after performing
# feature selection as it requires this initial threshold to perform fs
keepX <- createKeepX(big_data_list$X, n_percent = n_percent, ncomp=2)

# RUN a cv model of diablo

# create basic model
basic_model <- block.splsda(big_data_list$X, big_data_list$Y, keepX=keepX)
# Then run the select var part and extract its names
var_list <- selectVar(basic_model)
# Last column is ncomp, so discard that part, hence -1
diab_feats_df <- extract_feats_df(var_list = var_list) |> 
  as_tibble() |>
  # Need a better naming rather than coef?
  rename("coef" = "value.var") |>
  mutate(method = method, 
         dataset_name = dataset_name
         )

# Make the plotting out
# par(mar=c(1,1,1,1))
# getPlotDevice(name = "diablo_feature_selection_plot", dataset_name=dataset_name, 
#               height=8, width=8, device="svg")
# plotVar(basic_model)
# dev.off()

# -------------------------
# Writing to disk related
# -------------------------
feat_file <- paste0(method, "-", dataset_name, "_", "features_selected", ".csv")
#write.csv(x = diab_feats_df, file = feat_file, row.names = FALSE)
#return(diab_feats_df)
