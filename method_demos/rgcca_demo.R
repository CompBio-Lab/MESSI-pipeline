# =============================================================================
# USE this script to follow step by step of using RGCCA method
# 
# RGCCA requires X = [X1, X2, ... XJ] in R n x p , and a Y in R n 
# These two are stored in a list like: Z = [X1, X2, ... , XJ, Y]
# Each n × pj data matrix Xj is called a block and represents a set of 
# pj variables observed on the same # set of n individuals.
# 
# THIS is transpose of standard MutliAssayExperiment (pj x n)
# You specify the response by number of position of its input list
# Y needs to be in factor
# =============================================================================
# Load library
library(RGCCA)
library(MultiAssayExperiment)
library(tibble)
library(dplyr)
# Load sample data
s1 <- "data/real_data/breast_tcga/breast_tcga_mae_data/"
s2 <- "data/real_data/rosmap/mae_data/"
sample_mae <- loadHDF5MultiAssayExperiment(s1)
# Get the X and Y from the mae and convert it to rgcca input format
rgcca_input <- sample_mae@ExperimentList |> lapply(t) |> lapply(as.matrix)
rgcca_input[["response"]] <- sample_mae$response |> as.factor()

# Fit rgcca object
rgcca_fit <- rgcca(blocks=rgcca_input, response=length(rgcca_input))
# THIs show block weight vector
# plot(rgcca_fit, block=1:3)

# Then try a cv first
cv_out <- rgcca_cv(blocks = rgcca_input, response = 4,
                   par_type = "sparsity",
                   prediction_model = "lda",
                   validation = "kfold",
                   k = 5, n_run = 1, metric = "Balanced_Accuracy")

# Could plot the cv object as well
# plot(cv_out)

# Then fit rgcca on the cv_out
fit <- rgcca(cv_out)

stab <- rgcca_stability(fit)

# boot_out <- rgcca_bootstrap(stab, n_boot = 500)

# ----------------------

ddd_df <- stab$top |> as.data.frame() |> 
  rownames_to_column(var="feat") |>
  tidyr::drop_na() |> arrange(desc(top))

ddd_df |> tibble::as_tibble() |> rename(feature = feat)

