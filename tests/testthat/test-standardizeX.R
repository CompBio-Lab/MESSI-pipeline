testthat::context("Running standardizeX")
# Tests should follow below format
library(here) # To locate function script to test, and helper data/script
source(here("tests/testthat/sample_data_tests.R"))
source(here("modules/R/generic_helpers/standardizeX.R"))
# Parameters/input block ------------------------------------------------------
n <- 5
m <- 13
rows <- 1:n
cols <- c(seq(n, n - 3, -1))
# Smaller list of matrices with 5 rows fixed, and less cols per matrix 
# (different in each)
expected_X <- X_small <- setNames(lapply(seq_along(X), function(i) {
  subset_mat <- X[[i]][rows, 1:cols[i]]
  return(subset_mat)
}), names(X))

# To evaluate
X_bad <- lapply(X_small, t)
eval_X <- standardizeX(X_bad)
# Test block ------------------------------------------------------------------
# Test if getting correct output
test_that("Returning right output", {
  expect_equal(eval_X, expected_X)
})

# Test if get matching names from blocks
test_that("Matching names of blocks", {
  expect_named(eval_X, names(X)) 
  expect_equal(names(eval_X), names(X))
  # randomly check index if matched
  expect_equal(names(eval_X)[2], "protein")
  expect_length(eval_X, length(names(X)))
})

# Test if correct type
test_that("Right type of output", {
  expect_type(eval_X, "list")
  expect_output(str(eval_X), "num")
})

# Test if matching dimensions
test_that("Dimensions matched", {
  expect_true(all(dim(eval_X)[1] == n))
  expect_length(eval_X, length(expected_X))
})


