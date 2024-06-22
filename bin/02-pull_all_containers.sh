#!/bin/bash

###############################################################
# This scripts pulls all the required containers from dockerhub
# to a specifed directory set at bin/helper.sh, default is
# /arc/project/$USER/images. And, the pulled image would be 
# of .sif format.
###############################################################


# source helper script
# Get the directory of the currently executing script
# Source the script.sh file using the absolute path
HELPER=helper.sh
source "$(dirname $0)/$HELPER"

# prints the documentation out
print_document

# load modules
module load gcc/9.4.0
module load apptainer/1.1.9

# custom command/function for pulling each container to specified path
install_containers() {
   # check if dir exist and create it
   check_dir $1
   # read container names in path provided into array
   # each container is delimited by new line
   DELIMITER=$'\n'
   read -d '' -r -a names < ${CONTAINER_NAMES}
   for c in "${names[@]}"
   do
      # check if container exists, if not then downlaod all from names in file
      check_container "$c" "$1"
   done

   echo -e "\nDone, go to $PIPELINE_DIR/README.md for running instructions"
}

install_containers ${IMG_PATH}