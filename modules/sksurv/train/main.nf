// Nextflow process
// Survival training: fits a scikit-survival model on the train fold.

include { getPublishPath } from "${modulesDir}/functions"

process SKSURV_TRAIN {
	tag "${dataset_name}-${fold_path.name}-${model_name}"
	label 'sksurv'
	label 'process_medium'

	publishDir (
		path: "${params.outdir}/${getPublishPath(task.process)}/${dataset_name}/${fold_path.name}",
		mode: 'copy',
		overwrite: true
	)

	input:
		tuple val(dataset_name), path(data_path), path(fold_path)
		each(model_name)

	output:
		tuple val(dataset_name), val(fold_path.name), val("${model_name}"), path('*model*'),			emit: model
		tuple val(dataset_name), val(fold_path.name), val("${model_name}"), path('*test_data*'),	emit: test_data
		tuple val(dataset_name), val(fold_path.name), val("${model_name}"), path('*log*'),				emit: log

	script:
		def data_label = "${dataset_name}-${fold_path.name}"
		"""
		sksurv_train.py \
				--fold_path=${fold_path} \
				--label=${data_label} \
				--model_name=${model_name}  > \
				${data_label}-${model_name}-${getPublishPath(task.process).tokenize('/')[-1].toLowerCase()}.log
		echo ${data_label} > ${data_label}
		"""

	stub:
		"""
		echo ${dataset_name}
		echo ${data_path}
		echo 'some text' > text.log
		touch prediction.csv
		touch model
		"""
}
