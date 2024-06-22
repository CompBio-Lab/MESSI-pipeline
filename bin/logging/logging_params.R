# Function to log the parameters used inside the function
logging_params <- function(args_used) {
  formatted_args <- paste(names(args_used), "=", args_used, collapse = ", ")
  formatted_output <- paste("{", formatted_args, "}", sep = "")
  cat("\n")
  cat("Using the following parameters: \n")
  cat(formatted_output)
  cat("\n")
}
