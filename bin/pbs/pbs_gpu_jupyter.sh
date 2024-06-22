#!/bin/bash

# This is are the allocation specifications for the PBS job


#PBS -l walltime=03:00:00,select=1:ncpus=8:ompthreads=8:ngpus=1:mem=16gb
#PBS -N python_gpu
#PBS -A st-singha53-1-gpu
#PBS -m e
#PBS -M tliang19@student.ubc.ca

##############################

# Change to working dir (job dir)

cd $PBS_O_WORKDIR

# Load software environment
module load gcc
module load apptainer
module load cuda
module load cudnn

# Set RANDFILE location to writeable dir
export RANDFILE=$TMPDIR/.rnd

# Generate unique token (password) for Jupyter Notebooks
export APPTAINERENV_JUPYTER_TOKEN=$(openssl rand -base64 15)

# Find a unique port for Jupyter Notebooks to listen on
readonly PORT=$(python -c 'import socket; s=socket.socket(); s.bind(("",0)); print(s.getsockname()[1]); s.close()')


# Print connection details to file
cat > conn_${PBS_JOBID}.txt << END

1. Create an SSH tunnel to Jupyter Notebooks from your local workstation using the following command:

# change back 88xx to 8888
# This is the gpu one
ssh -N -L 8891:${HOSTNAME}:${PORT} ${USER}@sockeye.arc.ubc.ca 

2. Point your web browser to http://localhost:8891
 
3. Login to Jupyter Notebooks using the following token (password):
 
${APPTAINERENV_JUPYTER_TOKEN}
 
When done using Jupyter Notebooks, terminate the job by:
 
1. Quit or Logout of Jupyter Notebooks
2. Issue the following command on the login node (if you did Logout instead of Quit):
 
qdel ${PBS_JOBID}
 
END

echo "PLEASE WAIT FOR A MIN FOR JUPYTER TO LOAD, 'Connection failed is normal'"

echo "This is your token: ${APPTAINERENV_JUPYTER_TOKEN}"
# Override scratch
#SCRATCH_PATH=/scratch/st-singha53-1/tliang19/multi-omics-pipeline
SCRATCH_PATH=$(eval pwd)
DATA_PATH="${PROJECT_PATH}/multi-omics-pipeline/data"
# Execute jupyter within the jupyter/datascience-notebook container
IMAGE=$PROJECT_PATH/multi-omics-pipeline/apptainer_images/mogonet.sif
# export SF_SLIDE_BACKEND=libvips
#export SF_BACKEND=tensorflow

# -f after exec and --allow-root after jupyter lab
apptainer exec  --nv \
  -B $PROJECT_PATH \
  --bind $DATA_PATH:/arc_data \
  --home $SCRATCH_PATH \
  $IMAGE \
  jupyter lab --no-browser --port=${PORT} --ip=0.0.0.0 --notebook-dir=$PBS_O_WORKDIR