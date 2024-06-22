# This file is part of the standard setup for testthat.
# It is recommended that you do not modify it.
#
# Where should you do additional test configuration?
# Learn more about the roles of various files in:
# * https://r-pkgs.org/tests.html
# * https://testthat.r-lib.org/reference/test_package.html#special-files

library(testthat)
# Directory of all tests files related to R functions
test_dir <- here::here("tests/testthat")
# Get all tests files
all_tests <- list.files(test_dir, pattern="test-", 
                        all.files = TRUE, full.names = TRUE)
n_tests <- length(all_tests)
#test_check("multi-omics-pipeline")
exec_test <- 0
skip_test <- 0
# Checks first line of each test if containing the phrase "skip test"
# then it should be skipped
for (test in all_tests) {
  bn <- basename(test)
  keyword_line <- readLines(test, n=1) 
  skip <- grepl("skip test", keyword_line, ignore.case = TRUE)
  if (skip) {
    cat("\nSkipping", bn, "\n")
    skip_test <- skip_test + 1
    next
  }
  cat("\nExecuting", bn, "\n")
  test_file(test)
  exec_test <- exec_test + 1
}
cat("\nExecuted", exec_test, "/", n_tests, "tests.\n")
cat("\nSkipped", skip_test, "tests.\n")
# Cleans environment after executing all tests
# Some generates objecets, and some source functions, so all cleared
# after executing tests.
rm(list=ls())





