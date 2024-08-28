extract_feats_df <- function(var_list) {
  # Last column is ncomp, so discard that part, hence -1
  # where rest are "selected features" of each view
  n <- length(var_list)
  feat_list <- var_list[1:n - 1]
  # Store the names of views for saving it later
  view_names <- names(feat_list)
  selected_feat_df_list <- lapply(view_names, function(view) {
    # For each omic (which is a list(name, value)), get the value part
    view_feats <- feat_list[[view]]
    view_feats_df <- view_feats$value |> 
      tibble::rownames_to_column(var="feature") |>
      dplyr::mutate(view = view)
    return(view_feats_df)
  })
  
  selected_feat_df <- dplyr::bind_rows(selected_feat_df_list)
  return(selected_feat_df)
}