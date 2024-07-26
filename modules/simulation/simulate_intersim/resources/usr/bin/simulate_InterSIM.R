#!/usr/bin/env Rscript

# ==============================================================================
doc <- "This script is to use the InterSIM package to simulate synthetic data
based on TCGA ovarian cancer study. It creates dna methylation, gene expression
and protein data. We then apply a specific transformation to generate a 
dummy bernoulli distribution response of mimicking patient has cancer or not

Usage:
  simulate_InterSIM.R [options]

Options:
  --help                Display this help message
  --number_obs=N        Number of observations to generate [default: 2]
  --sigma=SIGMA         Covariance structure in the each omics's data, one of def, indep [default: indep]
  --corr=CORR           Correlation between each omics, one of: low, med, high, def. [default: low]
  --transformation=TR   Transformation to apply of the generated X to derive the response variable [default: rev_logit]
"
# ==============================================================================
# Parse cli arguments
opt <- docopt::docopt(doc)
# Load library
library(InterSIM)
library(dplyr)

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
generate_Y <- function(X, transformation=c("rev_logit", "composite_score"), tol=0.01, id_name="sample_name") {
  # SHOULD not create the y by clustering it, otherwise method will catch it 100%?
  transformation <- match.arg(transformation)
  message("Using transformation: ", transformation)
  # NOTE: Always using row here, since InterSim output row as subject, col as
  # feature
  if (transformation == "composite_score") {
    z <- rowSums(do.call(cbind, lapply(X, rowSums)))
    # Calculate a avg score of either mean or median
    median_score <- median(z)
    # Named vector of 1 and 0s
    response <- ifelse(z >= median_score, 1, 0)
  }
  
  if (transformation == "rev_logit") {
    # TODO: the rowmeans could be bad, since its almost always > 0
    # resulting in a not so fair bernoulli random variable
    z <- InterSIM::rev.logit(do.call(cbind, X)) |>
      rowMeans() 
    # TODO: try z (more positives) or 1 - z (more negative) in prob
    response  <- rbinom(n = length(z) , size = 1 , prob = 1 - z)
    # Named vector of 1 and 0s
    names(response) <- names(z)
  }
  # Check if the response follows bernoulli distribution with some tolerance
  sample_var <- var(response)
  phat <- mean(response)
  pop_var <- phat * (1 - phat)
  diff <- abs(pop_var - sample_var)
  is_bernoulli <- diff <= tol
  if (!is_bernoulli) warning("Difference of population and sample variance: ", round(diff, 3), " which exceeded tolerance of ", tol)
  
  # Lastly assign the rownames to df as well
  meta_df <- response |>
    as.data.frame() |>
    tibble::rownames_to_column(var={{ id_name }}) |>
    select({{ id_name }}, response)
  # Manually assign the rownames back, since MAE uses rownames of colData to
  # match those colnames of the X matrix (P_j x n)
  rownames(meta_df) <- meta_df |> pull( {{ id_name }} )
  return(meta_df)
}


# Main entrace of the function
main <- function(n=40, effect = 2.0,
                 p.DMP=0.2, p.DEG=NULL, p.DEP=NULL, 
                 sigma=c("indep", "def"), 
                 corr=c("low", "med", "high", "def"),
                 transformation="rev_logit") {
  
  # Match args of sigma and corr
  sigma <- match.arg(sigma)
  corr <- match.arg(corr)
  
  if (sigma == "def") {
    sigma <- NULL
  }
  
  if (corr == "low") {
    corr <- 0.2
  } else if (corr == "med") {
    corr <- 0.5
  } else if (corr == "high") {
    corr <- 0.7
  } else {
    corr <- NULL
  }

  # First generate the count data from InterSIM
  # TODO: The interSIM pkg doesnt have a way to change number of features in each omics
  # fixed to their defaults ....
  dat <- InterSIM(n.sample=n,
                  delta.methyl = effect, delta.expr = effect, delta.protein = effect,
                  p.DMP=p.DMP,p.DEG=p.DEG, p.DEP=p.DEP, 
                  sigma.methyl=sigma, sigma.expr=sigma, sigma.protein=sigma,
                  cor.methyl.expr=corr, cor.expr.protein=corr)

  # Ignore its cluster assignment for now
  # NOTE: this gives a non scaled data
  X_raw <- dat[1:length(dat) - 1] # Since last element is the cluster assignment
  # Rename its prefix of dat.<view_name>
  names(X_raw) <- gsub("dat.", "", names(X_raw))
  # Call the helper fun to generate Y variable which follows Bernoulli distribution
  Y <- generate_Y(X=X_raw, transformation = transformation)
  # And transpose the X to MultiAssayExperiment format, then construct the MAE
  mae <- MultiAssayExperiment::MultiAssayExperiment(
    experiments = lapply(X_raw, t),
    colData = Y)
  return(mae)
}


# Call the main function
main(
  n=as.numeric(opt$number_obs),
  sigma= opt$sigma,
  corr = opt$corr,
  transformation = opt$transformation
)
