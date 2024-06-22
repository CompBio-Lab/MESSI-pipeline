library(MOFA2)
library(MultiAssayExperiment)


load_test_splits <- function(split_dir, pattern=".txt", ...) {
  if (split_dir == "empty") {
    stop("You did not provide the directory that contains txt files of indices")
  }
  # Glob pattern
  # The split dir needs to be relative, do NOT use here::here
  # When run with nextflow, as it caches the dir inside a work directory
  idx_files <- list.files(path=split_dir, 
                          pattern=".txt", full.names = TRUE)
  # Read in data
  idx_list <- lapply(idx_files, function(f) {
    data <- scan(f, what = numeric(), quiet = TRUE)
    return(data)
  })
  
  # Check if it contains zero (hence assume it was 0index based)
  zero_indexed <- any(sapply(idx_list, function(vec) any(vec == 0)))
  # Then if true, shift all by 1
  if (zero_indexed) {
    cat("\nIndex founded to be 0 based, shift by 1 for all\n")
    idx_list <- lapply(idx_list, function(x) x + 1)
  }
  
  # Assign names based on loaded files
  idx_list <- setNames(idx_list, 
                       tools::file_path_sans_ext(basename(idx_files)))
  return(idx_list)
}


# Use this function to reconstruct mae
reconstruct_mae <- function(mae) {
  # Given an mae with delayed matrices, we could load it into
  # memory and make it of HDF5 arrays instead
  X <- mae@ExperimentList |> lapply(as.matrix)
  y <- mae$response
  # Construct MAE
  new_mae <- MultiAssayExperiment::MultiAssayExperiment(experiments = X)
  new_mae$response <- y
  return(new_mae)
}


# Actual fun to split each MAE to train and test portion
split_mae <- function(mae_path, split_dir, dataset_name) {
  # Read in the MAE
  # Note the prefix "" is required here?
  mae <- MultiAssayExperiment::loadHDF5MultiAssayExperiment(dir=mae_path, prefix="")
  # Should be a list of splits
  cat("Splitting data for", dataset_name, "\n")
  cat("\nThe data is located in:", mae_path, "\n")
  cat("\nThe splits are located in:", split_dir, "\n")
  split_dir = "tenFoldCV_results/splitting/split_train_test/breast_tcga/splits/"
  test_splits <- load_test_splits(split_dir=split_dir)
  
  
  fold_names <- names(test_splits)
  
  for (fold_name in fold_names) {
    # First subset both
    split <- test_splits[[fold_name]]
    # TODO: Transpose data only when method requires it to
    tr_mae <- new_mae[, -split, drop=TRUE] |> reconstruct_mae()
    te_mae <- new_mae[, split, drop=TRUE] |> reconstruct_mae()
    # Then save each fold's train and test portion as subdirectory of fold name
    cat("\nSaving for", fold_name, "\n")
    if (!dir.exists(fold_name)) {
      dir.create(fold_name)
    }
    tr_path <- file.path(fold_name, paste0(fold_name, "_tr"))
    te_path <- file.path(fold_name, paste0(fold_name, "_te"))
    # The train portion
    MultiAssayExperiment::saveHDF5MultiAssayExperiment(tr_mae, dir=tr_path,
                                                       prefix="train")
    # The test portion
    MultiAssayExperiment::saveHDF5MultiAssayExperiment(te_mae, dir=te_path,
                                                       prefix="test")
    cat("\nSaved for", fold_name, "\n")                                                      
  }
}

default_python <- "/usr/bin/python"
reticulate::use_python(default_python)


# So assumming I load that huge mae
full_mae <- loadHDF5MultiAssayExperiment("tenFoldCV_results/prepare_data/prepare_mae_data/breast_tcga/breast_tcga_mae_data/")


mofa_obj <- create_mofa(full_mae)
# TODO: ADD A manual scaling to the train data, possibly in a fun, so that it could be applied on the test data as well

# NOTE this treats features as rows and samples as columns
# Get data options
# TODO: these two could be discussed later
# scale_groups: if groups ( NOT meaning group of response ) have different ranges/variances, 
#               it is good practice to scale each group to unit variance. Default is FALSE
# scale_views: if views (omic) have different ranges/variances, 
#              it is good practice to scale each view to unit variance. Default is FALSE
data_opts <- get_default_data_options(mofa_obj)
#data_opts$scale_views <- TRUE

# Get model options
# num_factors might be tuneable
model_opts <- get_default_model_options(mofa_obj)

# Get train options
# maxiter: number of iterations. Default is 1000.
# convergence_mode: fast, medium, slow? not sure which one affects? tuneable?
# gpu_mode: use gpu, but needs cupy installed?
train_opts <- get_default_training_options(mofa_obj)

# Now build and train mofa object
# Notice this overrides the previous object created
mofa_obj <- prepare_mofa(
  object = mofa_obj,
  data_options = data_opts,
  model_options = model_opts,
  training_options = train_opts
)

full_mae@colData$response
col_data |> as.data.frame() |> cbind(sample_names = rownames(col_data))
col_data <- full_mae@colData
col_data |> rownames()
full_mae@colData |> rownames()
# Actual training step, this also saves the model to disk
mofa_model_file <- "model.hdf5"
mofa_model <- run_mofa(mofa_obj, outfile = mofa_model_file)
# Although to make predictions, need its embeddings and use a glmnet on prediction
factors <- get_factors(mofa_model, factors="all")
column_data <- data.frame(response = full_mae$response, sample_names = factors$group1 |> rownames())
rownames(column_data) <- factors$group1 |> rownames()
new_mae <- MultiAssayExperiment(
  experiments = list(embeddings=factors$group1 |> t()), 
  colData = column_data
  )


# NOW THIS CALLS THE SPLIT_MAE sort of

# THen loading back
curr_train <- loadHDF5MultiAssayExperiment("fold_1/fold_1_tr/")
curr_test <- loadHDF5MultiAssayExperiment("fold_1/fold_1_te/")

library(here)
source(here("bin/rhelpers.R")) # This is included in nextflow bin path
# Loading generic utils
load_utils(here("bin/logging"))
load_utils(here("bin/preprocessing"))
load_utils(here("bin/misc_utils"))

train_data <- curr_train |> extract_Xy()
test_data <- curr_test |> extract_Xy()

library(glmnet)
library(dplyr)
train_X <- train_data$X$embeddings |> as.data.frame() |>
  tibble::rownames_to_column(var = "sample_names")

train_y <- train_data$Y |> as.factor()

test_X <- test_data$X$embeddings |> as.matrix()
test_y <- test_data$Y |> as.factor()
glmnet_model <- glmnet(
  x = train_X |> select_if(is.numeric) |> as.matrix(),
  y = train_y,
  family = "binomial"
)


as <- stats::predict(glmnet_model, newx=train_X |> select_if(is.numeric) |> as.matrix(),
               type="response", s = 5)

bs <- stats::predict(glmnet_model, newx=test_X, type="response", s = 0.000001)


mean(ifelse(bs >= 0.5, 1, 0) == test_y)
mean(ifelse(as >= 0.5, 1, 0) == train_y)
# test

# train_weights <- get_weights(mofa_model)

# test_data$X |> lapply(dim)
# train_weights |> lapply(dim)
# 
# test_projected <- mapply(function(x, y ) {
#   return(x %*% y)
# }, x = test_data$X, y = train_weights, SIMPLIFY = F) 
# 
# lapply(test_projected, dim)
# 
# dim(test_projected)

#n x p //  p  x k 

# Then the factors would have F dimension factors of columns,
# this F is tuned earlier, and the output of this should be
# N x F, where N is number of samples (or number of individuals)
# Usually it has one group only
if (length(factors) == 1) {
  embeddings <- factors[[1]] 
}
# Convert this to dataframe and train glmnet model using this
embeddings <- embeddings |> 
  as.data.frame() |>
  tibble::rownames_to_column(var = "sample_name")

embeddings |> dim()

embeddings |> head()

library(dplyr)
# Glmnet model (ACTUALLY using this to predict)
glmnet_model <- glmnet::glmnet(
  x = embeddings |> select_if(is.numeric) |> as.matrix(),
  y = train_mae$response |> pull(response),
  family = "binomial"
)

train_mae@ExperimentList$protein[1:6, 1:3]
mofa_pred$protein$group1[1:6, 1:3]
mofa_pred <- predict(object = mofa_model)


stats::predict(glmnet_model, newx=)
