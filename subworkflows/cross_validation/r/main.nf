// Methods to include
include { COOPERATIVE_LEARNING }  from "${subworkflowDir}/methods/cooperative_learning"
include { DIABLO }                from "${subworkflowDir}/methods/diablo"
include { MOFA }                  from "${subworkflowDir}/methods/mofa"
include { RGCCA }                 from "${subworkflowDir}/methods/rgcca"
include { SGMR }	                from "${subworkflowDir}/methods/sgmr"
// This module to collect results
include { MERGE_RESULT_TABLE }    from "${modulesDir}/merge_result_table"



params.full_mode = false
def language_name = "R"
def saveMode = "language"
workflow CV_R {
  // Skip or trigger method to run
  skip_diablo = params.skip_diablo  // boolean: true/false
  skip_rgcca  = params.skip_rgcca   // boolean: true/false
  skip_sgmr   = params.skip_sgmr    // boolean: true/false
  skip_mofa   = params.skip_mofa    // boolean: true/false
  take:
    mae_copy 	//  channel of (key, key/path_to_mae, split_indices),
              // 	where each split_indices/ contains
              // 	list of txt files.
  main:
    printBanner()
    // ========================================================================
    /*
    Notice every method here is considered as a workflow of preprocessing and 
    cross validating steps
    */

    /*
      Also need to allocate these "null" results first in order to implement
      skipping
      TODO: find a better way to do this
    */

    // Instantiation of method subworkflows

    // Cooperative Learning
    cooperative_learning_results = Channel.empty()
    if (!skip_cplr) {
      COOPERATIVE_LEARNING ( mae_copy )
      cooperative_learning_results = COOPERATIVE_LEARNING.out.csv_results
    }
    // DIABLO
    diablo_results = Channel.empty()
    if (!skip_diablo) {
      DIABLO ( mae_copy )
      diablo_results = DIABLO.out.csv_results
    }

    // MOFA
    mofa_results = Channel.empty()
    if (!skip_mofa) {
      MOFA ( mae_copy )
      mofa_results = MOFA.out.csv_results
    }

    // RGCCA
    rgcca_results = Channel.empty()
    if (!skip_rgcca) {
      RGCCA ( mae_copy )
      rgcca_results = RGCCA.out.csv_results
    }
    

    // SGMR TODO: THIS IS NOT IMPLEMENTED
    sgmr_results = Channel.empty()
    if (!skip_sgmr) {
      SGMR ( mae_copy )
      sgmr_results = SGMR.out.csv_results
    }

    // ========================================================================  
    // Collect all result and mix it to merge it more
    Channel.empty()
            .mix( cooperative_learning_results )
            .mix( diablo_results )
            .mix( mofa_results )
            .mix( rgcca_results )
            .mix( sgmr_results )
            .map { it ->
              [ language_name, it[0], it[1] ]  // Ch [R, method name, path of summary csv of method]
            }
            .groupTuple(by: 0)
            .map { lang, methods, list_csvs -> [lang, list_csvs] } // Ch [R, list of summary table only]
            .set { csv_results }
    // ========================================================================
    // Merge result tables together
    MERGE_RESULT_TABLE ( csv_results, saveMode )
  emit:
    csv_results = MERGE_RESULT_TABLE.out.csv_results
}