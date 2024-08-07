import importlib

# Custom function to load different classifiers
def load_classifier_class(model_name, random_state=42, probability=True):
    # Adopted from https://scikit-learn.org/stable/auto_examples/classification/plot_classifier_comparison.html
    # Storing path of each classifier's class
    model_classes = {
    "Nearest Neighbors": "sklearn.neighbors.KNeighborsClassifier",
    "Linear SVM": "sklearn.svm.SVC",
    "RBF SVM": "sklearn.svm.SVC",
    "Gaussian Process": "sklearn.gaussian_process.GaussianProcessClassifier",
    "Decision Tree": "sklearn.tree.DecisionTreeClassifier",
    "Random Forest": "sklearn.ensemble.RandomForestClassifier",
    "Neural Net": "sklearn.neural_network.MLPClassifier",
    "AdaBoost": "sklearn.ensemble.AdaBoostClassifier",
    "Naive Bayes": "sklearn.naive_bayes.GaussianNB",
    "QDA": "sklearn.discriminant_analysis.QuadraticDiscriminantAnalysis",
    }
    # Storing default params of the classifier
    default_params = {
        "Nearest Neighbors": {"n_neighbors": 3},
        "Linear SVM": {"C": 0.025, "kernel": "linear", "random_state": random_state, "probability": probability},
        "RBF SVM": {"C": 1.0, "kernel": "rbf", "gamma": 2.0, "random_state": random_state, "probability": probability},
        "Gaussian Process": {"random_state": random_state},
        "Decision Tree": {"max_depth": 10, "random_state": random_state},
        "Random Forest": {"n_estimators": 100, "max_features": "sqrt", "max_depth": 10, "random_state": random_state},
        "Neural Net": {"alpha": 1.0, "max_iter": 1000, "random_state": random_state},
        "AdaBoost": {"algorithm": "SAMME", "random_state": random_state},
        # Empty params for naive bayes and qda for now, use their default
        "Naive Bayes": {},
        "QDA": {},
    }
    
    # Check if valid name of model was input
    model_names  = set(model_classes.keys())
    if model_name not in model_names:
        print(f"Valid models are: {model_names}")
        raise ValueError(f"Model '{model_name}' not valid, check spelling")
    
    module_path, class_name = model_classes[model_name].rsplit(".", 1)
    classifier_class = getattr(importlib.import_module(module_path), class_name)
    return classifier_class, default_params[model_name]