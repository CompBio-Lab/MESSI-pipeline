#!/usr/bin/env Rscript

# Doc section --------------------------------------------------------------
'This is the script to simulate data with X block , Z block, and a response 
vector R. The output is a list in R. By default it writes the rds file 
to current directory.

Author: Tony Liang

Usage:
  simulate_data.R [options]
    
Options:
  -n N --number=N                 Number of observations [default: 200]
  --num_predictors=P              Number of predictors to use [default: 500]
  -m M --block_num=M              Number of blocks to generate [default: 3]
  --latent_predictors=IMP         Number of latent predictors [default: 30]
  -s SIGMA --sigma=SIGMA          Noise strength to add into response [default: 39]
  --sy=SY                         Standard deviation of Y [default: 1]
  --sp=SP                         Standard deviation of block components [default: 3]
  --u_std=U_STD                   Standard deviation of normal distributed U [default: 1]
  --fct_str=FCT_STR               Factor strength [default: 7] 
  --task=TASK                     Type of response, binary/categorical [default: categorical]
  --tr=TRANSFORM                  Transformation on response, one of sigmoid or softmax [default: sigmoid]
	--dataset_name=DATASET_NAME			Name of data to save [default: sim_data]
  --seed=SEED                     Seed to reproduce [default: 1]
  --y_name=Y_NAME                 Column name for the response var [default: response]
' -> doc

# Load libraries
library(dplyr)
library(magrittr)
library(here)

# TODO: very uggly fix
bin_dir <- Sys.getenv("PATH") |> 
    strsplit(":") |>
    unlist() |>
    tail(1)
pipeline_dir <- gsub("/bin", "", bin_dir)
print(pipeline_dir)
# Loading scripts
source(here(pipeline_dir, "bin/rhelpers.R")) # This is included in nextflow bin path
# Load utils specific to simulation data
rp <- resource_helper_path(here(pipeline_dir, "modules/simulation/simulate_mvn_data"))
source(here(rp, "gen_simul_metadata.R"))
source(here(rp, "unique_matrices.R"))
# Loading generic utils
load_utils(here(pipeline_dir, "bin/logging"))
load_utils(here(pipeline_dir, "bin/preprocessing"))
source(here(pipeline_dir, "bin/savers/saveFile.R"))
# ============================================================================
# Parse above doc
opt_chr <- docopt::docopt(doc)
opt <- opt2num(opt_chr) 
# Functions  -----------------------------------------------------------------
# Generating process of data
# Source from https://www.pnas.org/doi/full/10.1073/pnas.2202113119
simulate_data <- function(
  n, p, m, p_imp, sigma, sy,
  sp, u_std, fct_str,
  task = c("continuous","binary", "categorical"),
  tr=c("sigmoid", "softmax"), 
  y_name
  ) {
  # Match arguments ----------------------------------------------------------
  task <- match.arg(task)
  tr <- match.arg(tr)
  # Logging stuff ------------------------------------------------------------
  args_used <- c(as.list(environment()))
  logging_params(args_used) # custom function to format and log
  # Record time to track execution time
  start_time <- Sys.time()
  # Check p_imp not greater than any of px or pz
  if ( p_imp > p) {
    print("p_imp cannot be > p, using default: 30")
    p_imp <- 30
  }
  
  # Instantiation  -----------------------------------------------------------
  blocks  <- unique_matrices(m=m, n=n, p=p, mu1=2, mu2=8, shift=TRUE)
  U = matrix(rep(0, n*p_imp), n, p_imp)
  
  # Relate U until p_imp columns in each mat of the mat_list
  for (j in seq(p_imp)) {
    # Random noise with sd of u_std (default 1)
    u = rnorm(n, sd = u_std)
    # Add noise to each j-th column that are "latent predictor" in block
    blocks <- lapply(blocks, function(block) {
      block[, j] <- block[, j] + sp * u
      return(block)
      })
    # Do same thing to the U matrix 
    U[, j] = U[, j] + sy * u
  }
  # Center and not scale these accordingly
  blocks <- lapply(blocks, scale, center=TRUE, scale=FALSE)
  # Create beta matrix and Y
  beta_U = c(rep(fct_str, p_imp))
  mu_all = U %*% beta_U
  # Continuous way, transform it later
  z <- mu_all + sigma * rnorm(n)
  # Metadata generation -----------------------------------------------------
  metadata <- gen_simul_metadata(blocks=blocks, z=z, tr=tr, task=task, response_name=y_name)
  # More logging to exit
  elapsed <- Sys.time() - start_time
  cat("\nTime taken to simulate data:", round(elapsed, 6), "seconds\n")
  cat("\nData simulated!\n")
  # TODO: This seems a bit hardcoded, but should have blocks that have all the omics
  #       while metadata should contain at least two columns, sample_names and response
  return(dat=list(blocks=blocks, metadata=metadata))
}

# Main entrance of the scripts
main <- function(number, num_predictors, blocks_num,
                p_imp, sigma, sy, sp, u_std, 
                factor_strength, task, tr,
                dataset_name, y_name, prefix="") {
  
  cat("Generating simulation... \n")
  # Invoke simulate data
  
  dat <- simulate_data(n=number, p=num_predictors, m=blocks_num,
                      p_imp=p_imp, sigma=sigma, sy = sy, sp=sp, 
                      u_std=u_std, fct_str=factor_strength, task=task,
                      tr=tr, y_name=y_name)
  # Time to write data
  write_start <- Sys.time()
  # To MAE and MuData
  saveFile(dat, name=dataset_name, prefix=prefix, output_format="MAE")
  saveFile(dat, name=dataset_name, prefix=prefix, output_format="MuData")
  # Log to end
  logging_write_disk(write_start = write_start)
  # Write metadata to file as well
  return(dat)
}

# Set seed to guarantee reproducible result (DELETE Later)
#SEED = opt$seed
#set.seed(SEED)
dat <- main(
    number          = opt$number, 
    num_predictors  = opt$num_predictors,
    blocks_num      = opt$block_num, 
    p_imp           = opt$latent_predictors,
    sigma           = opt$sigma,
    sy              = opt$sy,
    sp              = opt$sp,
    u_std           = opt$u_std,
    factor_strength = opt$fct_str,
    task            = opt_chr$task,
    tr              = opt_chr$tr,
    dataset_name	  = opt_chr$dataset_name,
    y_name          = opt_chr$y_name
  )


