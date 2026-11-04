# {{ method }}: worked example, ridge-penalised logistic regression on all views
# joined together. Base R only.
#
# Why not plain glm()? Multi-omics data usually have more features than samples,
# where glm() gives NA coefficients. A small ridge penalty fixed that, fitted here
# with optim().
#
# Test without Nextflow:  python bin/adding_method/add_method.py check {{ method }}

# Recorded in selected_hyperparameters.json as "fixed".
HYPERPARAMETERS <- list(penalty = "l2", lambda = 1)


# Input: X_train, named list of samples x features matrices; y_train, 0/1 labels.
# Output: any object, here a list with what predict_proba and feature_weights need.
fit <- function(X_train, y_train, ...) {
  X <- do.call(cbind, unname(X_train))
  centers <- colMeans(X)
  scales <- apply(X, 2, sd)
  scales[scales == 0] <- 1
  Z <- cbind(1, scale(X, center = centers, scale = scales))
  lambda <- HYPERPARAMETERS$lambda
  penalised <- c(0, rep(1, ncol(X)))

  loss <- function(beta) {
    eta <- as.vector(Z %*% beta)
    sum(log1p(exp(eta)) - y_train * eta) + 0.5 * lambda * sum(penalised * beta^2)
  }
  gradient <- function(beta) {
    eta <- as.vector(Z %*% beta)
    as.vector(crossprod(Z, plogis(eta) - y_train)) + lambda * penalised * beta
  }
  solution <- optim(rep(0, ncol(Z)), loss, gradient, method = "L-BFGS-B", control = list(maxit = 500))

  list(
    intercept = solution$par[1],
    coef = solution$par[-1],
    centers = centers,
    scales = scales,
    features = colnames(X),
    views = rep(names(X_train), vapply(X_train, ncol, 1L))
  )
}


# Input: the object from fit; X_test, named list of matrices.
# Output: numeric vector of P(class = 1), one per row of X_test[[1]].
predict_proba <- function(model, X_test) {
  X <- do.call(cbind, unname(X_test))
  Z <- scale(X, center = model$centers, scale = model$scales)
  as.numeric(plogis(model$intercept + Z %*% model$coef))
}


# Input: the object from fit.
# Output: data.frame with columns feature, view, coef.
feature_weights <- function(model) {
  data.frame(feature = model$features, view = model$views, coef = model$coef)
}
