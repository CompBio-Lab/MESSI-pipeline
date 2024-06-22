testthat::context("Running binaryY")
library(here) # To locate function script to test, and helper data/script
source(here("tests/testthat/sample_data_tests.R"))
source(here("modules/R/generic_helpers/binaryY.R")) # Fill in here to test some functions
# Parameters / input -----------------------------------------------
n <- 3
y_small <- Y_fct[1:n]
# Expected output
expected_ybin <- c(0,1,0)
# Evaluated functions
eval_ybin <- Y_fct[1:n] |> binaryY()
# Test block ------------------------------------------------------
# Test if getting correct output
test_that("Returning right output", {
  # Expected outputs
  expect_equal(eval_ybin, expected_ybin)  
})

# Test if matching dimensions input and output
test_that("Matching dimension", {
  expect_length(eval_ybin, n)
  expect_equal(length(eval_ybin), n)
})

# Test if right type of output
test_that("Right type of output", {
  expect_is(eval_ybin, "numeric")
  expect_type(eval_ybin, "double")
})


