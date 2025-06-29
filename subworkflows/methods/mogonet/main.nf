// Include mogonet's modules
def mogo_dir = "$modulesDir/mogonet"
include { MOGONET_PREPROCESS }  from "${mogo_dir}/preprocess"
include { MOGONET_TRAIN }       from "${mogo_dir}/train"
include { MOGONET_PREDICT }     from "${mogo_dir}/predict"
include { MERGE_RESULT_TABLE }  from "${modulesDir}/merge_result_table"
// Workflow related params
params.runMogonet = true
// This looks very hard coded, #TODO: improve it later?
def method_name = "mogonet"
def saveMode    = "method"
def override    = "yes"


/*
TODO: todo items goes here
  - Need to check number of omics in a dataset is at least >= 3
  - Need to find way to update model dict (it doesnt change after initialization)
*/



workflow MOGONET {
  take:
    mu_copy 	//  channel of (key, key/path_to_mu, split_indices), 
							// where each split_indices/ contains
							// list of txt files.
    he_base_dim // base dimension for the HE layer, default is 2 for real data, 1 for sim data
  main:
    // Might have some preprocessing steps
    /*
      1. Go through a specific preprocess step to get data ready for training

      TODO: Need to turn output of this to 'train_input'
    */

    /*
    ===========================================================================
              Preprocess and prepare inputs required for MOGONET
    ===========================================================================
    */    

    // Little bit special for mogonet, so we dont need the mudata here anymore
    // but instead the preprocessed format for mogonet0
    MOGONET_PREPROCESS ( mu_copy ) // Calls this process to
    mu_copy.join(MOGONET_PREPROCESS.out.fold_splits, by: 0)
            .map { it ->
              mu_folds:  [ it[0], it[3].flatten() ] // [fold1, fold2, ... , foldk] where each fold contains fold_i_tr and fold_i_te data
            }
            .transpose()
            .set { train_input }
    
    // Transform output of preprocess to one channel input only
    // interm.input_data
    //       .combine(interm.mu_folds.transpose(), by: 0)
    //       .set { train_input }      
    /*
    ===========================================================================
    Cross validation with MOGONET
    ===========================================================================
    */    
    
    // Training stepp
    MOGONET_TRAIN ( train_input, he_base_dim )
    // Predicting step
    MOGONET_PREDICT (
      MOGONET_TRAIN.out.model,
      MOGONET_TRAIN.out.test_data,
      MOGONET_TRAIN.out.metadata,
      Channel.value(method_name)
    )

    MOGONET_PREDICT.out.result_table
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
    // Uncomment this bit below and comment above to debug
    // csv_results = Channel.empty()
}

/*
Unused code
    //ch_txt.transpose().groupTuple( by: 0 )
    //      .flatMap { sample, list -> list.collate(3).collect { [ sample, it ]}}.view()
    

*/