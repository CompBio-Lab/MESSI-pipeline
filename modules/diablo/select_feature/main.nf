// Include util functions
include { getPublishPath } from "${modulesDir}/functions"


process DIABLO_SELECT_FEATURE {
  // Vars stuff
	def onSockeye = workflow.projectDir.toString().contains('/scratch')
	tag "${dataset_name}-design_${design}-ncomp_${ncomp}"
	debug true
  label 'process_high'
	container "${ onSockeye  ?
		'codia.sif' :
		'tonyliang19/codia:latest' }"

	publishDir (
		path: "${params.outdir}/${task.process.tokenize(':').join('/').toLowerCase()}/${dataset_name}",
		mode: 'copy',
		overwrite: true
	)

  /* Input and output blocks*/
  input:
    tuple val(dataset_name), path(mae_path)
    val(ncomp)
    each(design)
  output:
    path("*.csv"),    emit: features
    path("*plot*"),   emit: plot
    path("*.log"),    emit: log

  script:
  // The selected features, note have to run preprocess inside this step
  // which is just a convert data format only
  """
  diablo_select_features.R  --dataset_name=${dataset_name} \
                            --mae_path=${mae_path} \
                            --design=${design} \
                            --ncomp=${ncomp} > \
                            diablo-${dataset_name}-${design}.log

  """



}