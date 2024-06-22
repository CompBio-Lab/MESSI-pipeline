process UNCOMPRESS_RECORD {
  def onSockeye = workflow.projectDir.toString().contains('/scratch')
	/* process metadata and configs */
	tag "${row_map.dataset_name}"
  label 'process_low'
	// TODO: move this containter to somewhere else?
  container "${ onSockeye ? 
		'save_simulate.sif' : 
		'tonyliang19/save_simulate:latest' }"  
	publishDir (
		path: "${params.outdir}/${task.process.tokenize(':').join('/').toLowerCase()}/${row_map.dataset_name}",
		saveAS: { file },
		mode: 'copy',
		overwrite: true
	)
  
  input:
    val(row_map)

  // This is a map, such that you could access it by row_map.key1, row_map.key2
  // where key1, key2 are columns of the original csv

  output:
    tuple val(row_map.dataset_name), path("*${row_map.dataset_name}/*mae*"), path("*${row_map.dataset_name}/*.h5mu"), emit: record

  script:
  // TODO: needs a script placed under process_name/resources/usr/bin
  """
  uncompress_record.R --dataset_name=${row_map.dataset_name} \
    --tar_path=${row_map.tar_path} > \
    ${row_map.dataset_name}.log
  """
}