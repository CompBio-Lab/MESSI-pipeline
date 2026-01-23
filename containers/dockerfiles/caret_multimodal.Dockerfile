FROM bioconductor/bioconductor_docker:RELEASE_3_21-r-4.5.2@sha256:359702d482e70e343d2a436731b7c6deffd1ec184a1f1700de5d64b0c97cacba

# Install R packages from Bioconductor
RUN Rscript -e "\
  bioc_pkgs <- c('MultiAssayExperiment', 'HDF5Array'); \
  BiocManager::install(bioc_pkgs) \
  "

# Install R packages from CRAN
RUN Rscript -e "\
  pkgs <- c('here', 'docopt', 'glmnet'); \
  install.packages(pkgs) \
  "

# And install main caretMultimodal package from GitHub
RUN Rscript -e "devtools::install_github('JoshD898/caretMultimodal')"

