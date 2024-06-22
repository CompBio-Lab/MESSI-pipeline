// Include the parse method process name output dir
include { getPublishPath } from "${modulesDir}/functions"

process DIABLO_PREDICT {
	// Vars stuff
	def onSockeye = workflow.projectDir.toString().contains('/scratch')
	tag "${dataset_name}-${fold_name}-${method}"
	debug true
	label 'process_single'
	container "${ onSockeye  ?
		'codia.sif' :
		'tonyliang19/codia:latest' }"

	publishDir (
		//path: "${params.outdir}/${task.process.tokenize(':')[-1].toLowerCase()}/${dataset_name}/${fold_name}",
		path: "${params.outdir}/${getPublishPath(task.process)}/${dataset_name}/${fold_name}",
		mode: 'copy',
		overwrite: true
	)

	// Labels
	label 'low_mem'
	label 'cpu'
	label 'codia'

	input:
    tuple val(dataset_name), val(fold_name), val(method), path(model)
		tuple val(dataset_name), val(fold_name), val(method), path(test_path)
	output:
    tuple val(dataset_name), val(fold_name), val(method), path("*result*"), emit: result_table
    tuple val(dataset_name), val(fold_name), val(method), path("*weight*"), emit: weight
		path('*log*'), optional: true, emit: log
	script:
		def data_label = "${dataset_name}-${fold_name}-${method}"
		// TODO: very uggly code here ....
		def design = "${method.tokenize('-')[-1]}"
		"""
    predict_diablo.R \
      --model=${model} \
      --test_path=${test_path} \
			--label=${data_label} \
			--design=${design} > \
			${data_label}-${getPublishPath(task.process).tokenize('/')[-1]}.log
		"""
  stub:
    """
    echo ${dataset_name}
    echo ${fold_name}
    echo ${model}
    echo ${test_path}
    """
}