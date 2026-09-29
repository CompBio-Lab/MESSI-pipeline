process SAMPLESHEET_CHECK {
  tag "$samplesheet"
  label 'process_single_low'

  label 'mogonet'

  input:
  path(samplesheet)

  output:
  path('*.csv')       , emit: csv
  //path("versions.yml") , emit: versions


  script: // This script is bundled with in the process/resources/usr/bin
  """
  check_samplesheet.py \\
      ${samplesheet} \\
      samplesheet.valid.csv
  """
  /*
  // TODO: add this in later
  cat <<-END_VERSIONS > versions.yml
  "${task.process}":
      python: \$(python --version | sed 's/Python //g')
  END_VERSIONS
  """
  */
}