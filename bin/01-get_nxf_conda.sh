#!/bin/bash

######################################################################
# This script is to get nextflow binary installed to your environment
# using conda, it contains all nxf dependencies like openjdk.
######################################################################

# source helper script
# Get the directory of the currently executing script
# Source the script.sh file using the absolute path

# Load conda setup
source ~/.bashrc
# Load helper script that contains env variables
HELPER=helper.sh
source "$(dirname $0)/$HELPER"
# custom command/function for installing nextflow in a conda environment
install_nxf() {
    #module load miniconda3
    if [ -d $1 ]
    then
        echo -e "\nFound nextflow's conda environment at $1"
    else
        echo -e "\nNextflow will be install with conda at $1"
        conda create --prefix "$1" --yes --quiet
        echo -e "\nInstalling now ...\n"
        conda install --prefix "$1" -c conda-forge openjdk=11.08
        conda install --prefix "$1" -c bioconda -y nextflow=23.04.1
        echo -e "\nDone installing"
    fi
}
# prints info of the script
print_document
# install nextflow to the dir desired
install_nxf ${ENV_DIR}
# test sucessful installtaion
conda activate ${ENV_DIR}
nextflow -version
conda deactivate
# exit program
echo "Done"