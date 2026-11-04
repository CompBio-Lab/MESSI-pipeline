# Worked example: adding a method (R and Python)

Real output from the MESSI pipeline on this server (dataset `rosmap`, 2-fold CV,
reusing existing images, non-root containers). Each block below is one example.

The developer edits **one file** with three functions; the command generates the
four Nextflow processes, wires the method into five files, and validates it.

---

## 0. The only file you edit

### R — `modules/logistic_r/resources/usr/bin/logistic_r_core.R`

```r
# logistic_r: ridge-penalised logistic regression on all views joined. Base R only.
# Why not glm()? More features than samples gives NA coefficients; a small ridge
# penalty, fitted with optim(), fixes that.

HYPERPARAMETERS <- list(penalty = "l2", lambda = 1)

# in:  X_train, named list of samples x features matrices; y_train, 0/1 labels
# out: any object (saved with saveRDS), here a list for the other two functions
fit <- function(X_train, y_train, ...) {
  X <- do.call(cbind, unname(X_train))
  # ... centre/scale, optim() an L2-penalised logistic loss ...
  list(intercept = ..., coef = ..., centers = ..., scales = ...,
       features = colnames(X), views = rep(names(X_train), vapply(X_train, ncol, 1L)))
}

# out: numeric vector of P(class = 1), one per row of X_test
predict_proba <- function(model, X_test) {
  X <- do.call(cbind, unname(X_test))
  Z <- scale(X, center = model$centers, scale = model$scales)
  as.numeric(plogis(model$intercept + Z %*% model$coef))
}

# out: data.frame with columns feature, view, coef
feature_weights <- function(model) {
  data.frame(feature = model$features, view = model$views, coef = model$coef)
}
```

### Python — `modules/logistic_py/resources/usr/bin/logistic_py_core.py`

```python
# logistic_py: ridge-penalised logistic regression on all views joined, scikit-learn.
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

HYPERPARAMETERS = {"penalty": "l2", "C": 1.0}

# in:  X_train, dict of samples x features DataFrames; y_train, 0/1 array
# out: any picklable object, here a dict for the other two functions
def fit(X_train, y_train, **kwargs):
    X = pd.concat(X_train.values(), axis=1)
    pipeline = make_pipeline(
        StandardScaler(),
        LogisticRegression(penalty=HYPERPARAMETERS["penalty"], C=HYPERPARAMETERS["C"], max_iter=1000),
    )
    pipeline.fit(X.values, y_train)
    return {"pipeline": pipeline, "features": list(X.columns),
            "views": [v for v, f in X_train.items() for _ in f.columns]}

# out: 1-D array of P(class = 1), one per row of X_test
def predict_proba(model, X_test):
    X = pd.concat(X_test.values(), axis=1)
    return model["pipeline"].predict_proba(X.values)[:, 1]

# out: DataFrame with columns feature, view, coef
def feature_weights(model):
    coef = model["pipeline"].named_steps["logisticregression"].coef_[0]
    return pd.DataFrame({"feature": model["features"], "view": model["views"], "coef": coef})
```

---

## 1. Generate — one question at a time

The command validates each answer; a bad name is rejected and re-asked. Python is
identical with the answers `logistic_py`, `Python`, `eipy`.

```text
$ python bin/adding_method/add_method.py --example logistic

Step 1 of 3: method name
  Lowercase letters, digits and underscores.
Method name [logistic_r]: logistic-r
  Not usable: Use lowercase letters, digits and single underscores,
  starting with a letter (for example: my_method).
Method name [logistic_r]: logistic_r

Step 2 of 3: language
Language (R or Python) [R]: R

Step 3 of 3: container
  1) reuse tonyliang19/rgcca:latest
  2) reuse tonyliang19/caret_multimodal:latest
  3) reuse tonyliang19/mofa:latest
  4) new: generate a Dockerfile FROM tonyliang19/r_method_base_dev
Choice (number, or a full image name) [1]: rgcca
```

---

## 2. Preview — every inserted line, before writing

The command prints the exact change, not just the filenames (`--dry-run` stops here).

```text
Files to create:
  modules/logistic_r/main.nf
  modules/logistic_r/resources/usr/bin/logistic_r_core.R
  modules/logistic_r/resources/usr/bin/messi_contract.R
  modules/logistic_r/resources/usr/bin/messi_run.R
  subworkflows/methods/logistic_r/main.nf

Files to modify (23 lines inserted, each above its '// add_method:<slot>' marker):
  nextflow.config  (+2)
      + skip_logistic_r = false
      + withLabel: logistic_r { container = 'tonyliang19/rgcca:latest' }
  subworkflows/cross_validation/main.nf  (+1)
      + 'logistic_r',
  subworkflows/cross_validation/r/main.nf  (+9)
      + include { LOGISTIC_R } from "${subworkflowDir}/methods/logistic_r"
      + skip_logistic_r = params.skip_logistic_r || outcome_type != 'classification'
      + // LOGISTIC_R
      + logistic_r_results = Channel.empty()
      + if (!skip_logistic_r) {
      +   LOGISTIC_R ( mae_copy )
      +   logistic_r_results = LOGISTIC_R.out.csv_results
      + }
      + .mix( logistic_r_results )
  subworkflows/feature_selection/main.nf  (+11)
      + include { LOGISTIC_R_SELECT_FEATURE } from "${modulesDir}/logistic_r"
      + skip_logistic_r = params.skip_logistic_r || params.outcome_type != 'classification'
      + logistic_r_features = Channel.empty()
      + logistic_r_hyperparams = Channel.empty()
      + if (!skip_logistic_r) {
      +   LOGISTIC_R_SELECT_FEATURE ( mae_data )
      +   logistic_r_features = LOGISTIC_R_SELECT_FEATURE.out.features
      +   logistic_r_hyperparams = LOGISTIC_R_SELECT_FEATURE.out.hyperparameters
      + }
      + .mix( logistic_r_features )
      + .mix( logistic_r_hyperparams )
```

---

## 3. Check — your functions inside the container, non-root

### R

```text
$ python bin/adding_method/add_method.py check-image logistic_r
Checking image tonyliang19/rgcca:latest, run as -u 1043:1043 --entrypoint ''
  PASS 1. image starts          non-root user, no entrypoint
  PASS 2. runtime Rscript       R version 4.4.0
  PASS 2. package MultiAssayExperiment loads
  PASS 2. package HDF5Array     loads
     PASS fit              list, saved and reloaded with saveRDS
     PASS predict_proba    12 scores 0.008–0.988, AUC 1.00
     PASS feature_weights  20 rows in views: view_a, view_b
     PASS output files     result, feature and hyperparameter files written
  PASS 5. architecture          amd64
Result: PASS
```

### Python

```text
$ python bin/adding_method/add_method.py check-image logistic_py
Checking image tonyliang19/eipy:latest, run as -u 1043:1043 --entrypoint ''
  PASS 1. image starts          non-root user, no entrypoint
  PASS 2. runtime python        Python 3.11.6
  PASS 2. package numpy         loads
  PASS 2. package pandas        loads
  PASS 2. package mudata        loads
     PASS fit              dict of length 3, saved and reloaded with pickle
     PASS predict_proba    12 scores 0.006–0.971, AUC 1.00
     PASS feature_weights  20 rows in views: view_a, view_b
     PASS output files     result, feature and hyperparameter files written
  PASS 5. architecture          amd64
Result: PASS
```

---

## 4. Test — the real pipeline on rosmap

### R

```text
$ python bin/adding_method/add_method.py test logistic_r
Running methods in R only
[5e/50f0fc] FEATURE_SELECTION:LOGISTIC_R_SELECT_FEATURE (rosmap)
[de/affe24] CV_R:LOGISTIC_R:LOGISTIC_R_PREPROCESS (rosmap)
[ee/8158e1] CV_R:LOGISTIC_R:LOGISTIC_R_TRAIN (rosmap-fold_1)
[07/e7c453] CV_R:LOGISTIC_R:LOGISTIC_R_PREDICT (rosmap-fold_1)
[55/618847] CALCULATE_METRICS (1)
Successfully completed   (Duration: 48.6s)

Published files:
  PASS logistic_r-result.csv: 351 rows
  PASS all_feature_selection_results.csv: 600 rows
  PASS selected_hyperparameters.csv: 3 rows
  PASS metrics.csv: 1 row  ->  roc_auc 0.83
Result: PASS
```

### Python

```text
$ python bin/adding_method/add_method.py test logistic_py
Running methods in Python only
[.. ] FEATURE_SELECTION:LOGISTIC_PY_SELECT_FEATURE (rosmap)
[.. ] CV_PYTHON:LOGISTIC_PY:LOGISTIC_PY_PREPROCESS (rosmap)
[.. ] CV_PYTHON:LOGISTIC_PY:LOGISTIC_PY_TRAIN (rosmap-fold_1)
[.. ] CV_PYTHON:LOGISTIC_PY:LOGISTIC_PY_PREDICT (rosmap-fold_1)
[.. ] CALCULATE_METRICS (1)
Successfully completed   (Duration: 31.9s)

Published files:
  PASS logistic_py-result.csv: 351 rows
  PASS all_feature_selection_results.csv: 600 rows
  PASS selected_hyperparameters.csv: 3 rows
  PASS metrics.csv: 1 row  ->  roc_auc 0.83
Result: PASS
```

### Both at once — `test logistic_r --also logistic_py`

```text
Running all CVs with both R and Python
  PASS logistic_r-result.csv: 351 rows
  PASS logistic_py-result.csv: 351 rows
  PASS all_feature_selection_results.csv: 1200 rows
  PASS selected_hyperparameters.csv: 6 rows
  PASS metrics.csv: 2 rows   (logistic_r 0.83, logistic_py 0.83)
Result: PASS
```
