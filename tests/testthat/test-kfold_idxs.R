# Test file to test kfold idxs

# Generate kfold stuffs

source(here::here("modules/R/kfold_idxs.R"))
n <- 25
idxs <- seq_len(n)
k <- 5
#seed <- format(Sys.Date(), "%d") # I just randomly picked to this to add 
# more variability


# Test if the function returns a list
test_that("Output is a list", {
  test_split_idxs <- kfold_idxs(idxs)
  expect_is(test_split_idxs, "list")
})

# Test if the function returns the correct number of splits
test_that("Correct number of splits", {
  k <- 10 # Use longer specifically
  test_split_idxs <- kfold_idxs(idxs, k)
  expect_equal(length(test_split_idxs), k)
})

# Test if the returned splits have the correct length
test_that("Splits have correct length", {
  test_split_idxs <- kfold_idxs(idxs, k)
  for (fold in 1:k) {
    split_name <- paste0("fold_", fold)
    split_length <- length(test_split_idxs[[split_name]])
    expected_length <- length(idxs) / k
    expect_equal(split_length, expected_length)
  }
})

# Test if the indices in the splits are within the range of input indices
test_that("Indices are within range", {
  test_split_idxs <- kfold_idxs(idxs, k)
  for (fold in 1:k) {
    split_name <- paste0("fold_", fold)
    split_indices <- test_split_idxs[[split_name]]
    expect_true(all(split_indices %in% idxs))
  }
})

# Test if the sum of lengths of all splits equals the length of input indices
test_that("Sum of split lengths equals input length", {
  test_split_idxs <- kfold_idxs(idxs, k)
  total_length <- sum(sapply(test_split_idxs, length))
  expect_equal(total_length, length(idxs))
})

# Test if the function returns unique indices in each split
test_that("Unique indices in each split", {
  k <- 2
  test_split_idxs <- kfold_idxs(idxs, k)
  for (fold1 in 1:k) {
    for (fold2 in 1:k) {
      if (fold1 != fold2) {
        split_name1 <- paste0("fold_", fold1)
        split_name2 <- paste0("fold_", fold2)
        indices1 <- test_split_idxs[[split_name1]]
        indices2 <- test_split_idxs[[split_name2]]
        expect_is(indices1, "integer")
        expect_is(indices2, "integer")
        expect_false(any(indices1 %in% indices2))
      }
    }
  }
})
