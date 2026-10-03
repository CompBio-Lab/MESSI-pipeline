// Include the parse method process name output dir
include { getPublishPath } from "${modulesDir}/functions"

process SKSURV_PREDICT {
	tag "${dataset_name}-${fold_name}-${model_name}"
	debug "${params.debug}"
	label 'sksurv'

	publishDir (
		path: "${params.outdir}/${getPublishPath(task.process)}/${dataset_name}/${fold_name}/${model_name}",
		mode: 'copy',
		overwrite: true
	)

	label 'process_low'

	input:
    tuple val(dataset_name), val(fold_name), val(model_name), path(model_path)
		tuple val(dataset_name), val(fold_name), val(model_name), path(test_path)
    val(method_name)

  output:
    tuple val(dataset_name), val(fold_name), val(method_name), path("*result*"),  emit: result_table
		tuple val(dataset_name), val(fold_name), val(method_name), path('*log*'),     emit: log

  script:
		def data_label = "${dataset_name}-${fold_name}"
		"""
    sksurv_predict.py \
      --model_path=${model_path} \
      --test_path=${test_path} \
			--label=${data_label} \
      --method_name=${method_name}-${model_name} > \
			${data_label}-${model_name}-${getPublishPath(task.process).tokenize('/')[-1]}.log
		"""
  stub:
    """
    echo ${dataset_name}
    echo ${fold_name}
    echo ${model_path}
    echo ${test_path}
    """
}
