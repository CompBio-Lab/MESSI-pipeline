testthat::context("Running getDesign")
library(here)
source(here("tests/testthat/sample_data_tests.R"))
source(here("modules/R/classification/diablo/helpers/getDesign.R"))
# Setup block   -------------------------------------------------------------
# Parameters used
corr <- 0.7 
dim_names <- c("mrna", "protein", "cc", "mirna")
k <- length(dim_names)
# Expected results
expected_design_def <- matrix(0.1, nrow=k, ncol=k,
                              dimnames = list(dim_names, dim_names))
expected_design <- matrix(corr, nrow=k, ncol=k,
                          dimnames = list(dim_names, dim_names))
diag(expected_design_def) <- 0
diag(expected_design) <- 0
# Evaluated results
invisible(capture.output(evaluated_design_def <- getDesign(X=X)))
invisible(capture.output(evaluated_design <- getDesign(X=X, corr=corr)))
# Testing block ----------------------------------------------------------------
# Test if right output
test_that("Test right computation", {
  expect_equal(evaluated_design_def, expected_design_def)
  expect_equal(evaluated_design, expected_design)
})

# Test if dimensions of matrices match
test_that("Matching dimensions", {
  expect_equal(dim(evaluated_design), dim(expected_design))
  expect_equal(dim(evaluated_design_def), dim(expected_design_def))
})

# Test if generated is still double matrix
test_that("Right type of output", {
  expect_type(evaluated_design, "double")
  expect_type(evaluated_design_def, "double")
  expect_true(is.matrix(evaluated_design) && is.array(evaluated_design))
  expect_true(is.matrix(evaluated_design_def)  && is.array(evaluated_design_def))
  expect_output(str(evaluated_design), "num")
  expect_output(str(evaluated_design_def), "num")
})
