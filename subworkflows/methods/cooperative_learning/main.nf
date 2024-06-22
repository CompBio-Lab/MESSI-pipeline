// Include all relevant modules of cooperative learning
def cplr_dir = "${modulesDir}/cooperative_learning"
include { COOPERATIVE_LEARNING_PREPROCESS }     from "${cplr_dir}/preprocess"
include { COOPERATIVE_LEARNING_TRAIN }          from "${cplr_dir}/train"
include { COOPERATIVE_LEARNING_PREDICT }        from "${cplr_dir}/predict"
include { COOPERATIVE_LEARNING_SELECT_FEATURE } from "${cplr_dir}/select_feature"
include { MERGE_RESULT_TABLE }                  from "${modulesDir}/merge_result_table"


// Workflow related params
params.runCPLR = true
// This looks very hard coded, #TODO: improve it later?
def method_name = "cooperative_learning"
def saveMode = "method"

workflow COOPERATIVE_LEARNING {
  take:
    mae_copy // ch of tuple dataset, path of mae data, directories of fold, containing all txts
  main:
    log.info "Starting Cooperative Learning workflow"

    // Run a select feature process only, otherwise treat as cross validation
    // if (params.selectFeature == true) {
    //   // TODO: This bit sounds very redundant
    //   // Note this runs preprocess step inside
    //   COOPERATIVE_LEARNING_SELECT_FEATURE ( mae_copy )
    // } 
    /*
    1. Go through a specific preprocess step to get data ready for training

    TODO: Need to turn output of this to 'train_input'
    */
    COOPERATIVE_LEARNING_PREPROCESS ( mae_copy )
    mae_copy.join(COOPERATIVE_LEARNING_PREPROCESS.out.fold_splits, by: 0)
            .multiMap { it ->
              input_data: [ it[0], it[1] ] // [dataset_name, mae_data]
              mae_folds:  [ it[0], it[3].flatten()] // [fold1, fold2, ... , foldk] where each fold contains fold_i_tr and fold_i_te data
            }.set { interm }
    
          
    // Transform output of preprocess to one channel input only
    interm.input_data
          .combine(interm.mae_folds.transpose(), by: 0)
          .set { train_input }
    /*
    2. Training for each fold created through previous preprocessed data
    */

    COOPERATIVE_LEARNING_TRAIN ( train_input )
    // Do some transformation to make a multiMap that has two branches for predict
    COOPERATIVE_LEARNING_TRAIN.out.model
                              .join(COOPERATIVE_LEARNING_TRAIN.out.test_data, by: [0, 1])
                              .multiMap { it ->
                                model:      [ it[0], it[1], it[2] ] // [ GSExxx, fold_name, model ]
                                test_data:  [ it[0], it[1], it[3] ] // [ GSExxx, fold_name, test_data]
                              }.set { predict_input } 

    /*
    3. Predict for each fold of data throught their model and get fold specific outupts
    */

    COOPERATIVE_LEARNING_PREDICT ( predict_input.model,
              predict_input.test_data,
              Channel.value(method_name)
    )
    /* 
    4. Collect results of predicted folds for each data and group by GSE dataset name
    */
    
    COOPERATIVE_LEARNING_PREDICT.out.result_table
              .groupTuple(by: 2)
              // Get the datasetname and path of these result table only
              .map {it -> 
                [ it[2], it[3] ] // Channel of method name and all folds (of all data)
              }
              .set { result_tables }
    // Run these by batch of result tables (K tables per data)
    // result_tables.view()  
    MERGE_RESULT_TABLE ( result_tables, saveMode )
  emit:
    csv_results = MERGE_RESULT_TABLE.out.csv_results
}
