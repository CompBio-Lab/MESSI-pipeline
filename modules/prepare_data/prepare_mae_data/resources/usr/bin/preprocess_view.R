# Use this script to preprocess the following steps (Ordered):
# 1. Remove near zero variance features
# 2. Replace NAs with 0
# 3. Add the view name in front of features if any two views after overlapping feature names
# 4. Center and scale the matrix
# TODO: NOT scaling now, since it might introduce negative numbers and cause problem

# Load library
library(magrittr)
library(dplyr)

calculate_threshold <- function(variances, threshold_type = "mean", percentile = 0.10) {
  # Check for valid threshold_type
  if (!(threshold_type %in% c("mean", "median", "percentile"))) {
    stop("Invalid threshold_type. Choose from 'mean', 'median', or 'percentile'.")
  }

  # Calculate threshold based on type
  if (threshold_type == "mean") {
    threshold <- mean(variances)
  } else if (threshold_type == "median") {
    threshold <- median(variances)
  } else if (threshold_type == "percentile") {
    if (percentile < 0 || percentile > 1) {
      stop("Percentile must be between 0 and 1.")
    }
    threshold <- quantile(variances, probs = percentile)
  }

  return(threshold)
}

# Safe filter to drop columns by threshold, only filter if kept at least 2 columns
# Otherwise, methods could complain as it requires >= features
safe_filter <- function(X, keep, step, min_cols = 2) {

  kept <- sum(keep)

  total <- length(keep)

  if (kept < min_cols) {

    message(sprintf(

      "[SKIP] %s: %d/%d features",

      step, kept, total

    ))

    return(X)

  }



  message(sprintf(

    "[OK]   %s: %d/%d features",

    step, kept, total

  ))
  X[, keep, drop = FALSE]
}




# Takes input of an X list, such composed of I matrix of p_i x n
preprocess_view <- function(X, replace_na_val=0, scale=FALSE, filter_low_var=TRUE) {
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
    # p_i means number of variable
    # n means number of subject
    # Long means p_i x n , so row is p_i
    long_X_i <- new_X[[view]]
    # Wide means n x p_i, so row is n
    wide_X_i <- t(long_X_i)
    # 1. Remove features (now column) that contains NAs
    wide_X_i <- wide_X_i %>%
                as.data.frame() %>%
                dplyr::select(where(~ !any(is.na(.)))) %>%
                as.matrix()
    
    if (filter_low_var) {
      # 2. Remove features with lower variance than the mean
      # Calculate variance for each column
      variances <- apply(wide_X_i, MARGIN=2, FUN=var, na.rm=TRUE)
      # Remove features with less than mean of the variances
      threshold <- calculate_threshold(variances, threshold_type="mean")
      relv_feats <- variances >= threshold
      # Apply the safe filter here
      #wide_X_i <- wide_X_i[, relv_feats, drop=FALSE]
      wide_X_i <- safe_filter(wide_X_i, relv_feats, step = "Variance filter")

      # Then, check those features that have at least 50% of its values not being zero
      # And, remove those that have 70% of zero
      zero_var_feats <- rownames(mixOmics::nearZeroVar(wide_X_i, freqCut = 70/5, uniqueCut = 50)$Metrics)
      wide_X_i <- wide_X_i[, !colnames(wide_X_i) %in% zero_var_feats, drop=FALSE]
      stopifnot(is.matrix(wide_X_i))
    }


    #long_X_i  <- long_X_i[!rownames(long_X_i) %in% irrev_feats, ]
    #long_X_i <- long_X_i %>%
    #            as.data.frame()  %>%
                # TODO: Remove those NAs instead maybe? but need to consider only if NA constitute more than X percentage
                # of each row
    #            replace(is.na(.), values=replace_na_val)
    # 3. Add the view name in front of features if any two views after overlapping feature names
    feat_names <- colnames(wide_X_i)
    if (overlapped_feats) {
      colnames(wide_X_i) <- paste0(view, "_", feat_names)
    }
    # And return it back as long format of
    return(t(wide_X_i))
  })
  # Lastly assing its name back
  names(new_X) <- view_names
  return(new_X)
}
