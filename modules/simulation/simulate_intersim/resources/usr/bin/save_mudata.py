from mudata import MuData
from anndata import AnnData
import numpy as np
import pandas as pd

def save_mudata(X_dict, meta_df, feat_names_dict, dataset_name):
  # X_dict is dict of all the omics count data in array
  # meta_df is dataframe of relevant metadata information like subject
  # identifier, response
  # feat_names_dict is the feature names of X_dict
  
  # Combine to mudata
  mu_dict = {}
  for b, mat in X_dict.items():
    var_names = feat_names_dict[b]
    var = pd.DataFrame(var_names, columns=["feature"])
    ann = AnnData(X = mat, 
                  obs = meta_df, 
                  var = var)
    ann.obs_names = meta_df['sample_name']
    ann.var_names = var_names
    mu_dict[b] = ann  
  
  # store to mudata
  mdata = MuData(mu_dict)
  # Write to file
  output_path = f"{dataset_name}.h5mu"
  mdata.write(output_path)
  return None
