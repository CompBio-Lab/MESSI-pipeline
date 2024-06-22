#==============================================================================
# This is should be place to store doc for the image
# Template for creating R based Docker containers
# Bioconductor like based on Rstudio
# Run with -p 8787
#==============================================================================

# Run this command
# docker run -it --rm -p 8787:8787 -e PASSWORD=a -v /$(pwd):/home/rstudio <IMAGE>
#LABEL maintainer="Tony Liang <chunqingliang@gmail.com>"


# Base image to run from, always takes latest bioconductor
FROM bioconductor/bioconductor_docker:latest

# CRAN pkgs
RUN Rscript -e "install.packages('here')" \
	-e "install.packages('docopt')"
# Bioconductor pkgs
# TODO: you should add more pkgs if needed for the method used
RUN Rscript -e "BiocManager::install(c('MultiAssayExperiment', 'HDF5Array'))"
