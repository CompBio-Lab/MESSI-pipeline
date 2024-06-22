# This contains bioconductor, MultiAssayExperiment, docopt and here
FROM tonyliang19/r_method_base_dev
# MOFA installation
RUN Rscript -e "BiocManager::install('MOFA2')"
# For prediction wise
RUN Rscript -e 'install.packages("glmnet")'
# However mofa requires python as well ...
RUN pip install mofapy2==0.7.1
# And soft link the python3 as python
RUN ln -s /usr/bin/python3 /usr/bin/python
