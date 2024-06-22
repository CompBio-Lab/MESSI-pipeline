library(mixOmics)
# =================================================
# Some helper functions
genGrid <- function(block_names, short=FALSE) {
  sequence_fun <- function(name, short) {
    if (short) {
      return(c(seq(5,45, 10)))
    } else{
      return(
				c(
				seq(5,9, 1),
				seq(10, 18, 3),
				seq(20, 50, 10)
				)
			)
      # Consider using ncol(current_matrix) to be the last item
      # of grid, it would be different per matrix
    }
  }
  if (short) {
    cat("\nUsing shorter sequence of grid\n")
  } else {
    cat("\nUsing normal sequence of grid\n")
  }
  # Feed in the data directly instead of using block_names
  # Could change in function parameter
  # sapply (data, ncol) and ncol (check this) !!!!!!!!!!!!!!!!!
  grids <- lapply(block_names, sequence_fun, short=short)
  output <- setNames(grids, nm = block_names)
  return(output)
}

getDesign <- function(X, corr=0.1) {
  cat("\nGenerating design matrix\n")
  if (is.null(corr)) {
    cat("Could not find corr, using default")
    corr <- 0.1
    
  }
  if (corr > 1) {
    cat("Correlation between blocks should be <= 1, using default 0.1")
    corr <- 0.1
  }
  # for square matrix filled with 0.1s, diag 0
  design <- matrix(
		corr, ncol = length(X), nrow = length(X), 
		dimnames = list(names(X), names(X))
		)
  diag(design) <- 0
  cat("\nGenerated design matrix\n")
  return(design)
}


# function should tune parameters
tune_diablo <- function(base_model, design, dist="centroids.dist", validation='Mfold', folds=10, 
                        nrepeat=10) {
  #----------------------------------------------------------------------------
  # Tune ncomp, possible plots
  cat("\nStarting to tune for ncomp\n")
  perf_diablo <- perf(base_model, validation = validation, 
                      folds = folds, nrepeat = nrepeat)
  cat("\nFinished tuning ncomp\n")
  opt_ncomp <- perf_diablo$choice.ncomp$WeightedVote["Overall.BER", dist]
  if (length(opt_ncomp) > 1) {
    opt_ncomp <- opt_ncomp[[1]]
  }
  #----------------------------------------------------------------------------
  # Feature selections
  block_names <- names(base_model$X)
  test.keepX <- genGrid(block_names = block_names, short=TRUE)
  # Note ncomp here is tuned from perf_diablo already
  cat("\nStaring to tune for number of features to keep per block\n")
  tune_features <- tune.block.splsda(X = base_model$X, Y = base_model$Y, 
                                     ncomp = opt_ncomp, 
                                     test.keepX = test.keepX, 
                                     design = design,
                                     validation = validation, 
                                     folds = folds, nrepeat = nrepeat,
                                     dist = dist)
  cat("\nFinished tuning keepX\n")
  
  list_keepX <- tune_features$choice.keepX
  #-----------------------------------------------------------------------------
  tuned_output <- list(tune_mod=perf_diablo, ncomp=opt_ncomp, 
                       tune_features=tune_features,
                       keepX = list_keepX)
  #----------------------------------------------------------------------------
  # Save to disk
  cat("\nWriting tuned objects to file\n")
  saveRDS(tuned_output, "tuned_output.rds")
  # lapply(names(tuned_output), function(name) saveFile(object=tuned_output[[name]],
  #                                                     name=name, ext=".rds"))
  cat("\nFinished writing tuned objects to file\n")
  return(tuned_output)
  
}