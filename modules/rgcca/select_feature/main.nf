// Include util functions
include { getPublishPath } from "${modulesDir}/functions"


process RGCCA_SELECT_FEATURE {
  // Vars stuff
	tag "${dataset_name}-design_${design}-ncomp_${ncomp}"
	debug true
  label 'process_low'
  label 'rgcca'

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
  rgcca_select_features.R  --dataset_name=${dataset_name} \
                            --mae_path=${mae_path} \
                            --design=${design} \
                            --ncomp=${ncomp} > \
                            rgcca-select_features_${dataset_name}-${design}.log

  """



}
