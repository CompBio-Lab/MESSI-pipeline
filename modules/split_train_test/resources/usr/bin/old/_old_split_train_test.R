#==============================================================================
"This is the script to simulate data with X block , Z block, and a response
vector R. The output is a list in R. By default it writes the rds file
to current directory.

Author: Tony Liang

Usage:
    split_train_test.R  [options]

Options:
    --path=MAE_PATH         Path to read in the MultiExperimentAssay
    --extension=EXT         Extension of output write data [default: .rds]
    --train_frac=TRAIN_FRAC Train portion of the split [default: 0.7]
    --alpha=ALPHA           Tuning hyperparameter [default: 0.5]
" -> doc
#==============================================================================


# Parse above doc
opt <- docopt::docopt(doc)
# Source the common helpers
source(here::here("modules/R/generic_helpers.R"))


# TODO: Another path needs to be added for the extra matrix 
# Split the train and test data

# Input would be hold MAE that contains the 






main <- function(path,  
                 train_frac, alpha, extension, ...) {
  args_used <- c(as.list(environment()))
  logging_params(args_used) # custom function to format and log
  # Record time to track execution time
  start_time <- Sys.time()
  
  # Read in RDS, previously computed from simulation
  # blocks <- readRDS(block_path)
  # mae
  # x <- blocks$x
  # z <- blocks$z
  # w <- blocks$w
  # y <- readRDS(y_path)
  # Get the sample size and make sure its same across blocks and response
  if (!(nrow(x) == length(y) && nrow(x) == nrow(z))) {
    stop("Sample sizes are not the same across blocks, check your dimensions.")
  }
  
  n <- length(y)
  
  # Split train and test sets
  #smp_size_train = floor(train_frac * nrow(x))
  smp_size_train = floor(train_frac * n)
  train_idx = sort(sample(seq_len(n), size = smp_size_train))
  test_idx = setdiff(seq_len(n), train_idx)
  
  # Get the raw matrix after selecting indices
  # "X" block
  # First block
  train_x_raw <- x[train_idx, ]
  test_x_raw <- x[test_idx, ]
  # Second block
  train_z_raw <- z[train_idx, ]
  test_z_raw <- z[test_idx, ]
  # Third block
  train_w_raw <- w[train_idx, ]
  test_w_raw <- w[test_idx, ]
  
  # Get preprocess matrix from the raw matrices above
  # By default of center and scale
  
  # TODO: Need to conside adding the extra block, and treat them as different csv pre splitted and saved to
  #       path, might need to look at mogonet example for this
  
  
  # X splits
  train_x <- preprocess_dat(mat = train_x_raw)
  test_x <- preprocess_dat(mat = test_x_raw)
  # Z splits
  train_z <- preprocess_dat(mat = train_z_raw)
  test_z <- preprocess_dat(mat = test_z_raw)
  # W splits
  train_w <- preprocess_dat(mat=train_w_raw)
  test_w <- preprocess_dat(mat=test_w_raw)
  # response (Y) split (note y is originally a vector)
  train_y <- y[train_idx]
  test_y <- y[test_idx]
  
  # Join blocks
  train_data <- list(blocks = list(X=train_x, Z = train_z, W=train_w),
                     response = train_y)
  test_data <- list(blocks = list(X = test_x, Z = test_z, W=test_w),
                    response  = test_y)
  
  elapsed <- Sys.time() - start_time
  cat("\nTime taken to split data:", round(elapsed, 6), "seconds\n")
  cat("\nData splitted!\n")
  # Write to disk
  dat=list(train_data=train_data, test_data=test_data)
  
  write_start <- Sys.time()
  cat("\nWriting to disk:", names(dat), "\n")
  lapply(names(dat), function(name) saveFile(object=dat[[name]],
                                             name=name, ext=extension))
  logging_write_disk(write_start = write_start)
  
  
  return(dat)
}

# Set seed to reproduce
set.seed(329)

# Invoke function
split_tr_te <- main(path  = opt[["path"]],
                    test_frac  = as.numeric(opt[["test_frac"]]),
                    alpha       = as.numeric(opt[["alpha"]]),
                    extension   = opt[["extension"]])

