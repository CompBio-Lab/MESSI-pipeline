library(here)
# Fun to load all helpers for the methods, given the base path of 
resource_helper_path <- function(path) {
  # Returns a the "root" path that starts somewhere, to load everything under 'path' arg
  p <- here(path, "resources", "usr", "bin")
  return(p)
}


load_utils <- function(helper_path) {
  all_helpers <- list.files(helper_path, recursive = FALSE, full.names = TRUE)
  # Load each file
  for (h in all_helpers) {
    source(h)
  }
}

opt2num <- function(opt_chr) {
  # Converts character opts to numeric ones
  #opt <- lapply(opt_chr, function(x) as.numeric(as.character(x))) # This gives NA
  opt <- lapply(opt_chr, function(x) ifelse(grepl("^\\d+\\.?\\d*$", x), 
                                          as.numeric(x), x))
  return(opt)
}


make_parameter_record <- function(value, treatment) {
  allowed_treatments <- c(
    "tuned",
    "fixed",
    "default",
    "data-derived"
  )

  if (!treatment %in% allowed_treatments) {
    stop(
      "Unknown parameter treatment: ",
      treatment
    )
  }

  list(
    value = value,
    treatment = treatment
  )
}


write_selected_hyperparameters <- function(
    dataset_name,
    method_name,
    parameters,
    selection = NULL,
    output_path = NULL
) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("The jsonlite package is required")
  }

  if (is.null(output_path)) {
    safe_method_name <- method_name |>
      tolower() |>
      gsub("[^a-z0-9_-]+", "_", x = _)

    output_path <- paste0(
      safe_method_name,
      "-",
      dataset_name,
      "_selected_hyperparameters.json"
    )
  }

  result <- list(
    dataset = dataset_name,
    method = method_name,
    analysis_stage = "model_selection",
    selection = selection,
    parameters = parameters
  )

  jsonlite::write_json(
    result,
    path = output_path,
    pretty = TRUE,
    auto_unbox = TRUE,
    null = "null",
    na = "null",
    digits = NA
  )

  invisible(output_path)
}