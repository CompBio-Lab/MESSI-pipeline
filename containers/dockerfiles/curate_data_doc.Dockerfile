FROM rocker/verse:4.3.3
# This has tex and rmarkdown installed, so we need the R and Python deps only

# First for python & linux dev
RUN apt-get update \
    && apt-get install -y \
    libxt6 \
    python3.10 \
    python3-setuptools \
    python3-dev \
    python3-pip && \
  apt-get clean all && \
  apt-get purge && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
# Link python3 as python
RUN ln -s /usr/bin/python3 /usr/bin/python
# Then install python pkgs
RUN pip install \
    anndata==0.10.3 \
    docopt==0.6.2 \
    h5py==3.10.0 \
    matplotlib==3.8.1 \
    mudata==0.2.3 \
    numpy==1.26.1 \
    packaging==23.2 \
    pandas==2.1.1 \
    scikit-learn==1.3.2 \
    scipy==1.11.3 

# Now for R pkgs
RUN Rscript -e "install.packages('BiocManager')" \
	-e "install.packages('here')" \
	-e "install.packages('reticulate')" \
	-e "install.packages('bookdown')"

# And those of bioc conductor
RUN Rscript -e "BiocManager::install(c('mixOmics', 'MultiAssayExperiment', 'HDF5Array'))"
