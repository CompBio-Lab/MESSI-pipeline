# Use this script to preprocess the following steps (Ordered):
# 1. Remove near zero variance features
# 2. Replace NAs with 0
# 3. Add the view name in front of features if any two views after overlapping feature names
# 4. Center and scale the matrix
# TODO: NOT scaling now, since it might introduce negative numbers and cause problem

# Load library
library(magrittr)

# Takes input of an X list, such composed of I matrix of p_i x n
preprocess_view <- function(X, replace_na_val=0, scale=FALSE) {
  view_names <- names(X)
  # Take a new copy of X to start fresh
  new_X <- X

  # Check if theres any repeated features in view j vs view i
  nms <- combn(view_names, m=2 , FUN = paste0 , collapse = "" , simplify = FALSE )
  # Make the combinations of list elements
  ll <- combn(X , m=2 , simplify = FALSE )
  # Get length of intersection of feature names of view j and view i i != j
  out <- sapply( ll , function(x) length( intersect( x[[1]] |> colnames() , x[[2]] |> colnames() ) ) )
  overlapped_feats <- any(out != 0)
  new_X <- lapply(view_names, function(view){
    # Long means p_i x n
    long_X_i <- new_X[[view]]
    # Wide means n x p_i
    wide_X_i <- t(long_X_i)
    zero_var_metrics <- nearZeroVar(x = wide_X_i)
    irrev_feats <- zero_var_metrics$Metrics |> rownames()
    # Then reduce those out and transpose it back to p_i x n
    # 1. Remove those of near zero variance
    long_X_i  <- long_X_i[!rownames(long_X_i) %in% irrev_feats, ]
    # 2. Replace NAs with 0
    long_X_i <- long_X_i %>%
                as.data.frame()  %>%
                # TODO: Remove those NAs instead maybe? but need to consider only if NA constitute more than X percentage
                # of each row
                replace(is.na(.), values=replace_na_val)
    # 3. Add the view name in front of features if any two views after overlapping feature names
    if (overlapped_feats) {
      rownames(long_X_i) <- paste0(view, "_", rownames(long_X_i))
    }
    if (scale) {
      # 4. Center and scale these matrix
      long_X_i <- long_X_i %>%
                scale(center=center, scale=scale)
      # TODO: Scale first or remove low variance first?
    }
    return(long_X_i |> as.matrix())
  })
  # Lastly assing its name back
  names(new_X) <- view_names
  return(new_X)
}