process CALCULATE_METRICS {
	debug true
	label 'process_single'
	label 'sksurv' // This has generic python , sklearn and sksurv modules
	publishDir (
		path: "${params.outdir}/${task.process.tokenize(':').join('/').toLowerCase()}",
		mode: 'copy',
		overwrite: true
	)
	// Labels
	label 'low_mem'
	// Input output blocks
  input:
    tuple val(method_name), path(result_table)
    val(threshold) // This gets ignored for classification
    val(outcome_type) // One of classification or survival
	output:
		tuple val(method_name), path('*.csv'),  emit: metric_table
		path('*log*'),                          emit: log
	script:
    //def script_name = "calculate_metrics.py" // Execute this script in resources/usr/bin
    if (outcome_type == "classification")
    """
    calculate_classification_metrics.py \
      --result_path=${result_table} \
      --threshold=${threshold} > \
      ${task.process.tokenize(':')[-1].toLowerCase()}.log
    """
    else if (outcome_type == "survival")
    """
    calculate_survival_metrics.py \
	--result_path=${result_table} > \
	${task.process.tokenize(':')[-1].toLowerCase()}.log
    """
    else
    error "Did not implement other outcome types than 'classification' or 'survival'"
}
