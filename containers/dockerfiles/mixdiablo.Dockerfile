# Environment requirement for mixDIABLO omics

FROM bioconductor/bioconductor_docker:latest

RUN Rscript -e "install.packages('here')"
RUN Rscript -e "BiocManager::install(c('mixOmics', 'MultiAssayExperiment', 'HDF5Array'))"