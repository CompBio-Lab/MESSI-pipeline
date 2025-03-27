// This script is be very similar like the one of cross_validation?
// TODO: update this later

include { printBanner } 				  from "${modulesDir}/functions"
include { COOPERATIVE_LEARNING_SELECT_FEATURE }   from "${modulesDir}/cooperative_learning/select_feature"
include { DIABLO_SELECT_FEATURE }                 from "${modulesDir}/diablo/select_feature"
include { MOGONET_SELECT_FEATURE }                from "${modulesDir}/mogonet/select_feature"
include { RGCCA_SELECT_FEATURE }                  from "${modulesDir}/rgcca/select_feature"
include { SKLEARN_SELECT_FEATURE }                from "${modulesDir}/sklearn/select_feature"
include { MOFA_SELECT_FEATURE }                   from "${modulesDir}/mofa/select_feature"
include { MERGE_SELECTED_FEATURES }               from "${modulesDir}/merge_selected_features"

// Define vars to use later
//def saveMode 	= "language"
//def lang 			= "all_langs"
workflow FEATURE_SELECTION {
  // Params used
  // n_percent     = params.n_percent // N percent of features to be selected for each method
  // Skip or trigger method to run
  skip_cplr     = params.skip_cplr    // boolean: true/false
  skip_diablo   = params.skip_diablo  // boolean: true/false
  skip_rgcca    = params.skip_rgcca   // boolean: true/false
  skip_sgmr     = params.skip_sgmr    // boolean: true/false
  skip_mofa     = params.skip_mofa    // boolean: true/false
	skip_mogonet  = params.skip_mogonet // boolean: true/false
  skip_sklearn  = params.skip_sklearn // boolean: true/false
  // DIABLO param
  diablo_design_connection = params.diablo_design_connection
  // Sklearn param
  sklearn_classifier_names = params.sklearn_classifier_names
  // Require input of workflow
  take:
		// datasets
    mae_data
    mu_data
	main:
		//Special function to join maps (like hash map)
		//Source: https://github.com/nextflow-io/nextflow/issues/559
		printBanner()
    
		
    // Then it should fit the full data for each model and get features selected out from there
    // First make it up as mae portion and mu portion
    // datasets.multiMap{ it ->
    //                 mae_pt:  [dataset_name: it.dataset_name, mae_path: it.mae_path]
    //                 mu_pt:   [dataset_name: it.dataset_name, mu_path: it.mu_path]
    //               }
    //         .set { all_datasets }
    //mae_data.view { "This is mae: $it"}
    /* The ones in R */
   cooperative_learning_features = Channel.empty()
    if (!skip_cplr) {
      COOPERATIVE_LEARNING_SELECT_FEATURE (mae_data)
      cooperative_learning_features = COOPERATIVE_LEARNING_SELECT_FEATURE.out.features
    }

    diablo_features = Channel.empty()
    if (!skip_diablo) {
      // Connection for its design matrix
      ch_design = Channel.fromList( diablo_design_connection )
      DIABLO_SELECT_FEATURE ( mae_data, ch_design)
      diablo_features = DIABLO_SELECT_FEATURE.out.features
    }

    mofa_features = Channel.empty()
    if (!skip_mofa) {
      MOFA_SELECT_FEATURE ( mae_data)
      mofa_features = MOFA_SELECT_FEATURE.out.features
    }

    rgcca_features = Channel.empty()
    if (!skip_rgcca) {
      // RGCCA can use same design matrices like full or null as if in DIABLO
      RGCCA_SELECT_FEATURE (mae_data, ch_design)
      rgcca_features = RGCCA_SELECT_FEATURE.out.features
    }

    /* The ones in Python */
    mogonet_features = Channel.empty()
    if (!skip_mogonet) {
      MOGONET_SELECT_FEATURE (mu_data)
      mogonet_features = MOGONET_SELECT_FEATURE.out.features
    }

    sklearn_features = Channel.empty()
    if (!skip_sklearn) {
      // Classifier from sklearn
      ch_sk_classifiers = Channel.fromList( sklearn_classifier_names )
      SKLEARN_SELECT_FEATURE (mu_data, ch_sk_classifiers)
      sklearn_features = SKLEARN_SELECT_FEATURE.out.features
    }




    /* Lastly collect the features and merge together for downstream usage*/
    Channel.empty()
            .mix( cooperative_learning_features )
            .mix( diablo_features )
            .mix( mogonet_features )
            .mix( mofa_features )
            .mix( rgcca_features )
            .mix( sklearn_features )
            // This is the last step MUST to wait for all previous processes are finished
            .collect()
            //.groupTuple(by: 0)
            //.map { lang, methods, list_csvs -> [lang, list_csvs] } // Ch [R, list of summary table only]
            .set { features_csv }
    // ========================================================================
    // Merge result tables together
    MERGE_SELECTED_FEATURES ( features_csv )
}
