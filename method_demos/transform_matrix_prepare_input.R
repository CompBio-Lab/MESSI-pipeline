library(multiview)
library(mixOmics)
library(MultiAssayExperiment)
library(dplyr)
library(magrittr)
# Multiview test stuff
source("bin/split_mae.R")


separate_Xy <- function(mae, delay_matrix=TRUE, binary=FALSE) {
  # Note need to transpose back to p * n
  # TODO: add check for dimension match
  X <- mae@ExperimentList@listData |> lapply(t)
  # Given cooperative learning do not like delayed matrix, check here
  if (!delay_matrix) {
    cat("\nConverting delayed matrix to s3 matrix\n")
    X <- X |> lapply(as.matrix)
  }
  # Transform the y if needed
  # TODO: need a better way to update this
  if (binary) {
    cat("\nConverting Y to binary 1 or 0\n")
    Y <- mae$response
    Y <- ifelse(Y == "yes", 1, 0)
  } else {
    Y <- mae$response
  }
  return(list(X=X, Y=Y))
}
# data to read

raw_data <- loadHDF5MultiAssayExperiment(dir = "data/one_data/GSE123/GSE123_mae_data/")

idx_1 <- c(1,2,5,6)
idx_2 <- c(4,3,7,8)

w <- raw_data[, idx_1, drop=TRUE]
v <- raw_data[, idx_2, drop=TRUE]

# Saving it then
saveHDF5MultiAssayExperiment(w, dir="tr_mae", prefix="train", replace = TRUE)
saveHDF5MultiAssayExperiment(v, dir="te_mae", prefix="test", replace=TRUE)

# Reload back

tr_set <- loadHDF5MultiAssayExperiment(dir="tr_mae", prefix="train")
te_set <- loadHDF5MultiAssayExperiment(dir="te_mae", prefix="test")

# Then need to get X and y respectively

tr_list$Y

tr_list <- separate_Xy(tr_set, delay_matrix = FALSE, binary=TRUE)
te_list <- separate_Xy(te_set, delay_matrix = FALSE, binary = TRUE)
x = matrix(rnorm(100 * 20), 100, 20)
z = matrix(rnorm(100 * 10), 100, 10)
by = sample(c(0,1), 100, replace = TRUE)
fit2 = multiview(list(x=x,z=z), by, family = binomial(), rho=0.5)
# Training on model=

x_list <- tr_list$X
multi
mod <- cv.multiview(x_list=tr_list$X, y = tr_list$Y, family = binomial(), rho=0.5)


mod



lapply(te_list$X, dim)


length(te_list$Y)
