testthat::context("Running softmax")
library(here) # To locate function script to test, and helper data/script
source(here("tests/testthat/sample_data_tests.R"))
source(here("modules/R/generic_helpers/softmax.R")) 
# Parameters / Input
y_small <- c(1:3)
y_sum <- sum(exp(y_small))
# Expected output
expected_softmax <- exp(y_small) / y_sum
# Evaluated funs
eval_softmax <- softmax(y_small)
# Test if getting correct output
test_that("Returning right output", {
  # Expected outputs
  expect_equal(eval_softmax, expected_softmax)
})

# Test if get matching names from blocks
test_that("Right type of output", {
  expect_is(eval_softmax, "numeric")
  expect_type(eval_softmax, "double")
  expect_true(is.vector(eval_softmax))
})

# Test if matching dimensions
test_that("Matching dimension", {
  expect_length(eval_softmax, length(y_small))
  expect_equal(length(eval_softmax), length(expected_softmax))
})

# Test each entry should be in (0 , 1)
test_that("All entry is in (0,1)", {
  expect_true(all(eval_softmax > 0))
  expect_true(all(eval_softmax < 1))
})




