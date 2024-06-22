# Script to run cooperative learning
library(multiview)
source(here::here("modules/R/generic_helpers.R")) # Generic helpers
load_helpers(helper_path = "modules/R/classification/cooperative_learning/helpers/") # 
# Parameters -----------------------------------------------------------------
# Note container binded the /arc/project/.../multi-omics-pipeline/data to 
# /arc_data instead, so data could be made available there using absolute path
train_path <- "/arc_data/splitTrainTest/data/sample3/sample3-train_data.rds"
test_path <- "/arc_data/splitTrainTest/data/sample3/sample3-test_data.rds"
prefix <- ""
ext <- "rds"
type.measure <- c("deviance", "class")
s <- c("lambda.min", "lambda.1se")
type <- "response"
rho <- 0.5
verbose <- TRUE
# Main fun -------------------------------------------------------------------
main <- function(train_path, test_path, prefix, ext=".rds",
                 type.measure = c("deviance", "class"), rho=0.5, 
                 folds=10, verbose=FALSE, s = c("lambda.min", "lambda.1se"), 
                 type="response") {
  # Log the params used ------------------------------------------------------
  logging_sep_line()
  cat("\nStarting a new Cooperative Learning process\n")
  # Params -------------------------------------------------------------------
  type.measure <- match.arg(type.measure, choices = type.measure)
  s <- match.arg(s, choices=s)
  args_used <- c(as.list(environment()))
  logging_params(args_used)
  
  # Read data ----------------------------------------------------------------
  # Data contains X block, Y, and also newdat,a (list(X, Y))
  data <- getData(train_path, test_path=test_path, 
                  prefix=prefix, ext = ext, 
                  binary=TRUE) # binary response of 1 and 0 s
  X <- data$X
  Y <- data$Y
  newdata <- data$newdata
  # Training -----------------------------------------------------------------
  # Base model goes here
  multiview.control(mxitnr = 100) # This bit is needed to ensure convergence
  # binomial is required
  base_model <- multiview(x_list = X, y = Y, family = binomial())
  
  multiview.control(factory = TRUE) # reset to default settings
  # Tune model hyperparameters -----------------------------------------------
  # output is cv.multiview / cv.glmnet
  tuned_model <- tune_coop(data = data, type.measure = type.measure, 
                            rho = rho, verbose=verbose)
  # Prediction ---------------------------------------------------------------
  # Should have predicted proba with base model as well
  # s here uses default 0.5 (lambda)
  y_predicted_proba_base <- predictResults.coop(mod=base_model, 
                                                newdata=newdata,
                                                type=type, name="base") 
  y_predicted_proba_opt <- predictResults.coop(mod=tuned_model, 
                                               newdata=newdata,
                                               s=s, type=type, name="opt")
  savePred(y_predicted_proba_base)
  savePred(y_predicted_proba_opt)
  cat("\nFinished one Cooperative Learning process\n")
  logging_sep_line()
}

main(train_path=train_path, test_path = test_path, 
     prefix = prefix, verbose=TRUE)


#------------------------------------------
# Y <- newdata$Y |> as.factor()
# Y_pred <- ifelse(y_predicted_proba > 0.5, 1, 0)[,1] |> as.factor()
# caret::confusionMatrix(Y_pred, Y)













