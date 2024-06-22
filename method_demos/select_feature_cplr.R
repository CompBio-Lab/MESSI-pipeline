# ===============================================
# CPLR SELECT FEATURE
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


# --------------
# LOAD LIBRARY
# --------------
library(MultiAssayExperiment)
library(multiview)
library(tidyr)
library(dplyr)
# --------------
# PARAMS
# --------------
#mae_path <- "tenFoldCV_results/prepare_data/prepare_mae_data/GSE71669/GSE71669_mae_data/"
mae_path <- "tenFoldCV_results/prepare_data/prepare_mae_data/breast_tcga/breast_tcga_mae_data"
type.measure <- "deviance"
dataset_name <- "breast_tcga"
method <- "cooperative_learning"
top_n_percent <- 0.10
nfolds <- 3 # Smallest nfolds is 3 according to multiview doc
rho <- 0.5
useLasso <- FALSE
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

# RUN a cv model on multiview (alpha 0 = ridge, alpha 1 = lasso)

if (useLasso) {
  alpha <- 1
} else {
  alpha <- 0
}

# Smalles nfolds is 3 according to multiview doc
cv_model_lasso <- cv.multiview(x_list = big_data_list$X, y = big_data_list$Y,
                         family = binomial(),
                         type.measure = type.measure, 
                         rho=rho,trace.it = T,nfolds = 3, alpha = 1
                         )

cv_model_ridge <- cv.multiview(x_list = big_data_list$X, y = big_data_list$Y,
                               family = binomial(),
                               type.measure = type.measure, 
                               rho=rho,trace.it = T,nfolds = 3, alpha = 0
)


# Make the plotting out
# par(mar=c(1,1,1,1))
# getPlotDevice(name = "mutlview_feature_selection_plot", dataset_name=dataset_name, 
#               height=8, width=8, device="svg")
# plot(cv_model)
# dev.off()


# Get the lambda to use
s <- cv_model_ridge$lambda.min

# Not sure if ordered by standardized_coef
# of coef
n_percent <- 10
total_feat_num <- mae@ExperimentList |> lapply(nrow) |> unlist()



top_n_percent <- total_feat_num |> sapply(function(x) round(n_percent * x / 100))
top_n_percent
n_selected <- floor(top_n_percent * total_feat_num)

criteria = "coef"


feats_df <- coef_ordered(cv_model_ridge, s=s) %>%
  as_tibble() %>%
  rename(feature=view_col) %>%
  mutate(method = method,
         dataset_name = dataset_name
  ) %>%
  group_by(view) %>%
  arrange(desc(abs( !!sym(criteria) ))) %>%
  group_modify(~ slice_head(.x, n = round(n_percent * nrow(.x) / 100))) %>%
  ungroup() %>%
  select(feature, view, method, dataset_name)

f1 <- feats_df

f2 <- coef_ordered(cv_model_ridge, s=s) %>%
  as_tibble() %>%
  rename(feature=view_col) %>%
  mutate(method = method,
         dataset_name = dataset_name
  ) %>%
  group_by(view) %>%
  arrange(desc(abs( !!sym(criteria2) ))) %>%
  group_modify(~ slice_head(.x, n = round(n_percent * nrow(.x) / 100))) %>%
  ungroup() %>%
  select(feature, view, method, dataset_name)


sum(f1$feature == f2$feature)
