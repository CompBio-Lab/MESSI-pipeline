import os
import mudata

# Given a directory to fold, that contains train_mu.h5mu
# and test_mu.h5mu, load these in memory
def load_tr_te(fold_dir):
    # Find the train mu and test mu inside the fold path
    d = os.listdir(fold_dir)
    # Retrieve the paths to train data and test data
    train_path  = next((os.path.join(fold_dir, path) for path in d  if 'train' in path), None)
    test_path   = next((os.path.join(fold_dir, path) for path in d  if 'test' in path), None)
    # Load as mudata then transform as dataframe
    train_data = mudata.read(train_path)
    test_data  = mudata.read(test_path)
    return train_data, test_data