# Use this script as temp fix, need to update the pkg instead
import os
from sklearn.metrics import f1_score
import copy
import torch
import torch.nn.functional as F
import numpy as np
import pandas as pd
# Mogonet pkg
from mogonet.train_mogonet import gen_trte_adj_mat
from mogonet.prepare_trte_data import prepare_trte_data
from mogonet.models import init_model_dict

# Othe functions to run

def test_epoch(data_list, adj_list, te_idx, model_dict):
    for m in model_dict:
        model_dict[m].eval()
    num_view = len(data_list)
    ci_list = []
    for i in range(num_view):
        ci_list.append(model_dict["C{:}".format(i+1)](model_dict["E{:}".format(i+1)](data_list[i],adj_list[i])))
    if num_view >= 2:
        c = model_dict["C"](ci_list)
    else:
        c = ci_list[0]
    c = c[te_idx,:]
    prob = F.softmax(c, dim=1).data.cpu().numpy()

    return prob

def cal_feat_imp(data_folder, view_list, num_class, he_base_dim = 100, adj_parameter = 10):
    num_view = len(view_list)
    dim_hvcdn = pow(num_class,num_view)
    # Fix later ------------------
    adj_parameter = adj_parameter
    dim_he_list = [he_base_dim] * num_view
    # Fix later -----------------
    data_tr_list, data_trte_list, trte_idx, labels_trte = prepare_trte_data(data_folder, view_list)
    adj_tr_list, adj_te_list = gen_trte_adj_mat(data_tr_list, data_trte_list, trte_idx, adj_parameter)
    featname_list = []
    for v in view_list:
        df = pd.read_csv(os.path.join(data_folder, str(v)+"_featname.csv"), header=None)
        featname_list.append(df.values.flatten())
    
    dim_list = [x.shape[1] for x in data_tr_list]
    model_dict = init_model_dict(num_view, num_class, dim_list, dim_he_list, dim_hvcdn)
    cuda = True if torch.cuda.is_available() else False
    for m in model_dict:
        if cuda:
            model_dict[m].cuda()
    # This bit is required, for the line:
    # feat_imp['imp'][j] = (f1-f1_tmp)*dim_list[i]
    te_prob = test_epoch(data_trte_list, adj_te_list, trte_idx["te"], model_dict)
    if num_class == 2:
        f1 = f1_score(labels_trte[trte_idx["te"]], te_prob.argmax(1))
    else:
        f1 = f1_score(labels_trte[trte_idx["te"]], te_prob.argmax(1), average='macro')
    
    feat_imp_list = []
    for i in range(len(featname_list)):
        feat_imp = {"feat_name":featname_list[i]}
        feat_imp['imp'] = np.zeros(dim_list[i])
        for j in range(dim_list[i]):
            feat_tr = data_tr_list[i][:,j].clone()
            feat_trte = data_trte_list[i][:,j].clone()
            data_tr_list[i][:,j] = 0
            data_trte_list[i][:,j] = 0
            adj_tr_list, adj_te_list = gen_trte_adj_mat(data_tr_list, data_trte_list, trte_idx, adj_parameter)
            te_prob = test_epoch(data_trte_list, adj_te_list, trte_idx["te"], model_dict)
            if num_class == 2:
                f1_tmp = f1_score(labels_trte[trte_idx["te"]], te_prob.argmax(1))
            else:
                f1_tmp = f1_score(labels_trte[trte_idx["te"]], te_prob.argmax(1), average='macro')
            feat_imp['imp'][j] = (f1-f1_tmp)*dim_list[i]
            data_tr_list[i][:,j] = feat_tr.clone()
            data_trte_list[i][:,j] = feat_trte.clone()
        feat_imp_list.append(pd.DataFrame(data=feat_imp))
    return feat_imp_list


def summarize_imp_feat(featimp_list_list, dataset_name, view_list, n_percent=10, method='mogonet'):
    num_rep = len(featimp_list_list)
    num_view = len(featimp_list_list[0])
    df_tmp_list = []
    for v in range(num_view):
        df_tmp = copy.deepcopy(featimp_list_list[0][v])
        #df_tmp['omics'] = np.ones(df_tmp.shape[0], dtype=int)*v
        df_tmp['omics'] = view_list[v]
        df_tmp_list.append(df_tmp.copy(deep=True))
    df_featimp = pd.concat(df_tmp_list).copy(deep=True)
    for r in range(1,num_rep):
        for v in range(num_view):
            df_tmp = copy.deepcopy(featimp_list_list[r][v])
            #df_tmp['omics'] = np.ones(df_tmp.shape[0], dtype=int)*v
            df_tmp['omics'] = view_list[v]
            # THIS IS ORIGINALLY BUGGY CODE, pandas.DataFrame.append is deprecated now
            #df_featimp = df_featimp.append(df_tmp.copy(deep=True), ignore_index=True)
            df_featimp = pd.concat([df_featimp, df_tmp.copy(deep=True)])
    df_featimp_top = df_featimp.groupby(['feat_name', 'omics'])['imp'].sum()
    df_featimp_top = df_featimp_top.reset_index()
    # Rename some columns
    df_featimp_top = df_featimp_top.rename(
      columns={
      'feat_name': 'feature', 
      'omics': 'view',
      'imp': 'coef'
    })
    # Then now for each view select the top n percent of features
    feats_df = df_featimp_top.reset_index(drop=True)
    feats_df["method"] = method
    feats_df["dataset_name"] = dataset_name
    # Make sure to match names and order
    right_order = ['feature', 'view', 'coef', 'method', 'dataset_name']
    try:
      feats_df = feats_df[right_order]
    except KeyError as e:
      print(f"Sklearn select feature for '{dataset_name}', '{model_lower}' column not found: {e}")
    return feats_df