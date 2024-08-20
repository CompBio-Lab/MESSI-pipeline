#!/usr/bin/env Rscript

# ==============================================================================
doc <- "This script is to use the InterSIM package to simulate synthetic data
based on TCGA ovarian cancer study. It creates dna methylation, gene expression
and protein data. We then apply a specific transformation to generate a 
dummy bernoulli distribution response of mimicking patient has cancer or not

Usage:
  simulate_InterSIM.R [options]

Options:
  --help                  Display this help message
  --dataset_name=DNAME    Name of the dataset [default: empty]
  --output_format=OUT_F   Format of the output data, one of MAE or MuData [default: empty]
  --number_obs=N          Number of observations to generate [default: 30]
  --effect=EFFECT         Cluster mean shift on each view [default: 2]
  --sigma=SIGMA           Covariance structure in the each omics's data, one of def, indep [default: indep]
  --corr=CORR             Correlation between each omics, one of: 0, 0.5, 1 . [default: 0]
  --transformation=TR     Transformation to apply of the generated X to derive the response variable [default: rev_logit]
"
# ==============================================================================
# Parse cli arguments
opt <- docopt::docopt(doc)
# Load library
library(InterSIM)
library(dplyr)


# Gather the pipeline dir (THIS IS VERY UGGLY FIX)
bin_dir <- Sys.getenv("PATH") |> 
  strsplit(":") |>
  unlist() |>
  tail(1)
pipeline_dir <- gsub("/bin", "", bin_dir)

# Helper to convert mae to h5mu on mudata
save_h5mu <- function(mae, dataset_name, pipeline_dir) {
  # Takes the MAE experiment and save this as MuData
  exps <- mae@ExperimentList |> lapply(t)
  col_data <- mae@colData |> as.data.frame()
  feat_names <- mae@ExperimentList |> lapply(rownames)
  # Then calls python code here
  reticulate::use_python("/usr/bin/python")
  reticulate::source_python(here::here(pipeline_dir, "modules/simulation/simulate_intersim/resources/usr/bin/save_mudata.py"))
  # Save it to mudata
  save_mudata(exps, col_data, feat_names, dataset_name)
}


# Helper fun to generate the bernoulli distributed response variable from the 
# counts X using certain criteria
# TODO: Need to better describe this criteria

# Args:
#   X: List of matrices denoting the count matrix of omics
#      Each matrix should have dimension of n x P_j, where n is number of 
#      observations, and P_j is number of features in j-th omics
#   criteria: Custom criteria of how to transform from X to get bernoulli
#             distributed Y
#             Options are: 
#             - composite_score (rowSums >= median(rowSums))
#             - rev_logit: logit^-1 on the X to get [0, 1] values on each
#             entry of the cbinded matrices M = [m1 m2 m3, ...] then take
#             Bern( 1 - rowMeans(M) ) 
#   tol: tolerance of comparing difference of sample var and population of the response
# generate_Y <- function(X, transformation=c("rev_logit", "composite_score"), tol=0.01, id_name="sample_name") {
#   # SHOULD not create the y by clustering it, otherwise method will catch it 100%?
#   transformation <- match.arg(transformation)
#   message("Using transformation: ", transformation)
#   # NOTE: Always using row here, since InterSim output row as subject, col as
#   # feature
  
  
#   # =======================
#   # THIS IS FOR DEBUG
#   #X <- dd@ExperimentList |> lapply(t)
#   # =======================
  
#   if (transformation == "composite_score") {
#     z <- rowSums(do.call(cbind, lapply(X, rowSums)))
#     # Calculate a avg score of either mean or median
#     median_score <- median(z)
#     # Named vector of 1 and 0s
#     response <- ifelse(z >= median_score, 1, 0)
#   }
  
#   if (transformation == "rev_logit") {
#     # TODO: the rowmeans could be bad, since its almost always > 0
#     # resulting in a not so fair bernoulli random variable
#     z <- InterSIM::rev.logit(do.call(cbind, X)) |>
#       rowMeans() 
#     # TODO: try z (more positives) or 1 - z (more negative) in prob
#     response  <- rbinom(n = length(z) , size = 1 , prob = 1 - z)
#     # Named vector of 1 and 0s
#     names(response) <- names(z)
#   }
#   # Check if the response follows bernoulli distribution with some tolerance
#   sample_var <- var(response)
#   phat <- mean(response)
#   pop_var <- phat * (1 - phat)
#   diff <- abs(pop_var - sample_var)
#   is_bernoulli <- diff <= tol
#   if (!is_bernoulli) warning("Difference of population and sample variance: ", round(diff, 3), " which exceeded tolerance of ", tol)
  
#   # Lastly assign the rownames to df as well
#   meta_df <- response |>
#     as.data.frame() |>
#     tibble::rownames_to_column(var={{ id_name }}) |>
#     select({{ id_name }}, response)
#   # Manually assign the rownames back, since MAE uses rownames of colData to
#   # match those colnames of the X matrix (P_j x n)
#   rownames(meta_df) <- meta_df |> pull( {{ id_name }} )
#   return(meta_df)
# }


generate_Y <- function(response, id_name="sample_name") {
  # Maybe should not create the y by clustering it, otherwise method will catch it 100%?
  meta_df <- response |>
            rename( 
              {{ id_name }} := subjects ,
              "response" = cluster.id
            ) |>
            # INTERSIM gives 3 clusters, so we only keep the first two 1 and 2
            filter(response != 3) |>
            # This makes it to binary 1 and 0
            mutate(response = as.numeric(as.factor(response)) - 1)
  # Manually assign the rownames back, since MAE uses rownames of colData to
  # match those colnames of the X matrix (P_j x n)
  rownames(meta_df) <- meta_df |> pull( {{ id_name }} )
  return(meta_df)
}

# Process something on the X counts and filter by those subject names in Y
generate_X <- function(X_raw, meta_df) {
  # Rename its prefix of dat.<view_name>
  X_names <- gsub("dat.", "", names(X_raw))
  # The sample names in clusters 1 and 2
  keep_samples <- rownames(meta_df)
  # And transpose the X to MultiAssayExperiment format
  X <- lapply(X_raw, function(omic) {
    # Only keep those subjects in clusters 1 and 2
    x <- omic[ keep_samples, ]
    return(t(x))
  })
  names(X) <- X_names
  return(X)
}


# Main entrace of the function
main <- function(dataset_name, output_format, n, effect, 
                 cluster.sample.prop = c(0.45,0.45,0.1),
                 p.DMP=0.2, p.DEG=NULL, p.DEP=NULL, 
                 sigma=c("indep", "def"), 
                 corr=0,
                 transformation="rev_logit",
                 pipeline_dir=".") {
  
  # Stop when no custom dataset name is provided
  if (dataset_name == "empty") stop("Did not provided a custom dataset for simulation of intersim")
  if (output_format == "empty") stop("Did not provided the format of data to write out for simulation of intersim")
  # Match args of sigma
  sigma <- match.arg(sigma)
  if (sigma == "def") {
    sigma <- NULL
  }

  
  # First generate the count data from InterSIM
  # TODO: The interSIM pkg doesnt have a way to change number of features in each omics
  # fixed to their defaults ....
  dat <- InterSIM(n.sample=n,
                  cluster.sample.prop=cluster.sample.prop,
                  delta.methyl = effect, delta.expr = effect, delta.protein = effect,
                  p.DMP=p.DMP,p.DEG=p.DEG, p.DEP=p.DEP, 
                  sigma.methyl=sigma, sigma.expr=sigma, sigma.protein=sigma,
                  cor.methyl.expr=corr, cor.expr.protein=corr)
  
  # Ignore its cluster assignment for now
  n_list <- length(dat)
  # We retaining only cluster 1 and 2 subjects, so need to first process meta then on X
  Y_df <- generate_Y(response=dat[[n_list]])
  # Process the X as well
  X <- generate_X(X_raw = dat[1:n_list - 1], meta_df=Y_df)
  # Construct the X and Y here
  mae <- MultiAssayExperiment::MultiAssayExperiment(
    experiments = X,
    colData = Y_df
  )
  
  
  # Then should convert mae to mudata h5mu
  if (tolower(output_format) == "mudata") {
      save_h5mu(mae, dataset_name, pipeline_dir)
  }

  if (tolower(output_format) == "mae") {
      # Also saving it as mae
      MultiAssayExperiment::saveHDF5MultiAssayExperiment(mae, prefix="",
                                  dir=paste0(dataset_name, "_", "mae_data"),
                                  replace = T)
  }
  return(mae)
}


# Call the main function
main(
  dataset_name = opt$dataset_name,
  output_format = opt$output_format,
  n = as.numeric(opt$number_obs),
  effect = as.numeric(opt$effect),
  sigma = opt$sigma,
  corr = as.numeric(opt$corr),
  transformation = opt$transformation,
  pipeline_dir = pipeline_dir
)
