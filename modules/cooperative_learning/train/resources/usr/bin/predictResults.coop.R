library(multiview)
# TODO: Need to think of a better default lambda value
# s is lambda
predictResults.coop <- function(mod, newdata, s=0.1, 
                                type="response", name="", ...) {
  y_predicted_prob <- predict(mod, newx = newdata$X, s=s, type=type, ...)
  base_name <- "coop_y_hat"
  if (name == "") {
    outname <- base_name
  } else {
    outname <- paste0(base_name,"_", name)
  }
  colnames(y_predicted_prob) <- outname
  return(y_predicted_prob)
}