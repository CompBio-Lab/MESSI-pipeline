from sklearn.model_selection import RandomizedSearchCV
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import make_pipeline


# Run a randomized search cv to find optimal params
def run_random_search_cv(clf_instance, X, Y, param_distributions, n_iter=10, random_state=42, n_jobs=-1):
    # Apply random search cross validation to find optimal hyperparameters
    # Make sure to use a pipeline to standardize the data before fitting the model
    pipeline = make_pipeline(StandardScaler(), clf_instance)
    # When searching over a pipeline, param keys must be prefixed with the step
    # name (e.g. 'logisticregression__C'), otherwise sklearn treats them as
    # invalid Pipeline params. make_pipeline names the step by the lowercased
    # class name, so grab it from the last step.
    step_name = pipeline.steps[-1][0]
    prefixed_param_distributions = {
        f"{step_name}__{k}": v for k, v in param_distributions.items()
    }
    # Default to use all processors to speed up process
    clf_cv = RandomizedSearchCV(
        pipeline, param_distributions=prefixed_param_distributions,
        n_iter=n_iter, random_state=random_state,
        n_jobs=n_jobs
        )
    # Could then fit this cv object of the X and Y of data
    search = clf_cv.fit(X, Y)
    # Strip the step prefix so callers can re-instantiate the bare classifier
    # with the returned params (classifier_class(**optimal_params)).
    prefix = f"{step_name}__"
    optimal_params = {
        k[len(prefix):] if k.startswith(prefix) else k: v
        for k, v in search.best_params_.items()
    }
    return optimal_params
