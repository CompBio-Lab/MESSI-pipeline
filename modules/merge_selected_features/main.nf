process MERGE_SELECTED_FEATURES {
	//tag "${method_name}"
	debug true
	label 'process_single'
	label 'codia'

	publishDir (
		//path: "${params.outdir}/${task.process.tokenize(':')[-1].toLowerCase()}/${method_name}",
		// path: "${params.outdir}/${task.process.tokenize(':').join('/').toLowerCase()}",
    path: "${params.outdir}/${task.process.tokenize(':')[-1].toLowerCase()}",
		mode: 'copy',
		overwrite: true
	)
	// Input output blocks
  input:
    path(list_result_tables)
	output:
		// TODO: fix bad naming here of emitting channels
		path('all_feature_selection_results.csv'), optional: true, emit: csv_results
		path('relevant_feature_selection_results.csv'),   optional: true, emit: relevant_csv_results
		path('*log*'),  optional: true, emit: log
	script:
    // This script assumes to read in list of files
    // The "${variable}" or ${variable.join(' ')} does the trick to make it one whole string
		// Different branch to call different script under resources/usr/bin to merge and collect results
		"""
		merge_selected_features.R \
			--tables="${list_result_tables}" > \
			${task.process.tokenize(':')[-1].toLowerCase()}.log
    """
	}