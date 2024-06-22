#!/bin/bash

###############################################################################
# This is the setup script to install nextflow binary , retrieve data from
# remote repositorys, and containers
# Author: Tony Liang
###############################################################################

CURR="$(dirname $0)"

execute_src() {
    SCRIPT="$1"
    echo -e "\nExecuting $SCRIPT"
    bash "${SCRIPT}"
    echo -e "\nFinish running $SCRIPT"

}

installation() {
	# 1. Setup conda environment that contains nextflow and corresponding java
	CONDA_SRC="$CURR/01-get_nxf_conda.sh"
	execute_src $CONDA_SRC
	# 2. Pull all required containers
	# To know where would these containers be saved, please look at ./helpers.sh
	CONT_SRC="$CURR/02-pull_all_containers.sh"
	execute_src $CONT_SRC
	#####
	echo -e "\nFinished the setup"
}

source "$CURR/helper.sh"

if [ ! -d "$ENV_DIR" ] || [ ! -d "$IMG_PATH" ]
then
	installation
fi
