// Include the parse method process name output dir
include { getPublishPath } from "${modulesDir}/functions"
process COOPERATIVE_LEARNING_PREDICT {
	// Vars stuff
	tag "${dataset_name}-${fold_name}"
	debug true
	label 'process_single'
	label 'codia'

	publishDir (
		path: "${params.outdir}/${getPublishPath(task.process)}/${dataset_name}/${fold_name}",
		mode: 'copy',
		overwrite: true
	)

	// Labels
	label 'low_mem'
	label 'cpu'
	label 'codia'

	input:
    tuple val(dataset_name), val(fold_name), path(model)
		tuple val(dataset_name), val(fold_name), path(test_path)
    val(method_name)
	output:
    tuple val(dataset_name), val(fold_name), val(method_name), path("*result*"), emit: result_table
		path('*log*'), optional: true, emit: log
	script:
		def data_label = "${dataset_name}-${fold_name}"
		"""
    predict_cooperative_learning.R \
      --model=${model} \
      --test_path=${test_path} \
			--label=${data_label} \
      --method_name=${method_name} > \
      ${data_label}-${getPublishPath(task.process).tokenize('/')[-1]}.log

		echo diablo > method_name
		"""
  stub:
    """
    echo ${dataset_name}
    echo ${fold_name}
    echo ${model}
    echo ${test_path}
    """
}