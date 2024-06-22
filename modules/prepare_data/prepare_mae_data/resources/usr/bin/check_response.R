# Use this fun to check the response type and coerce it to
# binary levels, have several reqs
# TODO: add description here
check_response <- function(y) {
 if (is.null(y)) stop("Did not find response in MAE")
 # It should only have two label or classes
 num_labs <- length(unique(y))
 y_low <- tolower(y)
 if (num_labs != 2) stop("Y should only have two classes/labels")
 chr_labs <- c("no", "yes")
 bin_labs <- c(0, 1)
 is_num <- all(bin_labs %in% y_low)
 is_chr <- all(chr_labs %in% y_low)
 # Then check if it should be one of this two
 if (!is_num)  {
   if (!is_chr) stop("Y did not contain the right labels, requires to be 1-0 or yes-no")
   return(factor(y_low, levels=chr_labs))
 }
 y <- factor(ifelse(y == 1, "yes", "no"), levels=chr_labs)
 return(y)
}

# Uncomment below if want to debug the fun
# testthat::test_that("Should pass", {
#   ans <- factor(c("yes", "no", "yes", "no"))
#   yb <- c(1,0,1,0)
#   yc <- c("yes", "no", "yes", "no")
#   yfc <- factor(c("YES", "NO", "YES", "NO"))
#   yfb <- factor(c(1,0,1, 0))
#   y_bad <- c("hey", "bye", "hey", "bye")
#   y_bad2 <- factor(c("hey", "bye", "hey", "bye"))
#   # The actual tests goes here
#   expect_equal(check_response(yfc), ans)
#   expect_equal(check_response(yb), ans)
#   expect_equal(check_response(yfb), ans)
#   expect_equal(check_response(yc), ans)
#   expect_error(check_response(y_bad))
#   expect_error(check_response(y_bad2))
# })
