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
