source(here::here("modules/R/simulate_data/helpers/getNumPredictors.R"))
test_that("Get right output", {
  p <- 7
  ft_str <- 4
  sigma <- 9
  eval_getNP <- getNumPredictors(p, ft_str, sigma)
  expected_getNP <- list(px=12 , pz=8, pw=9)
  expect_equal(eval_getNP, expected_getNP)
})
