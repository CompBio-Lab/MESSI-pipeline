process CALCULATE_METRICS {
  def onSockeye = workflow.projectDir.toString().contains('/scratch')
	debug true
	label 'process_single'
	container "${ onSockeye  ?
		'codia.sif' :
		'tonyliang19/codia:latest' }"

	publishDir (
		path: "${params.outdir}/${task.process.tokenize(':').join('/').toLowerCase()}",
		mode: 'copy',
		overwrite: true
	)
	// Labels
	label 'low_mem'
	label 'cpu'
	label 'codia'
	// Input output blocks
  input:
    tuple val(method_name), path(result_table)
    val(threshold)
	output:
		tuple val(method_name), path('*.csv'),  emit: metric_table
		path('*log*'),                          emit: log
	script:
    def script_name = "calculate_metrics.R" // Execute this script in resources/usr/bin
    """
    ${script_name} \
      --result_path=${result_table} \
      --threshold=${threshold} > \
      ${task.process.tokenize(':')[-1].toLowerCase()}.log
    """
}