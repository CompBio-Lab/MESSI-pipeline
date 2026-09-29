// Nextflow process
// Author: Tony Liang


// Handles the   listed the Reference section of top-level README
/*
  You could have scripts that proces takes under this structure:
    - method/resources/usr/bin/script1.py
    - method/resources/usr/bin/script2.R
    - And so on
  This process is supposed be triggered from the subworkflow level of the method
  see templates/method_subworkflow.nf

  Author: Tony Liang
*/

include { getPublishPath } from "${modulesDir}/functions"

process SKLEARN_TRAIN {
	// Vars stuff
	// Identifier for each dataset and fold combination
	tag "${dataset_name}-${fold_path.name}-${model_name}"
	// TODO: rename to the actual image name used
	label 'sklearn'
	// Parse the output directory to migrate results to
	publishDir (
		path: "${params.outdir}/${getPublishPath(task.process)}/${dataset_name}/${fold_path.name}",
		mode: 'copy', 
		overwrite: true
	)
	// TODO: add your custom labels to tell if process
	// consumes large RAM/ROM and gpu access or not
	label 'process_medium'


	// TODO: Change arg name to mae_path or mu_path
	input:
		tuple val(dataset_name), path(data_path), path(fold_path)
		each(model_name)
	/* 
		TODO: this part needs to be defined by user,
		mostly required is the template
		======
		You could add the extension of your model or rename those, but it needs to match
		from the one you generate from your script

		Example:
		sample_script.R outputs model.rds, then define path('model.rds') in nextflow
		sample_script.py outputs my_model.pkl, then define path('my_model.pkl') in nextflow
	*/
	output:
		tuple val(dataset_name), val(fold_path.name), val(model_name), path('*model*'),			 	emit: model
		tuple val(dataset_name), val(fold_path.name), val(model_name), path('*test_data*'),	 	emit: test_data
		tuple val(dataset_name), val(fold_path.name), val(model_name), path('*log*'), 				emit: log
	script:
  /* 
			The script here should be found under method/resources/usr/bin/ , 
			and executable  by chmod +x method/resources/usr/bin/run_method.ext
			More infor see cli_scripts
			TODO: rename the extension to the script you write
		*/
		def data_label = "${dataset_name}-${fold_path.name}"
		// TODO: rename the extension to the script you write
		// TODO: rename arg name mae_or_mu_path to mae_path or mu_path accordingly
		"""
		sklearn_train.py \
				--fold_path=${fold_path} \
				--label=${data_label} \
				--model_name=${model_name} > \
				${data_label}-${model_name}-${getPublishPath(task.process).tokenize('/')[-1].toLowerCase()}.log
		echo ${data_label} > ${data_label}
		"""

  // This option is ran when -stub provided upon nextflow run
	stub:
	"""
	echo ${dataset_name}
	echo ${data_path}
	echo 'some text' > text.log
	touch prediction.csv
	touch model
	"""
}