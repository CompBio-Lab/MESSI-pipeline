// Include the parse method process name output dir
include { getPublishPath } from "${modulesDir}/functions"

process MOFA_PREDICT {
	// Vars stuff
	def onSockeye = workflow.projectDir.toString().contains('/scratch')
	tag "${dataset_name}-${fold_name}"
	debug true
	label 'process_single'
	container "${ onSockeye  ?
		'mofa.sif' :
		'tonyliang19/mofa:latest' }"

	publishDir (
		path: "${params.outdir}/${getPublishPath(task.process)}/${dataset_name}/${fold_name}",
		mode: 'copy',
		overwrite: true
	)

	// Labels
	label 'low_mem'
	label 'cpu'

	input:
    tuple val(dataset_name), val(fold_name), path(model)
		tuple val(dataset_name), val(fold_name), path(test_path)
	output:
    tuple val(dataset_name), val(fold_name), val("mofa"), path("*result*"), emit: result_table
    //tuple val(dataset_name), val(fold_name), val("mofa"), path("*weight*"), emit: weight
		path('*log*'), optional: true, emit: log
	script:
		def data_label = "${dataset_name}-${fold_name}"
		"""
    predict_mofa.R \
      --model=${model} \
      --test_path=${test_path} \
			--label=${data_label} > \
			${data_label}-${getPublishPath(task.process).tokenize('/')[-1]}.log

		echo mofa > method_name
		"""
  stub:
    """
    echo ${dataset_name}
    echo ${fold_name}
    echo ${model}
    echo ${test_path}
    """
}