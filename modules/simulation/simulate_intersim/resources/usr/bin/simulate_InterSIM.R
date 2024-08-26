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
  --number_noise_vars=H   Number of noise variables to create [default: 200]
  --effect=EFFECT         Cluster mean shift on each view [default: 2]
  --sigma=SIGMA           Covariance structure in the each omics's data, one of def, indep [default: indep]
  --noise=NOISE           Gaussian noise standard deviation [default: 1]
  --corr=CORR             Correlation between each omics, one of: 0, 0.5, 1 . [default: 0]
  --transformation=TR     Transformation to apply of the generated X to derive the response variable [default: rev_logit]
"
# ==============================================================================
# Parse cli arguments
opt <- docopt::docopt(doc)
# Load library
library(InterSIM)
library(dplyr)
library(magrittr)

# Helper to convert mae to h5mu on mudata
save_h5mu <- function(mae, dataset_name) {
  # Takes the MAE experiment and save this as MuData
  exps <- mae@ExperimentList |> lapply(t)
  col_data <- mae@colData |> as.data.frame()
  feat_names <- mae@ExperimentList |> lapply(rownames)
  # Then calls python code here
  reticulate::use_python("/usr/bin/python")
  # Gather the pipeline dir (THIS IS VERY UGGLY FIX)
  bin_dir <- Sys.getenv("PATH") |> 
    strsplit(":") |>
    unlist() |>
    tail(1)
  is_scratch <- stringr::str_detect(bin_dir, pattern = "scratch")
  if (is_scratch) {
    pipeline_dir <- gsub("/bin", "", bin_dir)
  } else {
    pipeline_dir <- ""
  }
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

generate_Y <- function(response_df, id_name="sample_name", response_name="response") {
  # Maybe should not create the y by clustering it, otherwise method will catch it 100%?
  if(!("subjects" %in% colnames(response_df) && "cluster.id" %in% colnames(response_df))) {
    stop("The columns 'subjects' and 'cluster.id' must exist in the response dataset.")
  }
  meta_df <- response_df %>%
    rename( 
      {{ id_name }} := subjects,
      {{ response_name }} := cluster.id
    )  %>%
    # The response vector is numeric already
    # INTERSIM gives 3 clusters, so we only keep the first two 1 and 2
    filter( !!sym(response_name) != 3) %>%
    mutate( {{ response_name }} := !!sym(response_name) - 1)
  # Manually assign the rownames back, since MAE uses rownames of colData to
  # match those colnames of the X matrix (P_j x n)
  rownames(meta_df) <- meta_df |> pull( {{ id_name }} )
  return(meta_df)
}


# ============================================================================
# HANDLING THE X LIST OF OMICS MATRICES
# ============================================================================
# TODO: many functions here should be moved to other files

# Helper to apply gaussian noise to each col or row of a matrix
add_gaussian_noise <- function(x, noise_mean = 0, noise_sd = 1) {
  # X could be a column vector or row vector
  noise <- rnorm(length(x), mean=noise_mean, sd=noise_sd)
  new_x <- x + noise
  return(new_x)
}

# Helper to generate H noise variables given matrix of n x p , where
# n is number of subjects, p is number of variables.
# By design, these noisy variables have higher sd than existing ones

generate_gaussian_noise_vars <- function(omic_matrix,  H=100, sd_multiplier = 1.5) {
  # Convenient var
  n <- nrow(omic_matrix)
  # Calculate standard deviation of existing variables
  existing_sd <- apply(omic_matrix, 2, sd, na.rm = TRUE) # This is a vector
  # Purposedly let sd of noise vars higher
  noise_data <- rnorm(n * H, mean = 0, sd = sd_multiplier * mean(existing_sd) )
  noise_vars_matrix <- matrix(noise_data, nrow=n, ncol=H)
  # Generate H noise variables
  # noise_vars_matrix <- replicate(H, {
  #   # For each new noise variable, use a standard deviation larger than existing ones
  #   noise_sd <- sd_multiplier * mean(existing_sd, na.rm = TRUE)
  
  #   # Generate random values with increased standard deviation
  #   runif(n = nrow(matrix), min = min(matrix, na.rm = TRUE), max = max(matrix, na.rm = TRUE))
  # }, simplify = TRUE)
  return(noise_vars_matrix)
}

generate_bimodal_noise_vars <- function(n,  H=100,
                                        beta_shape1 = 2, beta_shape2 = 2, 
                                        scale_1 = 2, shift_1 = 1, 
                                        scale_2 = 2, shift_2 = 3,
                                        bimodal = TRUE) {
  
  
  # Generate beta-distributed data for n rows and H columns
  noise_data <- rbeta(n*H, shape1 = beta_shape1, shape2 = beta_shape2)
  # Stored to matrix
  noise_vars_matrix <- matrix(noise_data, nrow = n, ncol = H)
  if (!bimodal) {
    message("Returning beta distributed noise vars")
    return(noise_vars_matrix)
  }
  # Create bimodal effect by applying different scaling and shifting to the two halves
  first_half <- 1:(n / 2)
  second_half <- (n / 2 + 1):n
  # Then modify these two halves
  noise_vars_matrix[first_half,  ]  <- noise_vars_matrix[first_half,  ] * scale_1 + shift_1
  noise_vars_matrix[second_half, ]  <- noise_vars_matrix[second_half, ] * scale_2 + shift_2
  return(noise_vars_matrix)
}


# Get the X omics matrices and add numbers of noise variable in each matrix
# And add additional noise to existing vars (including those noise variables)
generate_X <- function(X_raw, meta_df, H, noise_mean=0, noise_sd=1, sd_multiplier=1.5) {
  # Rename its prefix of dat.<view_name>
  X_names <- gsub("dat.", "", names(X_raw))
  # The sample names in clusters 1 and 2
  keep_samples <- rownames(meta_df)
  X <- lapply(names(X_raw), function(omic_name, H, noise_mean, noise_sd, sd_multiplier) {
    omic <- X_raw[[omic_name]]
    # Keep relevant observations, since some belong to cluster 3 which is not included
    if (!all(keep_samples %in% rownames(omic))) {
      stop("Some keep_samples are not found in the omic matrix.")
    }
    x_mat <- omic[keep_samples, ]
    # Some conveninent vars
    n <- nrow(x_mat)
    # Check for methylation data, since they are beta distributed of [0, 1]
    is_beta_distributed <- all(x_mat >= 0 & x_mat <= 1)
    if (is_beta_distributed) {
      # This specifically handles methyl data
      beta_shape = 2
      beta_scale = 2
      shift_1 = 1
      shift_2 = 3
      # Uses bimodal distribute noise
      noise_vars_matrix <- generate_bimodal_noise_vars(
        n=n, H=H, 
        beta_shape1=beta_shape, beta_shape2=beta_shape, 
        scale_1=beta_scale, shift_1=shift_1, 
        scale_2=beta_scale, shift_2=shift_2
      )
    }
    
    # Otherwise always use gaussian noise variables
    noise_vars_matrix <- generate_gaussian_noise_vars(omic_matrix=x_mat, H=H, sd_multiplier=sd_multiplier)
    # Append dummy name to columns
    # TODO: this bit could be redundant of removing prefix?
    omic_name_no_prefix <- gsub("dat.", "", omic_name)
    colnames(noise_vars_matrix) <- paste(omic_name_no_prefix, "noise_var", seq_len(H), sep="_")
    # Then combine the noise variables to the var matrix
    x_mat_full <- cbind(x_mat, noise_vars_matrix)
    # https://stats.stackexchange.com/questions/144410/how-to-add-noise-to-a-random-variable-whose-range-is-the-unit-interval
    # TODO: might need to check if this doing right here
    # Then for each column add gaussian noise
    x_mat_full <- apply(x_mat_full, 2, function(col) add_gaussian_noise(col, noise_mean=noise_mean, noise_sd=noise_sd))
    
    # And transpose the X to MultiAssayExperiment format
    return(t(x_mat_full))
  }, H=H, noise_mean=noise_mean, noise_sd=noise_sd, sd_multiplier=sd_multiplier)
  names(X) <- X_names
  return(X)
}



# Main entrace of the function
main <- function(dataset_name, output_format, 
                 n, effect, noise, H=200,
                 cluster.sample.prop = c(0.45,0.45,0.1),
                 p.DMP=0.2, p.DEG=NULL, p.DEP=NULL, 
                 sigma=c("indep", "def"), 
                 corr=0,
                 transformation="rev_logit"
) {
  
  # Stop when no custom dataset name is provided
  if (dataset_name == "empty") stop("Did not provided a custom dataset for simulation of intersim")
  if (output_format == "empty") stop("Did not provided the format of data to write out for simulation of intersim")
  # Match args of sigma
  sigma <- match.arg(sigma)
  if (sigma == "def") {
    sigma <- NULL
  }
  
  
  # First generate the count data from InterSIM
  # TODO: The interSIM pkg doesnt have a way to change number of features in each omic
  # fixed to their defaults ....
  
  # Given cluster propotions are c(0.45, 0.45, 0.1), where last cluster is always dropped after creation
  # So need to adjust that raw n to cancel this effect and having enough obsercations as stated.
  # Using this formula: n* = ceiling(raw_n / 0.9)
  # For example, if one want to simulate n = 50, then n* need to be ceiling(50 / 0.9) = 56
  # Then, 0.45 * 56 = 25.2 , 0.1 * 56 = 5.6
  # We can then only keep floor(25.2 + 25.2 ) = 50 which yields original n required
  adjusted_n <- ceiling(n / 0.9)
  dat <- InterSIM(n.sample=adjusted_n,
                  cluster.sample.prop=cluster.sample.prop,
                  delta.methyl = effect, delta.expr = effect, delta.protein = effect,
                  p.DMP=p.DMP,p.DEG=p.DEG, p.DEP=p.DEP, 
                  sigma.methyl=sigma, sigma.expr=sigma, sigma.protein=sigma,
                  cor.methyl.expr=corr, cor.expr.protein=corr)
  
  
  # Ignore its cluster assignment for now
  n_list <- length(dat)
  # We retaining only cluster 1 and 2 subjects, so need to first process meta then on X
  Y_df <- generate_Y(response_df=dat[[n_list]])
  # Process the X as well with suitable parameters to control noise generation
  # Let X be a J length list of n (row) x p (column) matrix
  # 1. Generate H noise variables of either:
  #    a) Normal distributed with mean 0 , sd = sd_multiplier *  mean(existing_sd of each column) of current omic and iterate for J omics
  #       This way noise has a higher spread than actual signal variables
  #
  #    b) Multimodal distributed derived from Beta Distribution shapes are fixed to be same
  #
  #
  # 2. Add only gaussian noise of mean = 0, sd = noise_sd , where noise sd is cli param to vary
  # Note: this get added to those previous noise variables, so could be double source of noise
  # And it also gets added to non normally distributed omics like the ones of Methylation
  # which is stricly Beta distributed.
  X <- generate_X(X_raw = dat[1:n_list - 1], meta_df=Y_df, H=H, noise_sd=noise)
  # Construct the X and Y here
  mae <- MultiAssayExperiment::MultiAssayExperiment(
    experiments = X,
    colData = Y_df
  )
  
  
  # Then should convert mae to mudata h5mu
  if (tolower(output_format) == "mudata") {
    save_h5mu(mae, dataset_name)
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
dat <- main(
  dataset_name = opt$dataset_name,
  output_format = opt$output_format,
  n = as.numeric(opt$number_obs),
  H = as.numeric(opt$number_noise_vars),
  effect = as.numeric(opt$effect),
  sigma = opt$sigma,
  corr = as.numeric(opt$corr),
  transformation = opt$transformation,
  noise = as.numeric(opt$noise)
)

dat