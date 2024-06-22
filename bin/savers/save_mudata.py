from mudata import MuData
from anndata import AnnData
import numpy as np
import pandas as pd

def save_mudata(object, name, message, **kwargs):
  # Get blocks and metadata and other useful params
  blocks = object.get('blocks')
  metadata = object.get('metadata')
  var_names = kwargs['var_names']
  # Combine to mudata
  mu_dict = {}
  for b, mat in blocks.items():
    var = pd.DataFrame(var_names[b], columns=["feature"])
    ann = AnnData(X = mat, 
                  obs = metadata, 
                  var = var)
    ann.obs_names = metadata.get('sample_names')
    ann.var_names = var_names[b]
    mu_dict[b] = ann  
  
  # store to mudata
  mdata = MuData(mu_dict)
  # Write to file
  output_name = name + ".h5mu"
  mdata.write(output_name)
  return mdata
