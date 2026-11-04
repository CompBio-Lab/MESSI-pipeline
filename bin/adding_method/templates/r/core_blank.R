# {{ method }}: THE ONE FILE YOU EDIT.
#
# Fill in the three functions below. The MESSI wrappers do everything else: they
# load the data and the fold split, call these functions, save the model and write
# the result, feature and hyperparameter files. You write no file I/O here.
#
# Test without Nextflow:  python bin/adding_method/add_method.py check {{ method }}
# Packages: use library() at the top of this file. They must exist in the method's
# container: python bin/adding_method/add_method.py check-image {{ method }}

# Optional: settings to record in selected_hyperparameters.json, for example
# HYPERPARAMETERS <- list(lambda = 1). A plain value is recorded as "fixed". To say
# otherwise use list(lambda = list(value = 1, treatment = "tuned")), where treatment
# is one of tuned, fixed, default, data-derived.
HYPERPARAMETERS <- list()


# fit: train the model.
#
# Input
#   X_train  Named list with one numeric matrix per omics view.
#            Rows are samples, columns are features, for example
#            list(mrna = <80 x 200 matrix>, mirna = <80 x 120 matrix>).
#            Row names are sample names, in the same order in every view.
#            Column names are feature names.
#   y_train  Integer vector of 0/1 with one label per row, named by sample.
#            1 is the positive class.
#   ...      Includes seed, an integer. set.seed(seed) has already been called.
# Output
#   Any R object. It is saved with saveRDS and passed to the other two functions.
#
# Minimal example:
#   X <- do.call(cbind, unname(X_train))
#   list(
#     weights = colMeans(X[y_train == 1, , drop = FALSE]) - colMeans(X[y_train == 0, , drop = FALSE]),
#     views = rep(names(X_train), vapply(X_train, ncol, 1L))
#   )
fit <- function(X_train, y_train, ...) {
  stop("fit() is not implemented yet. Fill it in: {{ core_path }}", call. = FALSE)
}


# predict_proba: score new samples.
#
# Input
#   model   The object fit() returned.
#   X_test  Named list of matrices like X_train: same views and features, other samples.
# Output
#   Numeric vector of probabilities of class 1, in [0, 1], with no NA.
#   One value per row of X_test[[1]], in the same order.
#   Return one column only: not a two-column matrix of both classes.
#
# Minimal example:
#   X <- do.call(cbind, unname(X_test))
#   as.numeric(plogis(X %*% model$weights))
predict_proba <- function(model, X_test) {
  stop("predict_proba() is not implemented yet. Fill it in: {{ core_path }}", call. = FALSE)
}


# feature_weights: how much each feature counts.
#
# Input
#   model  The object fit() returned, fitted on all samples of the dataset.
# Output
#   data.frame with one row per feature and exactly these columns:
#     feature  character, the name exactly as in colnames(X_train[[view]])
#     view     character, one of names(X_train)
#     coef     numeric and finite, the signed weight
#
# Minimal example:
#   data.frame(feature = names(model$weights), view = model$views, coef = unname(model$weights))
feature_weights <- function(model) {
  stop("feature_weights() is not implemented yet. Fill it in: {{ core_path }}", call. = FALSE)
}
