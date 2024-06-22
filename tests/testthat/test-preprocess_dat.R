# Skip test

# Tests should follow below format
library(here)
library(caret)
source(here("tests/testthat/sample_data_tests.R"))
source(here("modules/R/generic_helpers/preprocess_dat.R")) # Fill in here to test some functions
# Parameters/input block
n <- 5
rows <- 1:n
cols <- c(seq(5,2,-1))
X_small <- setNames(lapply(seq_along(X), function(i) {
  subset_mat <- X[[i]][rows, 1:cols[i]]
  return(subset_mat)
}), names(X))


# Evaluated functions

# The invisible(capture.output(...)) is to hide the cat messages within
# evaluated function to test
# Expected outputs
fail("Add expected outputs here")

# Test if getting correct output
test_that("Returning right output", {
  # Expected outputs
  fail("Not implemented")
})

# Test if get matching names from blocks
test_that("Another characteristic", {
  fail("Not implemented")
})

# Test if matching dimensions
test_that("Another characteristic", {
  fail("Not implemented")
})


