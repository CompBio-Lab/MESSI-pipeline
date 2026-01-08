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
		mu_data 			// tuple of identifier, path of mu data
		split_type 		// Type of splitting to perform (eg. stratified group k fold (default), leave one group out)
									// The args can be "sgkf" for stratified group k fold or "logo" for leave one group out
	main:
		// TODO: Add some checks inside here and add more verbose
		// log.info("Start to split now with K: ${num_splits}")
		// log.info "Indices are saved into a subfolder called: ${output_dir}"
		// TODO: Add a option to determine when to use seed if pipeline needs to be ran
		//			 several times

		      // TODO: Types of splitting to perform
      // Check for "id" column (non unique) --> LOOCV
      // 1 1 1 1 2 2 ---->

    // Adds a split type arg to denote if using StratifiedGroupKFold (default), or LeaveOneGroupOut
		log.info "Using ${split_type} splitting strategy based on 'sample name' column"


		SPLIT_TRAIN_TEST ( mu_data , split_type, num_splits, output_dir	)
	emit:
		splits_indices 	= SPLIT_TRAIN_TEST.out.splits_indices
		ch_logs					= SPLIT_TRAIN_TEST.out.split_log
}