from sklearn.model_selection import RandomizedSearchCV

# Run a randomized search cv to find optimal params
def run_random_search_cv(clf_instance, X, Y, param_distributions, n_iter=10, random_state=42, n_jobs=-1):
    # Apply random search cross validation to find optimal hyperparameters
    # Default to use all processors to speed up process
    clf_cv = RandomizedSearchCV(
        clf_instance, param_distributions=param_distributions, 
        n_iter=n_iter, random_state=random_state,
        n_jobs=n_jobs
        )
    # Could then fit this cv object of the X and Y of data
    search = clf_cv.fit(X, Y)
    optimal_params = search.best_params_
    return optimal_params
