testthat::context("Running transformation")
library(here) # To locate function script to test, and helper data/script
source(here("tests/testthat/sample_data_tests.R"))
source(here("modules/R/generic_helpers/transformation.R"))
# Parameters/input block ------------------------------------------------------
n <- 3
m <- 6
y_small <- Y[n:m]
tr_sig <- "sigmoid"
tr_soft <- "softmax"
# Evaluated functions
eval_sig <- y_small |> transformation(tr=tr_sig)
eval_soft <- y_small |> transformation(tr=tr_soft)
# Expected outputs
expected_sig <- sigmoid(y = y_small)
expected_soft <- softmax(y=y_small)
# Test blocks -----------------------------------------------------------------
# Test if getting correct output
test_that("Returning right output", {
  # Expected outputs
  expect_equal(eval_sig, expected_sig)
  expect_equal(eval_soft, expected_soft)
})

# Test if getting right type of output
test_that("Right type of output", {
  expect_is(eval_sig, "numeric")
  expect_is(eval_soft, "numeric")
  expect_type(eval_sig, "double")
  expect_type(eval_soft, "double")
})

# Test if matching dimensions
test_that("Matching dimensions", {
  expect_length(eval_sig, length(y_small))
  expect_length(eval_soft, length(y_small))
})


