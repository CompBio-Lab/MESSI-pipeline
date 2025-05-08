// Include diablo's modules
def diablo_dir = "${modulesDir}/diablo"
include { DIABLO_PREDICT }          from "${diablo_dir}/predict"
include { DIABLO_TRAIN }            from "${diablo_dir}/train"
include { DIABLO_PREPROCESS }       from "${diablo_dir}/preprocess"
include { DIABLO_DOWNSTREAM }       from "${diablo_dir}/downstream"
include { MERGE_RESULT_TABLE }      from "${modulesDir}/merge_result_table"

def saveMode = "method"
workflow DIABLO {
  runInnerCV = params.runInnerCV
  design     = params.diablo_design_connection
  take:
    mae_copy // ch of tuple dataset, path of mae data, directories of fold, containing all txts
    ncomp    // Number of components to run for DIABLO
  main:
    // Might have some preprocessing steps
    log.info "Starting DIABLO workflow"    
    /*
    ===========================================================================
          Calls this to preprocess and prepare input for diablo
    ===========================================================================
    */
    if ( params.runDownstreamAnalysis ) {
      log.info "Running downstream analysis with DIABLO"
      DIABLO_DOWNSTREAM ( mae_copy )
    }
    
    DIABLO_PREPROCESS ( mae_copy )

    /*
    ==========================================================================
      Cross Validate it, with inner CV loops that finds optimal parameter
    ==========================================================================
    */
    mae_copy.join(DIABLO_PREPROCESS.out.fold_splits, by:0)
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
    // These are possible design matrices for the method
    ch_design = Channel.fromList( design )
    DIABLO_TRAIN( train_input, runInnerCV, ncomp, ch_design )
    // Transform certain outputs here to use in prediction
    // Join outputs from trained models and prepare for prediction
    DIABLO_TRAIN.out.model
        .join(DIABLO_TRAIN.out.test_data, by: [0,1, 2])
        .multiMap { it ->
          model:      [ it[0], it[1], it[2], it[3] ] // [ dataset_name, fold_name, design, model ]
          test_data:  [ it[0], it[1], it[2], it[4] ] // [ dataset_name, fold_name, design, test_data]
        }.set { predict_input } 

    // Predict each fold with their corresponding model and test data within fold                       
    DIABLO_PREDICT (
      predict_input.model,
      predict_input.test_data
    )

    // Collect results of predicted folds for each data and group by GSE dataset name
    DIABLO_PREDICT.out.result_table
            .groupTuple(by: 2)
            // Get the dataset name and path of these result table only
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