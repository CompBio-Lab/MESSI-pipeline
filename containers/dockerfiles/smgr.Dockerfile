# Environment for SMGR
# See here for its github repo: https://github.com/QSong-github/SMGR
# BiocManager 3.12 i required


FROM bioconductor/bioconductor_docker:RELEASE_3_12
# Install dependencies of SMGR
#RUN Rscript -e "pkg <- c('glmnet','MASS','purrr','mpath','zic','pscl','parallel') ; BiocManager::install(pkg, dependencies = TRUE)"
RUN Rscript -e "\
  pkg <- c('glmnet', 'MASS', 'purrr', 'mpath', 'zic', 'pscl', 'parallel'); \
  BiocManager::install(pkg, dependencies = TRUE)"

# Install SMGR
RUN Rscript -e "devtools::install_github('QSong-github/SMGR')"

# Install other dependencies
RUN Rscript -e "install.packages('clValid')"
