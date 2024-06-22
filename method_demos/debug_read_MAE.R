# Check stuff
library(here)
library(MultiAssayExperiment)

# Fun to use
load_MAE <- function(path, prefix="") {
  MAE <- loadHDF5MultiAssayExperiment(
    dir     =  path,
    prefix  =  prefix
  )
  return(MAE)
}


separate_Xy <- function(mae) {
  # Note need to transpose back to p * n
  # TODO: add check for dimension match
  X <- mae@ExperimentList@listData |> lapply(t)
  Y <- mae$response
  return(list(X=X, Y=Y))
}

# Params
i <- 3
test <- TRUE
id <- "GSE123"
# Always look at fold 3 by def
# Return test set by def
f <- function(id, i = 3, test=TRUE, work=FALSE, work_dir="") {
  if (!work) {
    preprocess_dir <- here("results/diablo_preprocess", id)
    #cat("\nThis is", sample, "\n")
    all_folds <- list.files(preprocess_dir, 
                            pattern = "fold", full.names = TRUE)
    # Choose any i-th fold from all folds
    ith_fold <- list.files(all_folds[i], full.names = TRUE)
    #cat("\nThis is fold", ith_fold, "\n")
    # Retrive the paths first
    train_path <- ith_fold[str_detect(ith_fold, "_tr")]
    test_path  <- ith_fold[str_detect(ith_fold, "_te")]
  } else {
    pre_dir <- here(work_dir)
  }
  # Load MAE accordingly
  if (test) {
    #cat("\nThis is the test set\n")
    MAE <- load_MAE(path=test_path, prefix="test")
  } else {
    #cat("\nThis is the train set\n")
    MAE <- load_MAE(path=train_path, prefix="train")
  }
  
  return(MAE)
}

load_MAE(here("work/0f/6868746f8e81e6111e0e89e17a73d0/test_split_fold_1/test_split_fold_1_tr/"),
         "train")





# Loop through each set (train or test) of sample
for (i in 1:3) {
  mae <- f(id, i = i, test=TRUE)  
  print(mae)
}

# Sample 1 test set

lom <- lapply(seq(1:3), function(i) {
  data <- f(sample, i=i, test=TRUE)
  s <- data |> separate_Xy()
  return(s)
  })

lom[[1]]


dp <- "/scratch/st-singha53-1/tliang19/multi-omics-pipeline/work/f0/8f7db976b1f3634aaae7c4997d94c4/test_split_fold_1"
d <- list.files(dp, full.names=TRUE)
te <- d[str_detect(d, "_te")]
tr <- d[str_detect(d, "_tr")]


a <- g(tr, test=FALSE)
b <- f(sample="sample1", i=2, test=FALSE)

b
a$response == b$response

# fit diablo model
mixOmics::block.plsda(X = lom[[1]]$X, Y = lom[[1]]$Y)
mod


# Sample j original data
full_sample_path <- here("data/minimalist_data/sample2/sample2_mae_data/")
load_MAE(full_sample_path)
50 %/% 3 


# Import lib
library(here)
library(MultiAssayExperiment)
# Confirm source data
# Sample 1 has 30 obs, Sample 2 has 50 obs
id <- "GSE123"
data_source  <- here("data/one_data", id, 
                     paste0(id, "_mae_data"))

loadHDF5MultiAssayExperiment(
  dir = data_source
)

data

# Id from computation?
out <- list()
for (i in 1:3) {
  fold <- paste0("test_split_fold_", i)
  result_source <- here("results/diablo_preprocess", 
                        id, fold
  )
  data <- loadHDF5MultiAssayExperiment(
    dir = paste0(result_source, "/", fold, "_te"),
    prefix = "test"
  )
  
  fold_names <- lapply(assays(data), colnames)
  out[[fold]] <- fold_names
}


out$test_split_fold_1


out$test_split_fold_2

out$test_split_fold_3




