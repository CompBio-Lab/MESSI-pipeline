library(magrittr)
# Helper to convert z to y
convert_z2y <- function(z, tr, task, response_name) {
  # This makes it binary factor of 1 and 0s  
  y_bin_num <- z %>%
    transformation(tr=tr) %>%
    rbinom(length(z), 1, .) %>% # Bernoulli random var
    as.factor()
  # Determine by task and return suitable response y
  if (tolower(task) == "binary") return(y_bin_numeric)
  if (tolower(task) == "categorical") {
    y <- y_bin_num %>%
      tibble::as_tibble_col(column_name = response_name) %>%
      dplyr::mutate({{ response_name }} := case_when( 
        !!sym(response_name) == 1 ~ "yes",
        !!sym(response_name) == 0 ~ "no")
      ) %>%
      dplyr::mutate(!!response_name := factor(!!sym(response_name)))
    return(y)
  }
}

# Generate dummy metadata, note response should be contained here
# and sample_names to be common rownames
gen_simul_metadata <- function(blocks, z, tr, task, id_name="sample_names",
                               response_name="response") {
  # Convert this z to y response depending on task liked
  # one of binary (num) or categorical (chr)
  # TODO: need to put this elsewhere and clearer to denote what 
  # to transformation applied to Z to y
  y <- convert_z2y(z, tr, task, response_name) 
  # Create dummy metadata
  age <- sample(18:80, size = length(z), replace = TRUE)
  sample_names <- intersect |>
                  Reduce(lapply(blocks, rownames))

  # Combine these together in a df
  metadata <- data.frame(sample_names, y, age)
  names(metadata) <- c(id_name, response_name, "age")
  return(metadata)
}
