// Nextflow process
// Author: Tony Liang


// Handles the RGCCA listed the Reference section of top-level README
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

process RGCCA_TRAIN {
	// Vars stuff
	def onSockeye = workflow.projectDir.toString().contains('/scratch')
	// Identifier for each dataset and fold combination
	tag "${dataset_name}-${fold_path.name}-${method}-design_${design}-ncomp_${ncomp}"
	label 'process_single'
	// TODO: rename to the actual image name used
	container "${ onSockeye  ?
		'rgcca.sif' :
		'tonyliang19/rgcca:latest' }"
	// Parse the output directory to migrate results to
	publishDir (
		path: "${params.outdir}/${getPublishPath(task.process)}/${dataset_name}/${fold_path.name}",
		mode: 'copy', 
		overwrite: true
	)
	// TODO: add your custom labels to tell if process
	// consumes large RAM/ROM and gpu access or not
	/*
  label 'low_or_high_mem'
	label 'cpu_or_gpu'
  */

	input:
		tuple val(dataset_name), path(mae_path), path(fold_path)
		val(ncomp)
		each(method)
		each(design)
	output:
		tuple val(dataset_name), val(fold_path.name), val("${method}-${design}"), path('*model*'),				emit: model
		tuple val(dataset_name), val(fold_path.name), val("${method}-${design}"), path('*test_data*'),		emit: test_data
		tuple val(dataset_name), val(fold_path.name), val("${method}-${design}"), path('*log*'),					emit: log
	script:
  	/* 
			The script here should be found under method/resources/usr/bin/ , 
			and executable  by chmod +x method/resources/usr/bin/run_method.ext
			More infor see cli_scripts
			TODO: rename the extension to the script you write
		*/
		def data_label = "${dataset_name}-${fold_path.name}"
		// TODO: rename the extension to the script you write
		// TODO: rename arg name mae_path to mae_path or mu_path accordingly
		"""
		run_rgcca.R \
				--mae_path=${mae_path} \
				--label=${data_label} \
				--fold_path=${fold_path} \
				--method=${method} \
        --design=${design} \
				--ncomp=${ncomp} > \
				${data_label}-${getPublishPath(task.process).tokenize('/')[-1].toLowerCase()}.log
		echo ${data_label} > ${data_label}
		"""

  // This option is ran when -stub provided upon nextflow run
	stub:
	"""
	echo ${dataset_name}
	echo ${mae_path}
	echo 'some text' > text.log
	touch prediction.csv
	touch model
	"""
}
