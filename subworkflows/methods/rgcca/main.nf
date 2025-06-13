// Include all relevant modules of a method
// TODO: rename method_dir to actual method name dir and value
// TODO: Could replace METHOD by actual name with replace all
def method_dir = "${modulesDir}/rgcca"
include { RGCCA_PREPROCESS }   from "${method_dir}/preprocess"
include { RGCCA_TRAIN }        from "${method_dir}/train"
include { RGCCA_PREDICT }     from "${method_dir}/predict"
// This one could be optional and not implement for now
// so make sure to leave it comment out
// include { METHOD_SELECT_FEATURE }      from "${method_dir}}/select_feature" 
include { MERGE_RESULT_TABLE }  from "${modulesDir}/merge_result_table"

// Workflow related params
// These two are rights params, only need to change value of method_name
//def method_name = "<actual_method_goes_here>"
def saveMode = "method"

workflow RGCCA {
  take:
    // TODO: rename this data_copy to mae_copy or mu_copy depending on language
    mae_copy // ch of tuple dataset, path of mae/mu data, 
            // directories of fold, containing all txts ?
            // TODO: third part is a bit confusing, better description
    ncomp  // Number of component to fit for each block
  main:
    // This if here is just to quickly disable a run of method
    // Run a select feature process only, otherwise treat as cross validation
    // TODO: Could be optional such method dont have it
    /*
    if (params.selectFeature == true) {
      // TODO: This bit sounds very redundant
      // Note this runs preprocess step inside
      METHOD_SELECT_FEATURE ( data_copy )
    } 
    */

    // ======================================================================
    /* 
    1. Go through a specific preprocess step to get data ready for training
      TODO: Need to turn output of this to 'train_input'
    */
        
    RGCCA_PREPROCESS ( mae_copy )
    // Then join the original copy with actual folds after split
    mae_copy.join(  RGCCA_PREPROCESS.out.fold_splits, by:0 )
            .multiMap { it ->
                input_data: [ it[0], it[1] ]              // [dataset_name, mae/mu_data]
                mae_folds:  [ it[0], it[3].flatten() ]   // [fold1, fold2, ... , foldk] 
                                                          // where each fold contains fold_i_tr and fold_i_te data
              }.set{ interm }
    // Transform output of preprocess to one channel input only
    interm.input_data
                  .combine(interm.mae_folds.transpose(), by: 0)
                  .set {  train_input }

    // ======================================================================
    
    /*
      2.  Training for each fold created through previous preprocessed data
          saved as `train_input`. With option of inner cross validation in  
          each  fold data.
    */

    // TODO: implement inner fold cross-validation in each method's train
    /* 
      RGCCA is more special, given this contained various submethods to choose,
      so we need a second channel of list of methods
    */
    ch_methods = Channel.fromList(["rgcca", "sgcca"])
    // These are possible design matrices for the method
    ch_design = Channel.fromList(["full", "null"])
    RGCCA_TRAIN ( train_input, ncomp, ch_methods, ch_design )

    // Do some transformation to make a multiMap that has two branches for predict
    RGCCA_TRAIN.out.model
                .join(RGCCA_TRAIN.out.test_data, by: [0, 1, 2])
                .multiMap { it ->
                  model:      [ it[0], it[1], it[2], it[3] ] // [ dataset_name, fold_name, method, model ]
                  test_data:  [ it[0], it[1], it[2], it[4] ] // [ dataset_name, fold_name, method, test_data]
                }.set { predict_input }
    // ======================================================================
    
    /*
      3. Predict for each fold of data throught their model and get 
      fold specific outupts. With option of inner cross validation in each 
      fold data.
    */

    RGCCA_PREDICT (  
      predict_input.model,
      predict_input.test_data
    )

    // ======================================================================
    
    /* 
      4. Collect results of predicted folds for each data and group dataset
        name.
    */

    // Transform output of the predictions for merging now   
    RGCCA_PREDICT.out.result_table
                  .groupTuple(by: 2)
                  // Get the dataset name and path of these result table only
                  .map {it -> 
                    [ it[2], it[3] ] // Channel of method name and all folds (of all data)
                  }
                  .set { result_table }
    // Lastly merge it, this would be quite fast
    MERGE_RESULT_TABLE ( result_table, saveMode )

  //   // =====================================================================
  // }
  // // And emit the result back to upstream (which is another merge of different method)
  // // sort of like a recursive manner?
    emit:
      csv_results = MERGE_RESULT_TABLE.out.csv_results
      // csv_results = Channel.empty()
}
