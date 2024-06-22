#!/usr/bin/env python
"""
This script is used to read in R lists and vector to combine real data
and convert it to MAE and MuData

Author: Tony Liang

Usage:
  transform_mudata_format.py [options]
  
Options:
  --mu_path=MU_PATH             Path to read mu file [default: empty]
  --dataset_name=DNAME          Name of dataset to provide as id [default: empty]
  --var_threshold=VAR_THRES     Threhold for variance to filter features from [default: 0.16]
  --replace_na_val=NA_VAL       Value to replace NANs in omics [default: 0]
"""

# import libraries
from docopt import docopt
import pandas as pd
import mudata as mdata
import anndata as ad
# Custom import fun
from preprocess_view import preprocess_view
from convert_binary_str import convert_binary_str

# Main function here
# Requirements of the MuData
# 1. Needs to be in N observations x p_i way
# 2. Response stays at yes or no string column
# 3. Need to have a common observations names set as sample_names
# 4. Also requires to supply a dataset_name
# TODO: NOT scaling now, since it might introduce negative numbers and cause problem


def transform_mudata_format(mu_path, dataset_name, identifier_col="sample_names", var_threshold=0.16, replace_na_val=0, scale=False):
    # Read data here
    raw_data = mdata.read(mu_path)
    # Use a deeper copy of it
    data = raw_data.copy() 
    # Mudata has stricter format, so only need to check if each obs contain the
    # required columns
    must_cols = ["response", "sample_names"]
    new_mu_dict = {}
    for modality in data.mod:
        # get each modality's obs metadata and the measurements
        omic_obs = data[modality].obs
        obs_cols = set(omic_obs.columns)
        omic_df = data[modality].to_df()
        # Check if overlap needs to be two
        cols_contained = len(obs_cols & set(must_cols)) == len(must_cols)
        if not cols_contained:
            raise Exception("Did not have the contained columns: response, sample_names")
        # Then start the preprocess steps
        # Remove those of near zero variance
        # And replace nas with 0
        # And scale each
        df_reduced = preprocess_view(df = omic_df, var_threshold = var_threshold, replace_na_val=replace_na_val, scale=scale)
        # Remove those of near zero variance
        # Then check type of the reponse and convert it string only
        omic_obs["response"] = convert_binary_str(omic_obs["response"])
        # TODO: Uggly fix now to add the sample_names into it
        omic_obs[identifier_col] = data.obs_names.to_list()
        # And coerce the index of this to sample names as well
        omic_obs.index.name = identifier_col
        # Recreate new AnnData
        new_ann = ad.AnnData(X = df_reduced, 
                             obs=omic_obs, 
                             var=pd.DataFrame(df_reduced.columns, 
                                              columns=["feature"], 
                                              index=df_reduced.columns)
                            )
        new_mu_dict[modality] = new_ann
    # Then create a new mudata object
    new_mdata = mdata.MuData(new_mu_dict)
    # Lastly just write it to disk
    output_name = dataset_name + ".h5mu"
    # This data is a MuData object, hence could access its write method
    new_mdata.write(output_name)
    return new_mdata

# Execute the fun here
if __name__ == '__main__':
  # Parse docopt
  args = docopt(__doc__)
  # Execute runner
  transform_mudata_format(
    mu_path=args['--mu_path'] , dataset_name=args['--dataset_name'], 
    var_threshold=float(args['--var_threshold']), replace_na_val=float(args['--replace_na_val'])
    )