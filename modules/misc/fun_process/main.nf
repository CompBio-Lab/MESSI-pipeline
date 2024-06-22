/*
  ====================================================================
  Process to test features, options, configurations for nextflow stuff
  It would be constantly changing!
  Author: Tony Liang
  ====================================================================
*/

// ===================================================================

/*
  The process name should be ALL_UPPER, but its filename should be 
  all_lower. Make use of underscores
*/
process FUN_PROCESS {
  /* 
    You could a lot of inside container configs
    or put in config files, although the order is the following
    process level > config level
  */
  // Some other variables to use
  def isRemote = workflow.containerEngine == 'apptainer' && !workflow.profile == 'standard'

  // Process options
  container "${isRemote} ? 'save_simulate.sif' : 'tonyliang19/save_simulate:latest'"
  //def profile = workflow.profile
  /* This give "unique identifier" to the log 
   to denote which one is currently running
  */
  //tag "${id}" // if using ${}, then needs "" to wrap it
  //label "test_label" // This tells to find configs withLabel "test_label"

  //container "${}"
  debug true

  script:
  // variables to use
  """
  echo "I should be printing and you should see it"
  """
}