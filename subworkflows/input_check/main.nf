//
// Check input samplesheet and get data channels
//

include { SAMPLESHEET_CHECK } from "${modulesDir}/local/samplesheet_check"

workflow INPUT_CHECK {
  take:
    samplesheet

  main:
    SAMPLESHEET_CHECK ( samplesheet )
        .csv
        .splitCsv ( header:true, sep:',' )
        .map { create_data_channel(it) }
        .set { ch_datasets }

  emit:
    reads                                     // channel: [ val(meta), [ reads ] ]
    //versions = SAMPLESHEET_CHECK.out.versions // channel: [ versions.yml ]
}

// Function to get list of [ dataset_name, mae_path, mu_path ]
// TODO: not finished
def create_fastq_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.datset_name         = row.sample
    meta.single_end = row.single_end.toBoolean()

    // add path(s) of the fastq file(s) to the meta map
    def fastq_meta = []
    if (!file(row.fastq_1).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> Read 1 FastQ file does not exist!\n${row.fastq_1}"
    }
    if (meta.single_end) {
        fastq_meta = [ meta, [ file(row.fastq_1) ] ]
    } else {
        if (!file(row.fastq_2).exists()) {
            exit 1, "ERROR: Please check input samplesheet -> Read 2 FastQ file does not exist!\n${row.fastq_2}"
        }
        fastq_meta = [ meta, [ file(row.fastq_1), file(row.fastq_2) ] ]
    }
    return fastq_meta
}