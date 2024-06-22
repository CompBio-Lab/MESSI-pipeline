# --------------------------------------------------------------------------------
# Use this image to attain MAE or MuData behaviors

# By default this contains Rstudio interface!
FROM bioconductor/bioconductor_docker
WORKDIR /home/rstudio
#COPY install_R_pkgs.R install_R_pkgs.R
# Essential packages
# Requires to have couple packages

RUN apt-get update \
    && apt-get install -y \
    libxt6 \
    python3.10 \
    python3-setuptools \
    python3-dev \
    python3-pip
# ---------------------------------
# Given still in development stage, for faster speed
# split installs in couple of layers
RUN Rscript -e "install.packages('tidyverse')" \
  -e "install.packages('here')" \
  -e "install.packages('reticulate')"

RUN Rscript -e "BiocManager::install(c('mixOmics', 'MultiAssayExperiment', 'HDF5Array'))"

# Python packages
#COPY requirements.txt requirements.txt
RUN pip3 install \
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
# Link python3 to python as well
RUN ln -s /usr/bin/python3 /usr/bin/python
#COPY simulate_data/ simulation_data/


# Uncommnet this line and rebuild if you only want a rstudio server
CMD ["/bin/bash"]
