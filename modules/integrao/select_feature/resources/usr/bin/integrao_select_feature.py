#!/usr/bin/env python

"""
This is a script for integrao to perform feature selection on full portion of 
data (from MuData).

Usage:
  integrao_select_feature.py [options]

Options:
  -h --help                         Show this message
  --data_path=DATA_PATH             Path that contains full portion of MuData [default: empty]
  --dataset_name=DNAME              Label of the dataset [default: empty]
  --outdir=OUTDIR                   Directory to save the feature selection results [default: integrao_feature_selection_results]
  --n_times=N_TIMES                 Number of times to repeat the feature selection with different seeds [default: 5]
  --method_name=METHOD_NAME         Name of the method [default: integrao]
  --neighbor_size=N_SIZE            k for kNN graph [default: 20].
  --embedding_dims=E_DIMS           Latent space dimensionality [default: 64].
  --fusing_iteration=FUSE_IT        SNF diffusion iterations [default: 30].
  --normalization_factor=NF         Normalization factor [default: 1.0].
  --alignment_epochs=ALI_EPO        Unsupervised alignment epochs [default: 300].
  --finetune_epochs=FINT_EPO        Supervised fine-tuning epochs [default: 800].
  --beta=BETA                       Beta loss weight [default: 1.0].
  --mu=MU                           Mu loss weight [default: 0.5].
"""

# TODO: You could improve the docstring above and add more arguments if desired
from docopt import docopt
from integrao.integrater import integrao_integrater
from custom_integrao_predictor import CustomIntegraoPredictor
import pandas as pd
import mudata as md
import numpy as np
import torch
import os


# -------------------------
def get_default_hyperparameters():
  DEFAULT_HPARAMS = dict(
      neighbor_size=20,
      embedding_dims=64,
      fusing_iteration=30,
      normalization_factor=1.0,
      alignment_epochs=500,   # NOTE: IntegrAO API has typo "alighment_epochs"
      beta=1.0,
      mu=0.5,
      finetune_epochs=800,
      num_classes=2,
  )
  return DEFAULT_HPARAMS
# -------------------------


def set_seed(seed: int):
    """Set deterministic seeds for reproducibility."""
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)
        torch.backends.cudnn.deterministic = True
        torch.backends.cudnn.benchmark = False

def load_data(mdata_path: str):
    """Load MuData and return list of per-modality DataFrames + modality names."""
    mdata = md.read(mdata_path)
    modality_names = list(mdata.mod.keys())
    full_dfs = []
    for mod_name in modality_names:
        adata = mdata.mod[mod_name]
        X = adata.X.toarray() if hasattr(adata.X, "toarray") else adata.X
        df = pd.DataFrame(X, index=adata.obs_names, columns=adata.var_names)
        full_dfs.append(df)
        print(f"  Loaded {mod_name}: {df.shape}")

    # Extract labels (adjust this to match your label source)
    truelabel = mdata.mod[modality_names[0]].obs[["response"]].copy()
    truelabel["response"] = truelabel["response"].map({"yes": 1, "no": 0})
    return full_dfs, modality_names, truelabel

# Big function to run one seed iteration of the whole pipeline: train → save model → inference → interpret
def single_seed_run(
    full_dfs, modality_names, truelabel,
    seed, run_dir, dataset_name, hparams=None,
):
    """
    One complete seed iteration: train → save model → inference → interpret.

    Returns
    -------
    feat_imp_df : pd.DataFrame   columns = [feature, coef, view]
    preds       : np.ndarray     predicted probabilities (n_samples × n_classes)
    """
    DEFAULT_HPARAMS = get_default_hyperparameters()
    hparams = {**DEFAULT_HPARAMS, **(hparams or {})}
    os.makedirs(run_dir, exist_ok=True)
    model_path = os.path.join(run_dir, "model_integrao_supervised.pth")

    print(f"\n{'='*60}")
    print(f"  SEED {seed}  →  {run_dir}")
    print(f"{'='*60}")

    # --- seed ---
    set_seed(seed)

    # --- train ---
    # ================================================================================
    print("\n[1/4] Training integrater ...")
    integrater = integrao_integrater(
        full_dfs,
        dataset_name,
        modalities_name_list=modality_names,
        neighbor_size=hparams["neighbor_size"],
        embedding_dims=hparams["embedding_dims"],
        fusing_iteration=hparams["fusing_iteration"],
        normalization_factor=hparams["normalization_factor"],
        alighment_epochs=hparams["alignment_epochs"],
        beta=hparams["beta"],
        mu=hparams["mu"],
    )
    fused_networks = integrater.network_diffusion()
    embeds_final, S_final, model = integrater.unsupervised_alignment()
    # Use a hard code path for the unsupervised ver
    torch.save(model.state_dict(), os.path.join(run_dir, "model.pth"))
    # ===============================================================================
    print("\n[2/4] Classification finetuning ...")
    embeds_final, S_final, model, preds = integrater.classification_finetuning(
        truelabel, run_dir, finetune_epochs=hparams["finetune_epochs"],
    )
    # And here is the final one
    torch.save(model.state_dict(), model_path)
    print(f"       Model saved → {model_path}")

    # --- build predictor (re-uses same hparams) ---
    print("\n[3/4] Inference ...")
    predictor = CustomIntegraoPredictor(
        full_dfs,
        "feature_selection",
        modalities_name_list=modality_names,
        neighbor_size=hparams["neighbor_size"],
        embedding_dims=hparams["embedding_dims"],
        fusing_iteration=hparams["fusing_iteration"],
        normalization_factor=hparams["normalization_factor"],
        alighment_epochs=hparams["alignment_epochs"],
        beta=hparams["beta"],
        mu=hparams["mu"],
        num_classes=hparams["num_classes"]
    )
    fused_networks = predictor.network_diffusion()

    preds = predictor.inference_supervised(
        model_path=model_path,
        new_datasets=full_dfs,
        modalities_names=modality_names
    )

    # --- interpret ---
    print("\n[4/4] Computing feature importance (Integrated Gradients) ...")
    feat_imp_df = predictor.interpret_supervised(
        model_path=model_path,
        new_datasets=full_dfs,
        modalities_names=modality_names
    )
    feat_imp_df["seed"] = seed

    # Save per-seed results
    feat_imp_df.to_csv(os.path.join(run_dir, "feature_importance.csv"), index=False)
    print(f"       Results saved → {run_dir}/")

    return feat_imp_df

# Helper function to run the whole feature selection loop for multiple seeds and aggregate the results
def run_feat_selection_loop(outdir, full_dfs, modality_names, truelabel, hparams, dataset_name, n_times=5):
    # Create directory first
    os.makedirs(outdir, exist_ok=True)
    all_feat_dfs = []
    # Then the loop
    for s in range(n_times):
        seed = f"{s+1}"
        run_dir = os.path.join(outdir, f"seed_{s+1}")
        feat_df = single_seed_run(
            full_dfs, modality_names, truelabel,
            seed=int(seed),
            run_dir=run_dir,
            hparams=hparams,
            dataset_name=dataset_name
        )
        all_feat_dfs.append(feat_df)
    return all_feat_dfs

def summarize_feature_importance(df_list):
    # First combine it
    all_df = pd.concat(df_list, ignore_index=True)
    # Then take mean of features per view and rename it
    agg_df = (
        all_df
        .groupby(["feature", "view"])["coef"]
        .agg(mean_coef="mean")
        .reset_index()
        .rename(columns={"mean_coef": "coef"})
    )
    return agg_df

def wrangle_result_table(df, method, dataset_name):
    feats_df = df.copy()
    # Then add other metadata
    feats_df["method"] = method
    feats_df["dataset_name"] = dataset_name
    # Make sure to match names and order
    right_order = ['feature', 'view', 'coef', 'method', 'dataset_name']
    try:
      feats_df = feats_df[right_order]
    except Exception as e:
      print(f"IntegrAO select feature for '{dataset_name}', column not found: {e}")
    return feats_df



# This is the main entrance of the script
def main(
    mdata_path: str,
    dataset_name: str,
    method: str = "integrao",
    n_times: int = 5,
    outdir: str = "feature_selection_results",
    hparams: dict = None
):
    """
    Run the full pipeline across multiple seeds and aggregate results.

    Returns
    -------
    feats_df : pd.DataFrame  with columns [feature, view, coef, method_name, dataset]
    """

    # Common objects to be used through the place
    full_dfs, modality_names, truelabel = load_data(mdata_path)
    # Run the feature selection loop
    all_feat_dfs = run_feat_selection_loop(
        outdir=outdir, full_dfs=full_dfs, modality_names=modality_names, 
        truelabel=truelabel, hparams=hparams, dataset_name=dataset_name, n_times=n_times)
    # --- Aggregate feature importances ---
    agg_feat_df = summarize_feature_importance(all_feat_dfs)
    # --- Now add metadata info ---
    feats_df = wrangle_result_table(agg_feat_df, method, dataset_name)
    # Lastly write out to file
    filename = f"{method}-{dataset_name}_features_selected.csv"
    feats_df.to_csv(filename, index=False, header=True)
    return feats_df

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
      "beta": float(args["--beta"]),
      "mu": float(args["--mu"]),
      "finetune_epochs": int(args["--finetune_epochs"]),
  }
  # Execute the main function
  main(
      mdata_path=args['--data_path'], 
      dataset_name=args['--dataset_name'],
      method=args['--method_name'],
      outdir=args['--outdir'],
      n_times=int(args['--n_times']),
      hparams=hparams_dict
  )