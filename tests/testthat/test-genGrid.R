library(testthat)
library(here)
source(here("tests/testthat/sample_data_tests.R"))
source(here("modules/R/classification/diablo/helpers/genGrid.R"))
context("Running genGrid")
# Get block names
block_names <- names(X)
# Grids
long_grid <- c(seq(5,9, 1), seq(10, 18, 3), seq(20, 50, 10))
short_grid <- c(seq(5,45, 10))
# Evaluated funs
# The invisible(capture.output(...)) is to hide the cat messages within
# the functions evaluated
invisible(capture.output(short_eval <- genGrid(block_names, short = TRUE)))
invisible(capture.output(long_eval <- genGrid(block_names, short = FALSE)))

# Expected outputs
expected_output_short <-  list(mrna=short_grid,
                               protein=short_grid,
                               cc=short_grid,
                               mirna=short_grid)

expected_output_long <- list(mrna=long_grid,
                             protein=long_grid,
                             cc=long_grid,
                             mirna=long_grid)
# Test if getting correct output
test_that("Returning right output", {

  # Test   
  expect_equal(short_eval, 
               expected_output_short)
  
  expect_equal(long_eval,
               expected_output_long)
})

# Test if get matching names from blocks
test_that("Returning right blocks names", {
  expect_equal(names(short_eval), block_names)
  expect_equal(names(long_eval), block_names)
})

# Test if matching dimensions
test_that("Matched dimensions of output list with input", {
  expect_equal(dim(short_eval), dim(block_names))
  expect_equal(dim(long_eval), dim(block_names))
})
