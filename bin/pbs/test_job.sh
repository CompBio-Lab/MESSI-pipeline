#!/bin/bash

################################################################
# Test script

# echo -e "\nThe loaded ENV variables from helper.sh are:"
# echo Scratch path is $SCRATCH_PATH
# echo Proj path is $PROJECT_PATH
# # Virtual env related
# echo Env dir is $ENV_DIR
# echo Img path is $IMG_PATH
# # Project related
# echo Pipeline dir is $PIPELINE_DIR
# echo Script dir is $SCRIPT_DIR
# echo Container names located at $CONTAINER_NAMES

# Set home, work, cache dir manually
# and other runtime variables for NXF
# echo -e "\nThe modules loaded are:"
# module list
# echo Done

# # Before loading
# echo -e "\nBefore loading, some vars are:"
# echo Scratch path is $SCRATCH_PATH
# echo Proj path is $PROJECT_PATH
#echo "Java's location: $(which java)"
#echo "Java's version: $(java --version)"
#export JAVA_HOME=$(which java)
#echo -e "\nNextflow's location: $(which nextflow)"
#echo -e "\nNextflow's verion: $(nextflow -version)"

# Load conda setup
source ~/.bashrc

# # Change to working dir (job dir)
# cd $PBS_O_WORKDIR
# # Loading modules at specfic version
# module load gcc/9.4.0
# module load apptainer/1.1.9
# module load openjdk/11.0.8_10

# # Load helper script that loads various ENV variables for later usage
echo $PIPELINE_DIR
CURR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source "$CURR_DIR/../bin/helper.sh"
# source $HELPER

echo $PIPELINE_DIR

# export NXF_WORK="$PIPELINE_DIR/work"
# export NXF_HOME=$PIPELINE_DIR
# export NXF_OFFLINE='TRUE'

# # Use the pipeline
# conda activate ${ENV_DIR}
# nextflow -version
# echo Done
# conda deactivate