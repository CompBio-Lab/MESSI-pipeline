/* 
  Use this process prepare inputs, or any necessary
  transformation/preprocessing steps to train

  Author: Tony Liang
*/

/*
  MOGONET is quite standard ML like scikit-learn. Its data requires to stay
  in those of X_train, X_test, y_train, y_test. The directory structure is:

  - test_split_1_dir/
    - a_omics_featname.csv
    - a_omics_te.csv
    - a_omics_tr.csv
    - b_omics_featname.csv
    - b_omics_te.csv
    - b_omics_tr.csv
    - ... And so on till finish for all blocks
    - labels_te.csv (the target y of te, or y_test)
    - labels_tr.csv (the target y of tr, or y_train)
  - And repeat for all splits ....
  - test_split_k_dir/

  For more info check following link:
  https://peaceful-faloodeh-879fd6-nbbcwd-sx.netlify.app/train_mogonet#prepare-inputs-and-write-to-disk
*/

// Include the parse method process name output dir
include { getPublishPath } from "${modulesDir}/functions"

process MOGONET_PREPROCESS {
  // Temp variables
  def output_dir = "fold"
  // process configurations
  label 'process_low'
  debug "${params.debug}"
  tag "${dataset_name}"
  // If on sockeye, then use sif file otherwise assuming local (use docker)
  label 'mogonet'
  /* Outputs are stored to outdir (fold), for saving purpose, passing input/output 
  should be done with channels */
  publishDir (
    path: "${params.outdir}/${getPublishPath(task.process)}/${dataset_name}",
    mode: 'copy',
    overwrite: true
	)

  // Declare inputs and output blocks, optional: true flag could be supplied
  input:
    tuple val(dataset_name), path(mu_data), path(splits_dir) 
    // Complete portion of data, multi-omics, id, and the path to each txt file of split
  output:
		tuple val(dataset_name), path("fold*"),  emit:  fold_splits // This is the whole dir described above
    tuple val(dataset_name), path('*.log'),  emit:  log         // standard log file
  // Execution block, stub is evaluted when -stub is provided in cli
  script:
    // Handling a directory of files as batch job
    """
    preprocess_mogonet.py \
      --mdata_path=${mu_data} \
      --splits_dir=${splits_dir} \
      --base_dir=${output_dir} > \
      ${dataset_name}-${getPublishPath(task.process).tokenize('/')[-1].toLowerCase()}.log
    """
  stub:
    // TODO: This is not robust for now, hard coded
    """
    mkdir -p outputs/test_fold_split_1/
    mkdir -p outputs/test_fold_split_2/
    mkdir -p outputs/test_fold_split_3/
		touch test.log
    """
}