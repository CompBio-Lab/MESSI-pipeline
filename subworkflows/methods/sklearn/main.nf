/* =========================================================================== */
/* 

This is a template workflow for single method, you could implement its own
preprocessing processes, extra argument handlers. These workflow are supposed
to be downstream from the "training" worfklow

Author: Tony Liang
Date: 2024-04-14
*/
/* =========================================================================== */

// Include all relevant modules of a method
// TODO: rename method_dir to actual method name dir and value
// TODO: Could replace  by actual name with replace all
def method_dir = "${modulesDir}/sklearn"
include { SKLEARN_PREPROCESS }   from "${method_dir}/preprocess"
include { SKLEARN_TRAIN }        from "${method_dir}/train"
include { SKLEARN_PREDICT }      from "${method_dir}/predict"
// This one could be optional and not implement for now
// so make sure to leave it comment out
// include { SKLEARN_SELECT_FEATURE }      from "${method_dir}}/select_feature" 
include { MERGE_RESULT_TABLE }  from "${modulesDir}/merge_result_table"

// Workflow related params
// This looks very hard coded, #TODO: improve it later?
// These two are rights params, only need to change value of method_name
def method_name = "sklearn"
def saveMode = "method"


workflow SKLEARN {
  // Classifier to train for sklearn
  model_name  = Channel.fromList(params.sklearn_classifier_names)
  // Reduction method (pca or empty)
  reduction   = Channel.fromList(params.sklearn_reduction)
  take:
  // TODO: rename this data_copy to mae_copy or mu_copy depending on language
  data_copy // ch of tuple dataset, path of mae/mu data, 
          // directories of fold, containing all txts ?
          // TODO: third part is a bit confusing, better description

  main:
    // This if here is just to quickly disable a run of method



      // ======================================================================
      /* 
      1. Go through a specific preprocess step to get data ready for training
        TODO: Need to turn output of this to 'train_input'
      */
          
      SKLEARN_PREPROCESS ( data_copy )
      // Then join the original copy with actual folds after split
      data_copy.join(  SKLEARN_PREPROCESS.out.fold_splits, by:0 )
              .multiMap { it ->
                  input_data: [ it[0], it[1] ]              // [dataset_name, mae/mu_data]
                  // TODO: rename data_folds to mu_folds or mae_folds depending on language
                  data_folds:  [ it[0], it[3].flatten() ]   // [fold1, fold2, ... , foldk] 
                                                            // where each fold contains fold_i_tr and fold_i_te data
                }.set{ interm }
      // Transform output of preprocess to one channel input only
      interm.input_data
                    .combine(interm.data_folds.transpose(), by: 0)
                    .set {  train_input }
      // ======================================================================
      
      /*
        2.  Training for each fold created through previous preprocessed data
            saved as `train_input`. With option of inner cross validation in  
            each  fold data.
      */

      // TODO: implement inner fold cross-validation in each method's train
      SKLEARN_TRAIN ( train_input, reduction, model_name )

      // Do some transformation to make a multiMap that has two branches for predict

      SKLEARN_TRAIN.out.model
                  .join(SKLEARN_TRAIN.out.test_data, by: [0, 1, 2])
                  .multiMap { it ->
                    model:      [ it[0], it[1], it[2], it[3] ] // [ dataset_name, fold_name, model_name, model ]
                    test_data:  [ it[0], it[1], it[2], it[4] ] // [ dataset_name, fold_name, model_name, test_data]
                    //metadata:   [ it[0], it[1], it[4] ] // [ dataset_anme, fold_name, metadata_path]
                  }.set { predict_input }
      // ======================================================================
      
      /*
        3. Predict for each fold of data throught their model and get 
        fold specific outupts. With option of inner cross validation in each 
        fold data.
      */

      SKLEARN_PREDICT (  
        predict_input.model,
        predict_input.test_data,
        Channel.value(method_name)
        )

      // ======================================================================
      
      /* 
        4. Collect results of predicted folds for each data and group dataset
          name.
      */

      // Transform output of the predictions for merging now   
      SKLEARN_PREDICT.out.result_table
                    .groupTuple(by: 2)
                    // Get the dataset name and path of these result table only
                    .map {it -> 
                      [ it[2], it[3] ] // Channel of method name and all folds (of all data)
                    }
                    .set { result_table }
      // Lastly merge it, this would be quite fast
      MERGE_RESULT_TABLE ( result_table, saveMode )

      // =====================================================================
      // And emit the result back to upstream (which is another merge of different method)
      // sort of like a recursive manner?
    emit:
      csv_results = MERGE_RESULT_TABLE.out.csv_results
}
