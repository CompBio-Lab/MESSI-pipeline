#!/usr/bin/env python
"""
This is the script to split Mudata, it is designed to
return single splits within a fold.

Author: Tony Liang

Usage:
  split_tr_te.py [options] MDATA

Arguments:
  MDATA                    path to find MuData format

Options:
  --split_type=SPLIT_TYPE       Type of split: skf, sgkf, logo                  [default: skf]
  --num_splits=NUM_SPLITS       Number of splits to generate		            [default: 10]
  --seed=SEED                   Random number seed to reproduce                 [default: 329]
  --outcome_type=OUTCOME_TYPE   Type of outcome: classification or survival     [default: classification]
  --event_col=EVENT_COL         Column name for survival event (survival only)  [default: os_event]
  --output_dir=OUT_DIR          Output folder to write fold ids txt             [default: splits]
  --split_txt_name=SNAME        Name of individual fold txt file                [default: fold]
"""

from docopt import docopt
from anndata import AnnData
from dataclasses import dataclass
from sklearn.model_selection import StratifiedKFold, StratifiedGroupKFold, LeaveOneGroupOut
import pandas as pd
import numpy as np
import mudata
import os

# ------------------------------------------------------------------------------
# Configuration dataclass
# ------------------------------------------------------------------------------
@dataclass
class SplitConfig:
    split_type: str
    k: int
    seed: int
    identifier_col: str = "sample_name"
    outcome_type: str = "classification"
    event_col: str = "event"
    output_dir: str = "splits"
    split_txt_name: str = "fold"


# ------------------------------------------------------------------------------
# Utility functions (functional, stateless)
# ------------------------------------------------------------------------------
def load_mudata(path, identifier_col, outcome_type="classification", event_col="os_event"):
    mdata = mudata.read(path)
    block_key = list(mdata.mod.keys())[0]
    block = mdata.mod[block_key]

    X = block.to_df()
    groups = block.obs[identifier_col].values
    
    if outcome_type == "survival":
        y = block.obs[event_col].values
    else:
        y = block.obs["response"].values

    return X, y, groups

def create_splitter(split_type, k, seed):
    if split_type == "skf":
        return StratifiedKFold(n_splits=k, shuffle=True, random_state=seed)

    if split_type == "sgkf":
        return StratifiedGroupKFold(n_splits=k, shuffle=True, random_state=seed)

    if split_type == "logo":
        return LeaveOneGroupOut()

    raise ValueError(f"Unknown split_type: {split_type}")




def write_indices(path, indices):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("\n".join(map(str, indices)))
    print(f"[INFO] Wrote {path}")


# ------------------------------------------------------------------------------
# Split Engine (OOP — keeps configuration/state)
# ------------------------------------------------------------------------------
class SplitEngine:
    def __init__(self, cfg: SplitConfig):
        self.cfg = cfg

    def run(self, X, y, groups):
        splitter = create_splitter(self.cfg.split_type, self.cfg.k, self.cfg.seed)

        # Choose correct iterator
        if self.cfg.split_type == "skf":
            iterator = splitter.split(X, y)
        else:
            iterator = splitter.split(X, y, groups)

        results = {}
        for fold_idx, (_, test_idx) in enumerate(iterator, start=1):
            fname = f"{self.cfg.split_txt_name}_{fold_idx}.txt"
            path = os.path.join(self.cfg.output_dir, fname)

            write_indices(path, test_idx)
            results[fname] = test_idx

        return results

# ------------------------------------------------------------------------------
# Main entry point (functional, thin)
# ------------------------------------------------------------------------------
def main(args):
    cfg = SplitConfig(
        split_type=args["--split_type"],
        k=int(args["--num_splits"]),
        seed=int(args["--seed"]),
        identifier_col=args.get("--identifier_col", "sample_name"),
        event_col=args.get("--event_col", "os_event"),
	    outcome_type=args.get("--outcome_type", "classification"),
        output_dir=args["--output_dir"],
        split_txt_name=args["--split_txt_name"],
    )

    # Load the MuData and extract X, y, groups
    # Groups default is to sample_name
    X, y, groups = load_mudata(args["MDATA"], cfg.identifier_col, outcome_type=cfg.outcome_type,
                               event_col=cfg.event_col)

    engine = SplitEngine(cfg)
    folds = engine.run(X, y, groups)

    return folds

# Cli arguments from parsing docstring
if __name__ == "__main__":
  args = docopt(__doc__)
  print(args)
  # And execute main
  main(args)
