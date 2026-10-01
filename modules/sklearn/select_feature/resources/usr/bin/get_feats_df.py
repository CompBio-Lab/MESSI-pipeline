import pandas as pd
import warnings


# Use this fun to extract coefficients or feature importance
# from sklearn classifiers
def get_feats_df(classifier, feat_names, model_name, dataset_name, modality_names):
    columns = ["feature", "view", "coef", "method", "dataset_name"]

    # MLP has no native per-feature importance
    if model_name.lower() == "mlp":
        warnings.warn(
            f"{dataset_name}/{model_name}: native feature importance "
            "is unavailable; writing a header-only feature CSV."
        )
        feats_df = pd.DataFrame(columns=columns)
        return feats_df

    # Init importance value
    importance = None
    # Check the type of classifier and extract feature importance accordingly
    if hasattr(classifier, 'coef_'):
        # For linear models
        feature_importance = classifier.coef_
        importance = feature_importance.flatten()
    if hasattr(classifier, 'feature_importances_'):
        # For tree-based models
        importance = classifier.feature_importances_
    # Create a DataFrame for feature importance if importance is available
    if importance is None:
        raise ValueError(f"Importance was not present for '{model_name}' at '{dataset_name}'")    

    # Initialize dataframe to store this info
    feats_df = pd.DataFrame({
        'feature': feat_names,
        'coef': importance
    })
    
    # Map features to their corresponding omics
    #feats_df['view'] = feats_df['feature'].apply(lambda x: '_'.join(x.split('_')[:-1]))
    feats_df['view'] = feats_df['feature'].apply(
        lambda feature: next((view for view in modality_names if view in feature), None)
    )
    # Add metadata info for downstream usage
    feats_df['dataset_name'] = dataset_name
    # Prepend sklearn-model_name for readability
    model_lower = model_name.lower().replace(" ", "_")
    feats_df['method'] = f"sklearn-{model_lower}"
    # Lastly alter it to right order and matching columns
    # Arrange columns in the expected output order
    try:
        feats_df = feats_df[columns]
    except KeyError as e:
        print(f"Sklearn select feature for '{dataset_name}', '{model_lower}' column not found: {e}")
    return feats_df