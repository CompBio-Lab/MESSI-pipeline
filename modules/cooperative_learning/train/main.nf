// Nextflow process
// Author: Tony Liang


// Handles the Cooperative Learning method listed the Reference section of top-level README
// Include the parse method process name output dir
include { getPublishPath } from "${modulesDir}/functions"
process COOPERATIVE_LEARNING_TRAIN {
  // Vars stuff
	tag "${dataset_name}-${fold_path.name}"
	debug	"${params.debug}"
	label 'process_high'
	label 'codia'
	// More special publish dir by getting method/method_abc to method/abc
  publishDir (
    path: "${params.outdir}/${getPublishPath(task.process)}/${dataset_name}/${fold_path.name}",
    mode: 'copy',
    overwrite: true
  )

	// Labels
	label 'low_mem'
	label 'cpu'
	label 'codia'

	// Input, output blocks
	input:
		tuple val(dataset_name), path(mae_path), path(fold_path)
	output:
		tuple val(dataset_name), val(fold_path.name), path('*model.rds'),			 	emit: model
		tuple val(dataset_name), val(fold_path.name), path('*test_data.rds'),	 	emit: test_data
		tuple val(dataset_name), val(fold_path.name), path('*weights.txt'),			emit: weights
		tuple val(dataset_name), val(fold_path.name), path('*log*'), 						emit: log
	// Execution bit
	script:
		def data_label = "${dataset_name}-${fold_path.name}"
		"""
		run_cooperative_learning.R \
				--mae_path=${mae_path} \
				--label=${data_label} \
				--fold_path=${fold_path} > \
				${data_label}-${getPublishPath(task.process).tokenize('/')[-1].toLowerCase()}.log
		"""
	stub:
	"""
	echo ${dataset_name}
	echo ${mae_path}
	echo 'some text' > text.log
	touch prediction.csv
	touch model
	"""
}
