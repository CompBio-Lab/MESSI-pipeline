// Include modules to use
include { SPLIT_TRAIN_TEST } 	from "${modulesDir}/split_train_test"
include { printBanner } 			from "${modulesDir}/functions"

// Workflow entrace of splitting data to their indices
workflow SPLITTING {
	// Load params 
	num_splits 		= params.k_fold_number	// value of K fold
	output_dir		=	params.split_dir			// output directory to store the splits , def is "splits"
	// Workflow of splitting starts here
	take:
		// ch_datasets   // tuple of idendifier, path of mae data, path of mu data
		mu_data // tuple of identifier, path of mu data
	main:
		// TODO: Add some checks inside here and add more verbose
		// log.info("Start to split now with K: ${num_splits}")
		// log.info "Indices are saved into a subfolder called: ${output_dir}"
		// TODO: Add a option to determine when to use seed if pipeline needs to be ran
		//			 several times
		SPLIT_TRAIN_TEST ( mu_data , num_splits, output_dir	)
	emit:
		splits_indices 	= SPLIT_TRAIN_TEST.out.splits_indices
		ch_logs					= SPLIT_TRAIN_TEST.out.split_log
}