# This script is imported for sklearn classifiers usage


import scipy.stats as stats
import importlib

print("This date should be shown as : 2026")


def load_classifier_class(model_name, random_state=42, probability=True):
    # Define models with their respective classes, default parameters, and distributions
    # Adopted from https://scikit-learn.org/stable/auto_examples/classification/plot_classifier_comparison.html
    # NOTE: keep to use SVC rather than LinearSVC class since the latter do not have predict_prob
    # https://stackoverflow.com/questions/33843981/under-what-parameters-are-svc-and-linearsvc-in-scikit-learn-equivalent

    # Common params
    C                   = stats.loguniform(1e-4, 1e4)
    min_sample_leaf     = stats.randint(1,6)
    base_n_estimators   = 10
    n_estimators        = stats.randint(50, 501)
    learning_rate       = stats.uniform(0.01, 1.1)
    max_features        = ["sqrt", "log2", 100, 500, 1000, None]
    max_depth           = 10



    # Dict to store relevant information of sklearn classifiers

    # For logistic regression, it has built-in predict proba and coef
    logit_dict = {
            "class_path": "sklearn.linear_model.LogisticRegression",
            "default_params": {"C": 1.0, "penalty": "l2", "solver": "liblinear"},
            "params_dist": {"C": C, "penalty": ["l2"], "solver": ["liblinear"]}
        }
    # Use SVC with kernel linear and not LinearSVC, since the latter do not have predict_proba
    linear_svm_dict ={
            "class_path": "sklearn.svm.SVC",
            "default_params": {"C": 1.0, "kernel": "linear", "random_state": random_state, "probability": probability},
            "params_dist": {"C": C, "kernel": ["linear"] }
    }
    # Random Forest classifier, should in general work better than single decision tree
    random_forest_dict = {
            "class_path": "sklearn.ensemble.RandomForestClassifier",
            "default_params": {
                "n_estimators": base_n_estimators, "max_features": "sqrt", 
                "max_depth": max_depth, 
                "random_state": random_state, "n_jobs": -1
            },
            "params_dist": {
                "max_features": max_features,
                "max_leaf_nodes": [10, 100, 1000, None],
                "min_samples_leaf": min_sample_leaf
            }
    }

    # MLPClassifier is a neural network classifier
    mlp_dict = {
            "class_path": "sklearn.neural_network.MLPClassifier",
            "default_params": {
                "hidden_layer_sizes": (64,), "max_iter": 500,
                "random_state": random_state
            },
            "params_dist": {
                "hidden_layer_sizes": [(32,), (64,), (128,), (64, 32)],
                "alpha": stats.loguniform(1e-5, 1e-1)
            }
    }

    # Real xgboost
    xgboost_dict = {
            "class_path": "xgboost.XGBClassifier",
            "default_params": {
                "random_state": random_state ,
                "n_estimators": base_n_estimators,
                "objective": "binary:logistic"},
            "params_dist": { 
                "learning_rate": learning_rate,
                "max_depth": stats.randint(2, 9)
            }
    }

    # ========================
    # Lastly merge all together into a single dictionary
    model_info = {
        "Logit": logit_dict,
        "Linear_SVM": linear_svm_dict,
        # RandomForest should in general work better than single decision tree
        "Random_Forest": random_forest_dict,
        # MLPClassifier is a neural network classifier
        "MLP": mlp_dict,
        # XGBoost goes here
        "XGBoost": xgboost_dict
    }

    # Check if valid name of model was input
    if model_name not in model_info:
        valid_models = list(model_info.keys())
        print(f"Valid models are: {valid_models}")
        raise ValueError(f"Model '{model_name}' not valid, check spelling")
    
    # Retrieve model info
    model = model_info[model_name]
    class_path = model["class_path"]
    default_params = model["default_params"]
    params_dist = model["params_dist"]

    # Import and return the classifier class
    module_path, class_name = class_path.rsplit(".", 1)
    classifier_class = getattr(importlib.import_module(module_path), class_name)
    print(f"class name is: {class_name}")
    return classifier_class, default_params, params_dist
