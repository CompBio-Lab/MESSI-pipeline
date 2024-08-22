from docopt import docopt
import pandas as pd
import mudata as mdata
import os
# Custom functions import
from tr_te_mdata        import  tr_te_mdata
from save_blocks_labels import  save_blocks_labels
#from merge_obs_metadata import  merge_obs_metadata
from get_idxs           import  get_idxs

def prepare_mogonet_feat_select(mdata, dataset_name, random_state=123, block_num=0, test_size=0.25):
    # It still needs to be splitted as specified format of mogonet
    outdir = f"{dataset_name}-random_state_{random_state}"
    os.makedirs(outdir, exist_ok=True)
    # Merge all obs stuff
    #obs_df = merge_obs_metadata(mdata.obs)
    # TODO: use the first modality only?
    first_mod = list(mdata.mod.keys())[0]
    obs_df = mdata.mod[first_mod].obs
    # Get idxs
    train_idx, test_idx = get_idxs(mdata, random_state, block_num, test_size)
    train, test, meta_test = tr_te_mdata(mdata, train_idx, test_idx, meta=obs_df)
    # Then save this as usual
    print("Saving mogonet inputs")
    save_blocks_labels(train, test, outdir)
    print("Saved")
    return outdir