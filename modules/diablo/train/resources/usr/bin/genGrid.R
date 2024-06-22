# generate grid for keepX 
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

