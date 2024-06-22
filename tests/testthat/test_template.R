# Skip test (keyword check in testthat.R)

# Tests should follow below format
library(here) # To locate function script to test, and helper data/script
source(here("tests/testthat/sample_data_tests.R"))
source(here("modules/R/...")) # Fill in here to test some functions
# Parameters/input block
fail("Add parameters here to test")
# Evaluated functions
# The invisible(capture.output(...)) is to hide the cat messages within
# evaluated function to test
fail("Add evaluated outputs here withi invisible(capture.output(... <- ...))")
invisible(capture.output(variable_name <- some_function(a,b,c)))
invisible(capture.output(another_variable_name <- some_function(a,b,c)))

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


