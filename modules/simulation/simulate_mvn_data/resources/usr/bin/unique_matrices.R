# Helpers for unique matrices
gen_p <- function(m, n , p, size=1) {
  mu <- p / n
  noise <- floor(rnorm(1, mean=mu, sd=p%/%m)) + m 
  unique_p <- p + noise
  return(unique_p)
}

# Could shift means by nth observations now
gen_rand_data <- function(n, unique_p, mu1, mu2, shift) {
  # index of nth number to have different mu
  j <- floor(n / 2)
  if (shift == FALSE) {
    # If want not shift then we have same means
    mu1 <- mu2 <- 5 # randomly chose 5
  }
  means <- c(rep(mu1, j), rep(mu2, n-j))
  dat <- rnorm(n * unique_p ,mean=rep(means, unique_p))
  return(dat)
}

# Main function ----------------------------------------------
unique_matrices <- function(m, n, p, mu1=2, mu2=8, shift=TRUE) {
  mat_list <- list()
  # m should not be greater than 26 though
  for (i in 1:m) {
    label <- LETTERS[i] # Use letters as unique labels (a, b, c, ...)
    bname <- paste0(label, "_BLOCK")
    #unique_p <- getNumPredictors(p, ft_str, sigma)
    unique_p <- gen_p(m, n, p)
    dat <- gen_rand_data(n, unique_p, mu1=mu1, mu2=mu2, shift=shift)
    mat <- matrix(dat, n, unique_p)
    colnames(mat) <- paste0(label, 1:ncol(mat))
    rownames(mat) <- paste0("pat-", 1:nrow(mat))
    mat_list[[bname]] <- mat
  }
  return(mat_list)
}

