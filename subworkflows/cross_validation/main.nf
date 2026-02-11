
// =================================================================================
// INCLUDE SUBWORKFLOWS (each methos is a subworkflow)
// =================================================================================

include { CV_PYTHON } 					from "${subworkflowDir}/cross_validation/python"
include { CV_R } 								from "${subworkflowDir}/cross_validation/r"
include { MERGE_RESULT_TABLE }	from "${modulesDir}/merge_result_table"
include { printBanner } 				from "${modulesDir}/functions"


// Check if should run any of one language or not run at all (for debug)
// def run_one_lang(params, ch_full_exp) {
// 	if ( params.runR == true ) {
// 		log.info "Running methods in R only"
// 		CV_R ( ch_full_exp.mae_copy )
// 		csv_results = CV_R.out.csv_results
// 	} else if (params.runPython == true ) {
// 		log.info "Running methods in Python only"
// 		CV_PYTHON ( ch_full_exp.mudata_copy )
// 		csv_results = CV_PYTHON.out.csv_results
// 	} else {
// 		log.info "None of the method could be run, check if parameter provided"
// 	}
// 	return(csv_results)
// }

// Function to determine if Python methods should run
def shouldRunPython() {
    return !(
			params.skip_mogonet && 
			params.skip_integrao
		)

}

// Function to determine if R methods should run
def shouldRunR() {
    return !(
        params.skip_cplr && 
        params.skip_diablo && 
        params.skip_mofa &&
        params.skip_rgcca &&
				params.skip_caret_multimodal
    )
}

// Function to determine if all methods should run
def shouldRunAllMethods() {
    return shouldRunPython() && shouldRunR()
}


// Workflow variables to use
def saveMode 	= "language"
def lang 		= "all_langs"
// ============================
// ACTUAL IMPLEMENTATION HERE
// ============================
workflow CROSS_VALIDATION {
	/*
	This is a complex workflow, by training and cross validating at the same time
	Moreover, this is ongoing for all methods, so it would crazily hard to fix
	due to its parallelization
	*/
    // runAllMethods   = params.runAllMethods
    // runPython       = params.runPython
    // runR            = params.runR 
    // inputs of workflow
	take:
		// datasets
		mae_data
		mu_data
		splits_indices

	main:
		// runAllMethods   = params.runAllMethods
    // Determine if should run python or R or both
		runPython       = shouldRunPython()
    runR            = shouldRunR()
		runBothLangs    = runPython && runR

    // Special function to join maps (like hash map)
		// Source: https://github.com/nextflow-io/nextflow/issues/559
		// datasets
		mae_data.join(mu_data, by:0)
						.map { it ->
							[ dataset_name: it[0], mae_path: it[1], mu_path: it[2] ]
						}
						.set { datasets }


		datasets
						.map { it -> [ it.dataset_name, it ] }
            .cross (
                splits_indices        
                    .map { it ->
                        [ dataset_name: it[0], indices: it[1] ]
                    }
                    .map { it -> 
                        [ it.dataset_name, it ] 
                    }
            )
            .map { it[0][1] + it[1][1] }
        // Decouple input datasets into two portions
            .multiMap { it ->
                mae_copy: [it.dataset_name, it.mae_path, it.indices] // So this mae portion along with the indices is used for R only
                mudata_copy: [it.dataset_name, it.mu_path, it.indices] // So this mu portion only along with the indices is used for Python only
            }
            .set { ch_full_exp }

		// ch_full_exp.mae_copy.count().view {"Total is ${it}"}
		// ch_full_exp.mae_copy.view()
		// Note, this cannot be viewed, you need ch_data.mae.view() or ch_data.mu.view()
		// Execute these two (they should be in parallel)
		// Execute language workflows or specific only
		if ( !runBothLangs ) {
			if ( runR ) {
				log.info "Running methods in R only"
				CV_R ( ch_full_exp.mae_copy )
				csv_results = CV_R.out.csv_results
			} 
			else if ( runPython ) {
				log.info "Running methods in Python only"
				CV_PYTHON ( ch_full_exp.mudata_copy )
				csv_results = CV_PYTHON.out.csv_results
			} 
			else {
				log.info "None of the method could be run, check if parameter provided"
			}
		} 
		else {
			log.info "Running all CVs with both R and Python"
			CV_PYTHON ( ch_full_exp.mudata_copy )
			CV_R ( ch_full_exp.mae_copy )
			// Mix results together and set to csv_results
			Channel.empty()
                .mix( CV_PYTHON.out.csv_results )
                .mix( CV_R.out.csv_results )
                .map { it ->
                    [ lang, it[1] ]   // Ch [lang, list of summary table only]
                }
                .groupTuple(by: 0)
                .set { csv_results }
			// Collect all result and mix it to merge it more
			MERGE_RESULT_TABLE ( csv_results, saveMode )
			csv_results = MERGE_RESULT_TABLE.out.csv_results
		}
	emit:
	 	csv_results
}