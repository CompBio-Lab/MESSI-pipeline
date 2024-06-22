// Include mofa's modules
def mofa_dir = "${modulesDir}/mofa"
include { MOFA_PREDICT }          from "${mofa_dir}/predict"
include { MOFA_TRAIN }            from "${mofa_dir}/train"
include { MOFA_PREPROCESS }       from "${mofa_dir}/preprocess"
// include { MOFA_DOWNSTREAM }       from "${mofa_dir}/downstream"
include { MERGE_RESULT_TABLE }    from "${modulesDir}/merge_result_table"

def saveMode = "method"
workflow MOFA {
  runInnerCV = params.runInnerCV
  take:
    mae_copy // ch of tuple dataset, path of mae data, directories of fold, containing all txts
  main:
    // Might have some preprocessing steps
    log.info "Starting MOFA workflow"    
    /*
    ===========================================================================
          Calls this to preprocess and prepare input for mofa
    ===========================================================================
    */
    if ( params.runDownstreamAnalysis ) {
      // log.info "Running downstream analysis with MOFA"
      log.info "Not implemented the downstream analysis for MOFA"
      // MOFA_DOWNSTREAM ( mae_copy )
    }
    
    MOFA_PREPROCESS ( mae_copy )

    /*
    ==========================================================================
      Cross Validate it, with inner CV loops that finds optimal parameter
    ==========================================================================
    */
    mae_copy.join(MOFA_PREPROCESS.out.fold_splits, by:0)
            .multiMap { it ->
                input_data: [ it[0], it[1] ] // [dataset_name, mae_data]
                mae_folds: [it[0], it[3].flatten()] // [fold1, fold2, ... , foldk] where each fold contains fold_i_tr and fold_i_te data
              }.set{ interm }
    // Note for multimap you can only do some.br1.view() or some.br2.view() and not some.view()
    // Try something here to separate input in two branch
    // As each tuple do not work, use combine instead
    // Source: https://github.com/nextflow-io/nextflow/issues/1531
    interm.input_data
                .combine(interm.mae_folds.transpose(), by: 0)
                .set {  train_input }

    /*
    =========================================================================
                    COMPUTATIONAL INTENSIVE BLOCK goes here
    =========================================================================
    */

    // As mentioned, there's a possible run inner cv option
    // runInnerCV: boolean, true or false
    MOFA_TRAIN( train_input, runInnerCV )
    // Transform certain outputs here to use in prediction
    // Join outputs from trained models and prepare for prediction
    MOFA_TRAIN.out.model
        .join(MOFA_TRAIN.out.test_data, by: [0,1])
        .multiMap { it ->
          model:      [ it[0], it[1], it[2] ] // [ GSExxx, fold_name, model ]
          test_data:  [ it[0], it[1], it[3] ] // [ GSExxx, fold_name, test_data]
        }.set { predict_input } 

    // Predict each fold with their corresponding model and test data within fold                       
    MOFA_PREDICT (
      predict_input.model,
      predict_input.test_data
    )

    // Collect results of predicted folds for each data and group by GSE dataset name
    MOFA_PREDICT.out.result_table
            .groupTuple(by: 2)
            // Get the datasetname and path of these result table only
            .map {it -> 
            [ it[2], it[3] ] // Channel of method name and all folds (of all data)
            }
            .set { result_tables }
    // Run these by batch of result tables (K tables per data)
    //result_tables.view()
    
    MERGE_RESULT_TABLE ( result_tables, saveMode )
    // After ran the training part, we should validate it
    emit:
      csv_results = MERGE_RESULT_TABLE.out.csv_results
}