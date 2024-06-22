check_dataset_name <- function(dataset_name, X_list) {
  if (dataset_name == "empty") {
    stop("todo")
  } else {
    X_obj_name <- deparse(substitute(X_list))
    dataset_name <- paste0("dataset-", X_obj_name)
  }
}

# Stale code
# X_obj_name <- deparse(substitute(X_list)) 
# dataset_name <- paste0("dataset-", X_obj_name)