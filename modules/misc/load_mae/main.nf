process loadMAE {
    container "tonyliang19/rpystudio:v0.1"
    tag "${data_dir.getSimpleName()}"
    input:
        path(data_dir)
        tuple val(dataset_name), val(prefix)
    output:
        tuple val(dataset_name), val(prefix)
    script:
        """
        Rscript ${rDir}/loadMAE.R
        """
}
