process MERGE_RESULT_TABLE {
  def onSockeye = workflow.projectDir.toString().contains('/scratch')
	tag "${method_name}"
	debug true
	label 'process_single'
	container "${ onSockeye  ?
		'codia.sif' :
		'tonyliang19/codia:latest' }"

	publishDir (
		//path: "${params.outdir}/${task.process.tokenize(':')[-1].toLowerCase()}/${method_name}",
		path: "${params.outdir}/${task.process.tokenize(':').join('/').toLowerCase()}",
		mode: 'copy',
		overwrite: true
	)

	// Input output blocks
  input:
    tuple val(method_name), path(list_result_tables)
		val(saveMode)
	output:
		tuple val(method_name), path('*.csv'), 	optional: true, emit: csv_results
		tuple val(method_name), path('*.txt'), 	optional: true, emit: txt_results
		path('*log*'), optional: true, emit: log
	script:
    // This script assumes to read in list of files
    // The "${variable}" or ${variable.join(' ')} does the trick to make it one whole string
		// Different branch to call different script under resources/usr/bin to merge and collect results
		if (saveMode == "method") 
			"""
			combine_tables.R \
				--tables="${list_result_tables}" \
				--method_name=${method_name} \
				--methodMode > \
				${method_name}-${task.process.tokenize(':')[-1].toLowerCase()}.log
			"""
		else if (saveMode == "language")
			"""
			combine_tables.R \
				--tables="${list_result_tables}" \
				--method_name=${method_name} > \
				${method_name}-${task.process.tokenize(':')[-1].toLowerCase()}.log
			"""
		else
			error "Did not provide save mode to be language or method"
	}