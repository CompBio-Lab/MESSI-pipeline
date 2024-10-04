#!/usr/bin/env python

"""
This is a script for sklearn to perform feature selection on full portion of 
data (from MuData).

Usage:
  sklearn_select_feature.py [options]

Options:
  -h --help                   Show this message
  --data_path=DATA_PATH       Path that contains full portion of MuData [default: empty]
  --dataset_name=DNAME        Label of the dataset [default: empty]
  --n_iter=N_ITER             Number of repetitions of cv [default: 10]
  --model_name=MODEL_NAME     Name of the sklearn model [default: empty]
"""

# TODO: You could improve the docstring above and add more arguments if desired
from docopt import docopt
import pandas as pd
import mudata
import os
import copy
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

# Custom import
from get_feats_df import get_feats_df
from run_random_search_cv import run_random_search_cv
from combine_mdata2df import combine_mdata2df
from load_classifier_class import load_classifier_class


# This is the main entrance of the script
# TODO: You need to re-implement the main logic
# 1. Perform some kind of cv to find hyperparameters
# 2. Use those found optimal hyperparams to fit final model
# 3. Then return the weights along with feat name on each dataset + model combination
def main(mu_path, dataset_name, model_name, block_num=0, n_iter=10, random_state=42, target_col="response"):
    """
    Parameters
    ----------

    mu_path:        Path to the h5mu that contains multiomics data
    dataset_name:   Name of the dataset
    model_name:     Name of model to retrieve from Sklearn. Available options are: 
                    ['Logit', 'Linear_SVM', 'Decision_Tree', 'Random_Forest', 'AdaBoost', 'GradientBoost']
    block_num:      N-th block of all blocks to use to stratify from, default takes 0 (1st)
    n_iter:         Numbers of repetitions to run randomized search cv      
    """

    # --------------------
    # Check args
    # --------------------
    if model_name == "empty":
        raise ValueError("Did not provide right model name")
    # --------------------
    # IMPLEMENTATION
    # --------------------
    raw_mdata = mudata.read(mu_path)
    # Use a copy here to avoid mixing up stuff
    mdata = raw_mdata.copy()
    # TODO: this is uggly solution now
    # Take the modality out for usage later
    modality_names = list(mdata.mod.keys())
    # Then convert the mdata to merged dataframe column wise
    merged_df = combine_mdata2df(mdata)
    # And split them to X and Y
    X_df, y_df = merged_df.drop(columns=[target_col]), merged_df[[target_col]]
    # For a model , apply a CV on full data to find optimal hyperparam
    # then instantiate new model with best param to get feature importance or weight
    print(f"Model name is '{model_name}'")
    classifier_class, init_params, param_dist = load_classifier_class(model_name=model_name)
    clf_instance = classifier_class(**init_params) # Instantiate object from class with model init params
    # Then apply random CV on the parameter distribution of given model
    optimal_params_dict = run_random_search_cv(clf_instance, X=X_df, Y=y_df, param_distributions=param_dist, n_iter=n_iter, random_state=random_state)
    # Now, instantiate new instance of the model with optimal params instead
    opt_clf_instance = classifier_class(**optimal_params_dict)
    print(opt_clf_instance)
    # Apply scaling and fit final model
    opt_clf = make_pipeline(StandardScaler(), opt_clf_instance)
    opt_clf.fit(X_df, y_df["response"])
    # Extract the classifier from the pipeline
    classifier = opt_clf.steps[-1][1]   # Adjust this based on your pipeline's step name
    # Then could either extract their weights or feature importance
    feats_df = get_feats_df(
        classifier=classifier, feat_names=X_df.columns, 
        model_name=model_name, dataset_name=dataset_name,
        modality_names=modality_names)    
    # Fix naming here for output, specifically add sklearn and turn it to lower
    method = f"sklearn-{model_name.lower().replace(' ', '_')}"
    filename = f"{method}-{dataset_name}_features_selected.csv"
    # And write it to file
    feats_df.to_csv(filename, index=False)
    return(feats_df)




# Execute it here
if __name__ == '__main__':
  # Parse docopt
  args = docopt(__doc__)
  # Execute the main function
  main(mu_path=args['--data_path'], 
  dataset_name=args['--dataset_name'],
  model_name=args['--model_name'],
  n_iter=int(args['--n_iter'])
  )