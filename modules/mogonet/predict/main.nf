// Include the parse method process name output dir
include { getPublishPath } from "${modulesDir}/functions"
process MOGONET_PREDICT {
	// Vars stuff
	def onSockeye = workflow.projectDir.toString().contains('/scratch')
	tag "${dataset_name}-${fold_name}"
	debug true
	label 'process_low'
	container "${ onSockeye  ?
		'mogonet.sif' :
		'tonyliang19/mogonet:latest' }"

	publishDir (
		path: "${params.outdir}/${getPublishPath(task.process)}/${dataset_name}/${fold_name}",
		mode: 'copy',
		overwrite: true
	)

	// Labels
	label 'low_mem'
	label 'gpu'
  label 'mogonet'

	input:
    tuple val(dataset_name), val(fold_name), path(model)
		tuple val(dataset_name), val(fold_name), path(test_path)
		tuple val(dataset_name), val(fold_name), path(metadata_path)
    val(method_name)
	output:
    tuple val(dataset_name), val(fold_name), val(method_name), path("*result*"), emit: result_table
		path('*log*'), optional: true, emit: log
	script:
		def data_label = "${dataset_name}-${fold_name}"
		"""
    predict_mogonet.py \
      --model=${model} \
      --test_path=${test_path} \
			--metadata_path=${metadata_path} \
			--label=${data_label} \
      --method_name=${method_name} > \
      ${data_label}-${getPublishPath(task.process).tokenize('/')[-1]}.log

		echo ${method_name} > method_name
		"""
  stub:
    """
    echo ${dataset_name}
    echo ${fold_name}
    echo ${model}
    echo ${test_path}
    """
}