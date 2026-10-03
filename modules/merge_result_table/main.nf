process MERGE_RESULT_TABLE {
        tag "${method_name}"
        debug true
        label 'process_single'
        label 'codia'

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
                val(outcome_type)
	output:
					tuple val(method_name), path('*.csv'),  optional: true, emit: csv_results
					path('*log*'), optional: true, emit: log

	script:
	def file_list =  list_result_tables.collect { it.toString().replace("'", "'\"'\"'") }.join('\n')



	// Different branch to call different script under resources/usr/bin to merge and collect results
	if (saveMode == "method")
									"""
									printf '%s\\n' '${file_list}' > input_files.txt
									combine_tables.R \
													--input_list=input_files.txt \
													--outcome_type=${outcome_type} \
													--method_name=${method_name} \
													--methodMode > \
													${method_name}-${task.process.tokenize(':')[-1].toLowerCase()}.log
									"""
	else if (saveMode == "language")
									"""
									printf '%s\\n' '${file_list}' > input_files.txt
									combine_tables.R \
													--input_list=input_files.txt \
													--outcome_type=${outcome_type} \
													--method_name=${method_name} > \
													${method_name}-${task.process.tokenize(':')[-1].toLowerCase()}.log
									"""
	else
									error "Did not provide save mode to be language or method"
	}
