#!/usr/bin/env python
"""
This script is used to read mudata and apply suitable transformation to match
those criterias in the pipeline to run cv on methods.

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
# 3. Need to have a common observations names set as sample_name
# 4. Also requires to supply a dataset_name
# TODO: NOT scaling now, since it might introduce negative numbers and cause problem


def transform_mudata_format(mu_path, dataset_name, identifier_col="sample_name", var_threshold=0.16, replace_na_val=0, scale=False):
    # Read data here
    raw_data = mdata.read(mu_path)
    # Use a deeper copy of it
    data = raw_data.copy() 
    # Mudata has stricter format, so only need to check if each obs contain the
    # required columns
    accepted_cols = set(["response", "sample_names", "sample_name"])
    new_mu_dict = {}
    for modality in data.mod:
      
        # get each modality's obs metadata and the measurements
        omic_obs = data[modality].obs
        obs_cols = set(omic_obs.columns)
        # Check if at least contains response or sample_name/s in accepted cols
        # The second part checks for sample in index
        cols_contained = len(accepted_cols & obs_cols) >= 2 or omic_obs.index.name in accepted_cols
        if not cols_contained:
            raise Exception("Did not have the contained columns: response, sample_name")

        # TODO: Uggly fix now to add the sample_name into it
        # Check if identifier_col is already in the DataFrame
        if identifier_col in obs_cols:
            # If identifier_col is present, drop sample_names if it exists
            if 'sample_names' in obs_cols:
                omic_obs = omic_obs.drop(columns=['sample_names'])
        else:
            # If identifier_col is not present, check if sample_names is in the DataFrame
            if 'sample_names' in obs_cols:
                # If sample_names is present, rename it to identifier_col
                omic_obs = omic_obs.rename(columns={'sample_names': identifier_col})
            else:
                # If neither are present, create identifier_col from mudata source
                omic_obs[identifier_col] = data.obs_names.to_list() 
        # And coerce the index of this to sample name as well
        omic_obs.index.name = identifier_col
        # Then check type of the reponse and convert it string only
        omic_obs["response"] = convert_binary_str(omic_obs["response"])
        # Then start the preprocess steps
        omic_df = data[modality].to_df()
        # Remove those of near zero variance
        # And replace nas with 0
        # And scale each
        df_reduced = preprocess_view(df = omic_df, var_threshold = var_threshold, replace_na_val=replace_na_val, scale=scale)
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
  # TODO: Remove the replace na val as its not doing anything here
  transform_mudata_format(
    mu_path=args['--mu_path'] , dataset_name=args['--dataset_name'], 
    var_threshold=float(args['--var_threshold']), replace_na_val=float(args['--replace_na_val'])
    )