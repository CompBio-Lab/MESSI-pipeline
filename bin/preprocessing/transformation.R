#tr_path <- here::here("bin/preprocessing/")
#source(here::here(tr_path, "sigmoid.R"))
#source(here::here(tr_path, "softmax.R"))

# softmax
softmax <- function(z) {
  e_pow <- exp(z)
  sums <- sum(e_pow)
  out <- e_pow / sumsk
  return(out)
}

# sigmoid
sigmoid <- function(z) {
  return(1 / (1 + exp(-1 * z)))
}

transformation <- function(z, tr) {
  if (tr == "sigmoid") return(sigmoid(z=z))
  if (tr == "softmax") return(softmax(z=z))
}