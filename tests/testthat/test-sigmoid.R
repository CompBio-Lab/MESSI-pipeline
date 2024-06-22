testthat::context("Running sigmoid")
library(here) # To locate function script to test, and helper data/script
source(here("tests/testthat/sample_data_tests.R"))
source(here("modules/R/generic_helpers/sigmoid.R")) 
# Parameters / Input ---------------------------------------------------------
y_small <- c(1:3)
e_pow <- exp(y_small)
# Expected output
expected_sigmoid <- e_pow / (1 + e_pow)
# Evaluated funs
eval_sigmoid <- sigmoid(y_small)
# Test block -----------------------------------------------------------------
# Test if getting correct output
test_that("Returning right output", {
  # Expected outputs
  expect_equal(eval_sigmoid, expected_sigmoid)
})

# Test if get matching names from blocks
test_that("Right type of output", {
  expect_is(eval_sigmoid, "numeric")
  expect_type(eval_sigmoid, "double")
  expect_true(is.vector(eval_sigmoid))
})

# Test if matching dimensions
test_that("Matching dimension", {
  expect_length(eval_sigmoid, length(y_small))
  expect_equal(length(eval_sigmoid), length(expected_sigmoid))
})

# Test each entry should be in (0 , 1)
test_that("All entry is in (0,1)", {
  expect_true(all(eval_sigmoid > 0))
  expect_true(all(eval_sigmoid < 1))
})




