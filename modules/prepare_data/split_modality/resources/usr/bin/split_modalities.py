#!/usr/bin/env python
"""
Split a  MuData into one single-modality MuData per view.

Used by the single-modality mode (params.single_modality_mode): each output is a
first-class dataset named '{dataset_name}-{modality}' so that downstream
splitting / cross-validation / methods run UNCHANGED.

Requirements on the input (already enforced by transform_mudata_format.py):
  - each modality's obs contains 'response' (yes/no) and 'sample_name'

Usage:
  split_modalities.py [options]

Options:
  --mu_path=MU_PATH           Path to the processed MuData [default: empty]
  --dataset_name=DNAME        Parent dataset name [default: empty]
"""

from docopt import docopt
import mudata
import re

def make_safe_id(value):
    """Safe for filenames, Nextflow work outputs, and shell paths."""
    value = str(value).strip()
    value = re.sub(r"\s+", "_", value)              # spaces → _
    value = re.sub(r"[^A-Za-z0-9._-]", "_", value)  # other unsafe chars → _
    value = re.sub(r"_+", "_", value)               # collapse ___
    return value.strip("._-")


def split_modality(mdata, mod_names, dataset_name=""):
    out_files = []

    safe_dataset_name = make_safe_id(dataset_name)

    for mod in mod_names:
        mod_obs = mdata[mod].obs

        for col in ("response", "sample_name"):
            if col not in mod_obs.columns:
                raise KeyError(
                    f"{dataset_name}/{mod}: mod-level obs missing '{col}'"
                )

        # Keep the original modality key inside the MuData object.
        sub = mudata.MuData({mod: mdata[mod].copy()})

        safe_mod = make_safe_id(mod)
        out_file = f"{safe_dataset_name}-{safe_mod}_processed.h5mu"

        sub.write(out_file)
        out_files.append(out_file)

        print(
            f"[INFO] Wrote {out_file} "
            f"({sub.n_obs} obs × {mdata[mod].n_vars} vars)"
        )

    return out_files


def main(mu_path, dataset_name):
    mdata = mudata.read(mu_path)
    mod_names = list(mdata.mod.keys())
    if len(mod_names) < 2:
        print(f"[WARN] {dataset_name} has a single modality ({mod_names}); nothing to split")
    out_files = split_modality(mdata, mod_names, dataset_name)
    return out_files


if __name__ == "__main__":
    args = docopt(__doc__)
    files = main(args["--mu_path"], args["--dataset_name"])
    # Print file names one per line so the wrapping process can glob them
    print("\n".join(files))
