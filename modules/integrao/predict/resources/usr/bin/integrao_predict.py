#!/usr/bin/env python

"""
This is a integrao prediction script, loads torch like models and make predictions
Output a summary table with test probability in it.

Usage:
  integrao_predict.py [options]

Options:
  -h --help                                 Show this message
  --model_dir=MODEL_DIR                     Dir to trained model on specific fold [default: empty]
  --preprocessed_data_dir=PREPR_DATA_DIR    Dir to preprocessed data dir for specific fold [default: empty]
  --dataset_name=DATASET_NAME               Dataset name (repeated in purpose)[default: empty]
  --label=LABEL                             Label of dataset and fold iteration [default: empty]
  --method_name=METHOD_NAME                 Method name ran [default: integrao]
"""

# TODO: The docopt help message above can be better described or reformatted

from custom_integrao_predictor import CustomIntegraoPredictor
from docopt import docopt
import json
import pandas as pd
import mudata as md
import os
import hashlib
import re


def label_to_seed(label, prime=999983):
    hash_value = int(hashlib.sha256(label.encode()).hexdigest(), 16)
    return hash_value % prime  # Controls range

# See here: https://stackoverflow.com/questions/70584201/i-dont-understand-why-set-seed-is-needed-with-torch-and-tensorflow-import
# Function to set a seed
def seed_everything(seed: int):
    import random
    import os
    import numpy as np
    import torch
    
    random.seed(seed)
    os.environ['PYTHONHASHSEED'] = str(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed(seed)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = True
        # ^^ safe to call this function even if cuda is not available


def binarize_labels(series, positive="yes", negative="no"):
    """
    Convert a categorical series to binary 0/1 labels.
    
    Parameters
    ----------
    series : pd.Series
        Series containing string labels (e.g., "yes"/"no").
    positive : str
        The label to treat as 1.
    negative : str
        The label to treat as 0.
    
    Returns
    -------
    pd.Series
        Binary series of 0/1.
    """
    return series.map({positive: 1, negative: 0})


def extract_test_predictions(full_pred_probs, full_mdata, test_mdata, modality_names):
    """
    Extract predicted probabilities and true labels for test samples.

    Parameters
    ----------
    full_pred_probs : np.ndarray
        Predicted probabilities for all samples (shape: n_samples x n_classes).
    full_mdata : mudata.MuData
        Full MuData object containing all samples.
    test_mdata : mudata.MuData
        MuData object containing only test samples.
    modality_names : List of str
        All names of modalities.

    Returns
    -------
    pd.DataFrame
        DataFrame indexed by test sample IDs with columns:
        - pred_prob : predicted probability of positive class
        - y : true binary label
    """
    # Map probabilities to full sample index
    all_probs_df = pd.DataFrame(
        {"phat": full_pred_probs[:, 1]},  # positive class in binary
        index=full_mdata.obs.index
    )

    # Subset to test samples
    test_probs = all_probs_df.loc[test_mdata.obs.index]

    # Extract true labels and binarize
    true_labels = binarize_labels(test_mdata.mod[modality_names[0]].obs["response"])

    # Combine into one DataFrame
    results_df = pd.DataFrame({
        "phat": test_probs["phat"],
        "y": true_labels
    }, index=test_mdata.obs.index)

    return results_df


def extract_fold_name(label, pattern="fold_\\d+"):
    matches = re.findall(pattern, label)
    return matches[0]

# NOTE: This is bad when dealing with sim data that have sim-data_fold...
# So just pass the dataset name directly from CLI
# def extract_dataset_name(label, pattern="-"):
#     return label.split(pattern)[0]

def generate_result_table(test_df, method_name, dataset_name=None, label=None, decimals=3):
    """
    Format a result table with predicted probabilities and metadata.

    Parameters
    ----------
    test_df : pd.DataFrame
        DataFrame with columns ['pred_prob', 'y'] and index as sample IDs.
    method_name : str
        Name of the prediction method.
    dataset_name : str or None
        Name of the dataset (optional).
    decimals : int
        Number of decimals to round predicted probabilities.

    Returns
    -------
    pd.DataFrame
        Formatted results table.
    """
    df = test_df.copy()
    df = df.reset_index().rename(columns={"index": "sample_name"})
    df["fold"] = extract_fold_name(label)
    df["sample_name"] = df["sample_name"].astype(str)
    df["phat"] = df["phat"].round(decimals)
    df["method_name"] = method_name
    if dataset_name is not None:
        df["dataset"] = dataset_name
    else:
        df["dataset"] = label

    # Ensure column order
    desired_order = ["sample_name", "y", "phat", "method_name", "dataset", "fold"]
    df = df[desired_order]

    return df

    
def load_metadata(preprocessed_dir):
    """Load preprocessing metadata.

    Parameters
    ----------
    preprocessed_dir : str
        Directory from preprocess step.

    Returns
    -------
    metadata : dict
        Metadata with test_ids, label_map_inverse, etc.
    """
    with open(os.path.join(preprocessed_dir, "metadata.json")) as f:
        metadata = json.load(f)
    return metadata

def load_hparams(model_dir):
    """Load training hyperparameters.

    Parameters
    ----------
    model_dir : str
        Directory from train step.

    Returns
    -------
    hparams : dict
        Hyperparameters including modality_names, num_classes.
    """
    with open(os.path.join(model_dir, "hparams.json")) as f:
        hparams = json.load(f)
    return hparams

def load_full_data(preprocessed_dir, modality_names):
    """Load full dataset for transductive prediction.

    Parameters
    ----------
    preprocessed_dir : str
        Directory containing full_data.h5mu.
    modality_names : list of str
        Ordered modality names.

    Returns
    -------
    full_mdata : mudata.MuData
        Full MuData object.
    full_dfs : list of pd.DataFrame
        Per-modality DataFrames (samples x features).
    """
    full_mdata = md.read(os.path.join(preprocessed_dir, "full_data.h5mu"))
    print(f"Loaded full dataset: {full_mdata.n_obs} samples, {len(modality_names)} modalities")

    full_dfs = []
    for mod_name in modality_names:
        adata = full_mdata.mod[mod_name]
        df = pd.DataFrame(
            adata.X.toarray() if hasattr(adata.X, "toarray") else adata.X,
            index=adata.obs_names,
            columns=adata.var_names,
        )
        full_dfs.append(df)
        print(f"  {mod_name}: {df.shape}")

    return full_mdata, full_dfs

def build_predictor(full_dfs, hparams,
                    dataset_name="messi_integrao"):
    """Initialize the IntegrAO predictor on the full graph.

    Parameters
    ----------
    full_dfs : list of pd.DataFrame
        Per-modality DataFrames for all samples.
    modality_names : list of str
        Modality names.
    hparams : dict
        Hyperparameters from training.
    dataset_name : str
        Name used internally by IntegrAO.

    Returns
    -------
    predictor : integrao_predictor
        Initialized predictor with fused network.
    """
    predictor = CustomIntegraoPredictor(
        full_dfs,
        dataset_name,
        modalities_name_list=hparams["modality_names"],
        neighbor_size=hparams["neighbor_size"],
        embedding_dims=hparams["embedding_dims"],
        fusing_iteration=hparams["fusing_iteration"],
        normalization_factor=hparams["normalization_factor"],
        alighment_epochs=hparams["alignment_epochs"],  # NOTE: typo is in IntegrAO's API
        beta=hparams["beta"],
        mu=hparams["mu"],
        num_classes=hparams["num_classes"],
    )

    print("Running network diffusion on full graph...")
    predictor.network_diffusion()
    return predictor


# Main entry point for prediction script
def main(model_dir, preprocessed_data_dir, label, dataset_name, method_name):
    # set seed here
    seed = label_to_seed(label)
    seed_everything(seed)

    # -------------
    #metadata = load_metadata(preprocessed_data_dir)
    hparams = load_hparams(model_dir)
    modality_names = hparams["modality_names"]
    full_mdata, full_dfs = load_full_data(preprocessed_data_dir, modality_names)
    test_mdata = md.read(os.path.join(preprocessed_data_dir, "test_data.h5mu"))
    # --- Construct the predictor on full data (design of integrao is to use full data instead of just test data) and then predict on test ids)
    predictor = build_predictor(full_dfs, hparams, dataset_name=label)
    # Run inference on the full data with the trained model from earlier step
    full_pred_probs = predictor.inference_supervised(
        model_path=os.path.join(model_dir, "model_integrao_supervised.pth"), 
        new_datasets=full_dfs, modalities_names=modality_names
    )
    probs_df = extract_test_predictions(full_pred_probs, full_mdata, test_mdata, modality_names)
    # Now add metadata back to this probs_df and generate the result table
    result_df = generate_result_table(probs_df, method_name=method_name, dataset_name=dataset_name, label=label)
    # Lastly write out to file
    result_file = f"{label}-result.csv"
    result_df.to_csv(result_file, index=False, header=True)
    return result_df

# Execute it here
if __name__ == '__main__':
  # Parse docopt
  args = docopt(__doc__)
  # Execute the main function
  print(args)
  main(
    model_dir=args['--model_dir'], 
    preprocessed_data_dir=args['--preprocessed_data_dir'], 
    label=args['--label'],
    dataset_name=args['--dataset_name'],
    method_name=args['--method_name']
  )