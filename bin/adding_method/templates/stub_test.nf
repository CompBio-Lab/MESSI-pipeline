// Throwaway harness written by `add_method.py test {{ method }} --stub`.
// Runs only the four processes of this method, with placeholder inputs, on their
// stub: blocks. It leaves out the merge processes: they have no stub: block, and
// Nextflow 24.10.2 fails on a process without one when run with -stub.
include { {{ METHOD }}_PREPROCESS; {{ METHOD }}_TRAIN; {{ METHOD }}_PREDICT; {{ METHOD }}_SELECT_FEATURE } from "${modulesDir}/{{ method }}"

workflow {
  data = file("${projectDir}/nextflow.config")
  splits = file("${projectDir}/main.nf")
  {{ METHOD }}_PREPROCESS ( Channel.of( [ 'stubdata', data, splits ] ) )
  {{ METHOD }}_TRAIN ( {{ METHOD }}_PREPROCESS.out.fold_splits.transpose() )
  {{ METHOD }}_PREDICT (
    {{ METHOD }}_TRAIN.out.model.join( {{ METHOD }}_TRAIN.out.test_data, by: [0, 1] ),
    Channel.value('{{ method }}')
  )
  {{ METHOD }}_SELECT_FEATURE ( Channel.of( [ 'stubdata', data ] ) )
}
