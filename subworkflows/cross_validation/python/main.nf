// Methods to include
include { SKLEARN } from "${subworkflowDir}/methods/sklearn"
include { MOGONET } 						from "${subworkflowDir}/methods/mogonet"
include { GOAT } 								from "${subworkflowDir}/methods/goat"
// This module to collect results
include { MERGE_RESULT_TABLE }  from "${modulesDir}/merge_result_table"
// Helper fun
include { printBanner } 				from "${modulesDir}/functions"


// Workflow specific params to use
def language_name = "Python"
def saveMode = "language"

workflow CV_PYTHON {
  // Skip or trigger method to run
  skip_sklearn  = params.skip_sklearn // boolean: true/false
  skip_mogonet	= params.skip_mogonet	// boolean: true/false
  skip_goat 		= params.skip_goat		// boolean: true/false
  take:
    mu_copy 	//  channel of (key, key/path_to_mu, split_indices), 
              // where each split_indices/ contains
              // list of txt files.
  main:
    printBanner()
    log.info("This is the training python")
    /*
      Need to first allocate empty output for each of the methods
      TODO: need a smarter way to do it
    */

    // Instantiation of method subworkflows
    // SKLEARN
    sklearn_results = Channel.empty()
    if (!skip_sklearn) {
        SKLEARN ( mu_copy )
        sklearn_results = SKLEARN.out.csv_results
    }
    
    // MOGONET
    mogonet_results = Channel.empty()
    if (!skip_mogonet) {
      MOGONET ( mu_copy )
      mogonet_results = MOGONET.out.csv_results
    }

    // GOAT
    goat_results = Channel.empty()
    if (!skip_goat) {
      GOAT ( mu_copy )
      goat_results = GOAT.out.csv_results
    }

    // ======================================================================== 
    // Collect all result and mix it to merge it more
    Channel.empty()
            // Then these are outputs of methods
            .mix( sklearn_results )
            .mix( mogonet_results )
            .mix( goat_results )
            .map { it ->
              [ language_name, it[0], it[1] ]  // Ch [R, method name, path of summary csv of method]
            }
            .groupTuple(by: 0)
            .map { lang, methods, list_csvs -> [lang, list_csvs]} // Ch [R, list of summary table only]
            .set { csv_results }
    // ======================================================================== 
    // Merge result tables together
    MERGE_RESULT_TABLE ( csv_results, saveMode )
  emit:
    csv_results = MERGE_RESULT_TABLE.out.csv_results
}