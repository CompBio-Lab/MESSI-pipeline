from sklearn.model_selection import RandomizedSearchCV
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import make_pipeline


# Run a randomized search cv to find optimal params
def run_random_search_cv(clf_instance, X, Y, param_distributions, n_iter=10, random_state=42, n_jobs=-1):
    # Apply random search cross validation to find optimal hyperparameters
    # Make sure to use a pipeline to standardize the data before fitting the model
    pipeline = make_pipeline(StandardScaler(), clf_instance)
    # Default to use all processors to speed up process
    clf_cv = RandomizedSearchCV(
        pipeline, param_distributions=param_distributions,
        n_iter=n_iter, random_state=random_state,
        n_jobs=n_jobs
        )
    # Could then fit this cv object of the X and Y of data
    search = clf_cv.fit(X, Y)
    optimal_params = search.best_params_
    return optimal_params
