import scipy.stats as stats
import importlib


def load_classifier_class(model_name, random_state=42, probability=True):
    # Define models with their respective classes, default parameters, and distributions
    # Adopted from https://scikit-learn.org/stable/auto_examples/classification/plot_classifier_comparison.html
    # NOTE: keep to use SVC rather than LinearSVC class since the latter do not have predict_prob
    # https://stackoverflow.com/questions/33843981/under-what-parameters-are-svc-and-linearsvc-in-scikit-learn-equivalent

    # Common params
    C               = stats.loguniform(1e-4, 1e4)
    min_sample_leaf = stats.randint(1,6)
    n_estimators    = stats.randint(50, 501)
    learning_rate   = stats.uniform(0.01, 1.1)
    max_features    = ["sqrt", "log2", 100, 500, 1000, None]
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
    # Decision Tree classifier, risk of overfitting, hence require pruning of trees
    decision_tree_dict = {
            "class_path": "sklearn.tree.DecisionTreeClassifier",
            "default_params": {"max_depth": 10, "random_state": random_state},
            "params_dist": {
                "criterion": ['gini', 'entropy', 'log_loss'],
                "max_depth": stats.randint(5, 41),
                "min_samples_leaf": min_sample_leaf,
                "max_leaf_nodes": [10, 100, 1000, None]
            }
    }
    # Random Forest classifier, should in general work better than single decision tree
    random_forest_dict = {
            "class_path": "sklearn.ensemble.RandomForestClassifier",
            "default_params": {"n_estimators": 10, "max_features": "sqrt", "max_depth": 10, "random_state": random_state, "n_jobs": -1},
            "params_dist": {
                "max_features": max_features,
                "max_leaf_nodes": [10, 100, 1000, None],
                "min_samples_leaf": min_sample_leaf
            }
    }

    # Gradient Boost classifier, should tune large number of estimators with slow learning rate
    gradient_boost_dict = {
            "class_path": "sklearn.ensemble.GradientBoostingClassifier",
            "default_params": {"loss":'log_loss', "learning_rate":0.1, "n_estimators":10},
            "params_dist": { 
                "n_estimators": n_estimators,
                "learning_rate": learning_rate,
                "min_samples_leaf": min_sample_leaf,
                "max_features": max_features
            }
    }
    # MLPClassifier is a neural network classifier
    mlp_dict = {
    "class_path": "sklearn.neural_network.MLPClassifier",
    "default_params": {"hidden_layer_sizes": (64,), "max_iter": 500,
                       "random_state": random_state},
    "params_dist": {"hidden_layer_sizes": [(32,), (64,), (128,), (64, 32)],
                    "alpha": stats.loguniform(1e-5, 1e-1)}
    }
    # Mimic xgboost
    hist_gradient_boost_dict = {
        "class_path": "sklearn.ensemble.HistGradientBoostingClassifier",
        "default_params": {"random_state": random_state},
        "params_dist": {"learning_rate": learning_rate,
                    "max_leaf_nodes": [15, 31, 63],
                    "min_samples_leaf": stats.randint(5, 30)}
    }

    # ========================
    # Lastly merge all together into a single dictionary
    model_info = {
        "Logit": logit_dict,
        "Linear_SVM": linear_svm_dict,
        # Decision Tree have risk of overfitting, hence require pruning of trees
        "Decision_Tree": decision_tree_dict ,
        # RandomForest shuold in general work better than single decision tree
        "Random_Forest": random_forest_dict,
        # GradientBoost should tune large number of estimators with slow learning rate
        "Gradient_Boost": gradient_boost_dict,
        # MLPClassifier is a neural network classifier
        "MLP": mlp_dict,
        "Hist_Gradient_Boost": hist_gradient_boost_dict
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
