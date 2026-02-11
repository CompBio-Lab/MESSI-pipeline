#!/usr/bin/env python

"""
This is script to train model from integrao method. Output is a fitted model on the previously
processed train MuData, and previously processed test MuData from specific fold.

Usage:
    integrao_train.py [options]

Options:
    -h --help                         Show this message
    --fold_path=FOLD_PATH             Directory containing one split directory of relevant input [default: empty] 
    --label=LABEL                     Label of dataset and fold iteration [default: empty]
    --neighbor_size=N_SIZE            k for kNN graph [default: 20].
    --embedding_dims=E_DIMS           Latent space dimensionality [default: 64].
    --fusing_iteration=FUSE_IT        SNF diffusion iterations [default: 30].
    --normalization_factor=NF         Normalization factor [default: 1.0].
    --alignment_epochs=ALI_EPO        Unsupervised alignment epochs [default: 300].
    --finetune_epochs=FINT_EPO        Supervised fine-tuning epochs [default: 800].
    --beta=BETA                       Beta loss weight [default: 1.0].
    --mu=MU                           Mu loss weight [default: 0.5].
"""



from docopt import docopt
import json
import os
import mudata as md
import pandas as pd
import torch
import hashlib

from integrao.integrater import integrao_integrater


# See here: https://stackoverflow.com/questions/70584201/i-dont-understand-why-set-seed-is-needed-with-torch-and-tensorflow-import
# Function to set a seed
def seed_everything(seed: int):
    import random, os
    import numpy as np
    import torch

    random.seed(seed)
    os.environ['PYTHONHASHSEED'] = str(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed(seed)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False
        # ^^ safe to call this function even if cuda is not available


def load_train_data(preprocessed_dir):
    """Load preprocessed training data and metadata.

    Parameters
    ----------
    preprocessed_dir : str
        Directory from preprocess step.

    Returns
    -------
    train_mdata : mudata.MuData
        Training MuData object.
    metadata : dict
        Metadata including modality names, num_classes, label mapping.
    """
    with open(os.path.join(preprocessed_dir, "metadata.json")) as f:
        metadata = json.load(f)

    train_mdata = md.read(os.path.join(preprocessed_dir, "train_data.h5mu"))
    print(f"Training with {train_mdata.n_obs} samples, {len(metadata['modality_names'])} modalities")
    print(f"Modalities: {metadata['modality_names']}")
    print(f"Num classes: {metadata['num_classes']}")
    return train_mdata, metadata


def extract_modality_dfs(mdata, modality_names):
    """Extract per-modality DataFrames from MuData.

    IntegrAO expects a list of pandas DataFrames (samples x features).

    Parameters
    ----------
    mdata : mudata.MuData
        MuData object.
    modality_names : list of str
        Ordered list of modality names to extract.

    Returns
    -------
    dfs : list of pd.DataFrame
        One DataFrame per modality, indexed by sample ID.
    """
    dfs = []
    for mod_name in modality_names:
        adata = mdata.mod[mod_name]
        df = pd.DataFrame(
            adata.X.toarray() if hasattr(adata.X, "toarray") else adata.X,
            index=adata.obs_names,
            columns=adata.var_names,
        )
        dfs.append(df)
        print(f"  {mod_name}: {df.shape}")
    return dfs


def extract_train_labels(train_mdata, modality_names):
    """Extract 0-indexed training labels in IntegrAO format.

    Parameters
    ----------
    train_mdata : mudata.MuData
        Training MuData with 'response' in .obs.

    Returns
    -------
    train_labels : pd.DataFrame
        DataFrame with 'cluster.id' column (IntegrAO convention).
    """
    # The labels are consistent between modalities, so get from 1 is ok
    train_labels = train_mdata.mod[modality_names[0]].obs[["response"]].copy()
    train_labels["response"] = train_labels["response"].map({"yes": 1, "no": 0})
    train_labels.columns = ["cluster.id"]
    return train_labels


def save_hparams(outdir, modality_names, num_classes, seed, **hparams):
    """Save hyperparameters as JSON for the test script.

    Parameters
    ----------
    outdir : str
        Output directory.
    modality_names : list of str
        Modality names.
    num_classes : int
        Number of classes.
    seed : int
        Random seed.
    **hparams
        All IntegrAO hyperparameters.
    """
    hparams_dict = {
        "modality_names": modality_names,
        "num_classes": num_classes,
        "seed": seed,
        **hparams,
    }
    path = os.path.join(outdir, "hparams.json")
    with open(path, "w") as f:
        json.dump(hparams_dict, f, indent=2)
    print(f"Hyperparameters saved to {path}")


def label_to_seed(label, prime=999983):
    hash_value = int(hashlib.sha256(label.encode()).hexdigest(), 16)
    return hash_value % prime  # Controls range


# from upstream process
def main(fold_path, label, hparams_dict):
    seed = label_to_seed(label)
    # Make output directory
    outdir = f"{fold_path}-model" # Use label directly as outdir since it already contains dataset and fold info
    os.makedirs(outdir, exist_ok=True)
    # --- Pipeline ---
    seed_everything(seed)
    # Load train and test data from fold_path
    train_mdata, metadata = load_train_data(fold_path)
    modality_names = metadata["modality_names"]
    num_classes = metadata["num_classes"]

    # Extract the train dfs
    train_dfs = extract_modality_dfs(train_mdata, modality_names)
    train_labels = extract_train_labels(train_mdata, modality_names)
    # --- TRAINING ---
    # Initialize the integrater
    integrater = integrao_integrater(
        datasets=train_dfs,
        dataset_name=label,   # used for naming the intermediate files during training
        modalities_name_list=modality_names,   # used for naming the incomplete modalities during new sample inference
        neighbor_size=hparams_dict["neighbor_size"],
        embedding_dims=hparams_dict["embedding_dims"],
        fusing_iteration=hparams_dict["fusing_iteration"],
        normalization_factor=hparams_dict["normalization_factor"],
        alighment_epochs=hparams_dict["alignment_epochs"], # NOTE: typo is in IntegrAO's API, so we have to use "alighment_epochs" instead of "alignment_epochs"
        beta=hparams_dict["beta"],
        mu=hparams_dict["mu"],
        random_state=seed
    )
    # Data indexing
    fused_networks = integrater.network_diffusion()
    embeds_final, S_final, model = integrater.unsupervised_alignment()
    # Save the unsupervised model fisrt
    torch.save(model.state_dict(), os.path.join(outdir, "model_unsupervised.pth"))
    # Extra sub labels step from integrao?
    truelabel_sub = train_labels[train_labels.index.isin(embeds_final.index)]
    # Then fine-tuning
    embeds_final, S_final, model, preds = integrater.classification_finetuning(
        truelabel_sub, 
        outdir, # This looks for the unsupervised model in the same folder, so we can just reuse the same outdir
        finetune_epochs=hparams_dict["finetune_epochs"]
    )
    # Save the finetuned model
    torch.save(model.state_dict(), os.path.join(outdir, "model_integrao_supervised.pth"))
    # Save the hparams for test script
    save_hparams(
    outdir, modality_names, num_classes, seed,
    **hparams_dict
    )
    # And writing the metadata file for downstream
    return model
# Execute it here
if __name__ == '__main__':
    # Parse docopt
    args = docopt(__doc__)
    hparams_dict = {
        "neighbor_size": int(args["--neighbor_size"]),
        "embedding_dims": int(args["--embedding_dims"]),
        "fusing_iteration": int(args["--fusing_iteration"]),
        "normalization_factor": float(args["--normalization_factor"]),
        "alignment_epochs": int(args["--alignment_epochs"]),
        "finetune_epochs": int(args["--finetune_epochs"]),
        "beta": float(args["--beta"]),
        "mu": float(args["--mu"])
    }
    # Execute the main function
    main(
        fold_path = args["--fold_path"],
        label     = args["--label"],
        hparams_dict = hparams_dict,
    )

