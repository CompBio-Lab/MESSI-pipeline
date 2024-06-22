# transform
transform_y <- function(y, tr="sigmoid", res="factor") {
  if (tr == "sigmoid") {
    out <- 1 / (1 + exp(-y))
  }
  y_fact <- ifelse(out >= 0.5, "yes", "no") |>
            as.factor()
  return(y_fact)
}

# Blocks
n <- 25
m <- 75
mu <- 5
s <- (m - n) / mu
set.seed(329)
X <- list(mrna = matrix(rnorm(n, mu), nrow = n, ncol = m),
          protein = matrix(rnorm(n, n/mu), nrow=n, ncol=m+n) , 
          cc = matrix(rnorm(n, n/mu + mu), nrow=n , ncol=mu * n), 
          mirna = matrix(rnorm(n, n %/% (mu+mu)), nrow=n, ncol= (m-n)*mu)
)

# Assign column names
X <- lapply(X, function(mat) {
  colnames(mat) <- 1:ncol(mat)
  return(mat)
})

Y <- rnorm(n = n , mean = s/mu, sd = s) 

Y_fct <- Y |>
      transform_y(tr = "sigmoid", res="factor")
