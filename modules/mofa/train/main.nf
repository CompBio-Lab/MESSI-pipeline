// Nextflow process
// Author: Tony Liang


// Handles the MOFA method listed the Reference section of top-level README
include { getPublishPath } from "${modulesDir}/functions"
process MOFA_TRAIN {
	// Vars stuff
	tag "${dataset_name}-${fold_path.name}"
	//debug	"${params.debug}"
	debug true
	label 'process_medium'
	label 'mofa'
	// Parse this path
	publishDir (
		path: "${params.outdir}/${getPublishPath(task.process)}/${dataset_name}/${fold_path.name}",
		mode: 'copy',
		overwrite: true
	)

	// Labels
	label 'low_mem'
	label 'cpu'

	input:
		tuple val(dataset_name), path(mae_path), path(fold_path)
    val(run_inner_cv)
	output:
		tuple val(dataset_name), val(fold_path.name), path('*model.rds'),    	emit: model
    tuple val(dataset_name), val(fold_path.name), path('*test_data.rds'),	emit: test_data
    tuple val(dataset_name), val(fold_path.name), path('*log*'), 					emit: log
	script:
		def data_label = "${dataset_name}-${fold_path.name}"
    if (run_inner_cv)
      """
      run_mofa.R \
        --mae_path=${mae_path} \
        --label=${data_label} \
        --fold_path=${fold_path} \
        --run_inner_cv > \
        ${data_label}-${getPublishPath(task.process).tokenize('/')[-1].toLowerCase()}.log
      echo ${dataset_name} > dataset_name
      """
    else
    """
      run_mofa.R \
        --mae_path=${mae_path} \
        --label=${data_label} \
        --fold_path=${fold_path} > \
        ${data_label}-${getPublishPath(task.process).tokenize('/')[-1].toLowerCase()}.log
      echo ${dataset_name} > dataset_name
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