from integrao.integrater import integrao_predictor
from integrao.IntegrAO_supervised import IntegrAO
from captum.attr import IntegratedGradients
import pandas as pd
import numpy as np
import os

import torch
import torch_geometric.transforms as T
import torch.nn.functional as F
from integrao.dataset import GraphDataset



# Implement a custom integrao predictor that inherits from integrao_predictor and overrides the interpret_supervised and inference_supervised methods
# to return predicted probabilities and feature importance for the new datasets. 
class Custom_Integrao_Predictor(integrao_predictor):
    def inference_supervised(self, model_path, new_datasets, modalities_names):
        # loop through the new_dataset and create Graphdatase
        device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")

        model = IntegrAO(self.feature_dims, self.hidden_channels, self.embedding_dims, num_classes=self.num_classes).to(device)
        model = self._load_pre_trained_weights(model, model_path, device)

        x_dict = {}
        edge_index_dict = {}
        for i, modal in enumerate(new_datasets):
            # find the index of the modal in the self.modalities_name_list
            model_name = modalities_names[i]
            modal_index = self.modalities_name_list.index(model_name)

            dataset = GraphDataset(
                self.neighbor_size,
                modal.values,
                self.fused_networks[modal_index].values,
                transform=T.ToDevice(device),
            )
            modal_dg = dataset[0]

            x_dict[modal_index] = modal_dg.x
            edge_index_dict[modal_index] = modal_dg.edge_index

        # Now to do the inference
        final_embeddings, _, preds, id_list = model(
            x_dict, edge_index_dict, self.dict_original_order
        )

        preds = F.softmax(preds, dim=1)
        preds = preds.detach().cpu().numpy()
        # MODIFICATION: instead of returning the predicted class labels, we return the predicted probabilities for each class.
        # preds = np.argmax(preds, axis=1)
        return preds

    def interpret_supervised(self, model_path, new_datasets, modalities_names):
        # loop through the new_dataset and create Graphdatase
        device = torch.device("cuda:0" if torch.cuda.is_available() else "cpu")
        model = IntegrAO(self.feature_dims, self.hidden_channels, self.embedding_dims, num_classes=self.num_classes).to(device)
        model = self._load_pre_trained_weights(model, model_path, device)

        # It takes variable node features (x) for a given domain,
        # while keeping the rest of the inputs (static_x_dict, edge_index_dict, and domain_sample_ids) fixed.
        def custom_forward(x, static_x_dict, edge_index_dict, domain, domain_sample_ids):
            x_dict = static_x_dict.copy()
            x_dict[domain] = x 

            _, _, output, _ = model(x_dict, edge_index_dict, domain_sample_ids)
            # Aggregate output per sample to a scalar.
            # Here we sum over the class dimension (dim=1); adjust if you need a different reduction; for example just a single class.
            return output.sum(dim=1)


        # Prepare the data dictionaries for node features and edge indices.
        x_dict = {}
        edge_index_dict = {}
        feature_name_dict = {}
        for i, modal in enumerate(new_datasets):
            # find the index of the modal in the self.modalities_name_list
            model_name = modalities_names[i]
            modal_index = self.modalities_name_list.index(model_name)
            feature_name_dict[modal_index] = modal.columns

            dataset = GraphDataset(
                self.neighbor_size,
                modal.values,
                self.fused_networks[modal_index].values,
                transform=T.ToDevice(device),
            )
            modal_dg = dataset[0]

            x_dict[modal_index] = modal_dg.x
            edge_index_dict[modal_index] = modal_dg.edge_index

        # Compute feature importances using IntegratedGradients.
        feat_importances = {}
        for domain in x_dict:
            x_input = x_dict[domain]
            static_x = {k: x_dict[k] for k in x_dict}

            ig = IntegratedGradients(custom_forward)

            attributions, delta = ig.attribute(
                inputs=x_input,
                additional_forward_args=(static_x, edge_index_dict, domain, self.dict_original_order),
                return_convergence_delta=True
            )

            if domain not in feat_importances:
                feat_importances[domain] = []
            feat_importances[domain].append(attributions.detach().cpu().numpy())


        df_list = []
        for domain in feat_importances:

            # Concatenate along the first axis (nodes).
            feat_importances[domain] = np.concatenate(feat_importances[domain], axis=0)
            feature_names = feature_name_dict[domain]
            view_name = self.modalities_name_list[domain]
            #num_feats = feat_importances[domain].shape[1]
            # Aggregate directly from numpy array (take mean to show global importance) and make it n x 1
            feature_importance = np.abs(feat_importances[domain]).mean(axis=0)
            # Create a DataFrame; here columns are named feat_0, feat_1, etc.
            #df = pd.DataFrame(feat_importances[domain], columns=[f'feat_{i}' for i in range(num_feats)])
            temp_df = pd.DataFrame({
                "feature": feature_names,
                "coef": feature_importance,
                "view": view_name,
            })
            df_list.append(temp_df)
        final_df = pd.concat(df_list)
        return final_df