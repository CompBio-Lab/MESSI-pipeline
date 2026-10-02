process MERGE_SELECTED_HYPERPARAMETERS {
    label "generic"
    tag "Merge selected hyperparameters"

    publishDir (
      path: "${params.outdir}/${task.process.tokenize(':')[-1].toLowerCase()}",
		  mode: 'copy',
		  overwrite: true
	  )
    
    input:
    path(input_files)

    output:
    path("selected_hyperparameters.json"),     emit: merged_json

    path("selected_hyperparameters.csv"),      emit: merged_csv

    script:
    """
    merge_selected_hyperparameters.py \
        --inputs ${input_files} > \
			${task.process.tokenize(':')[-1].toLowerCase()}.log
    """
}