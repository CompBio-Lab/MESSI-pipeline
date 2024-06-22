#!/bin/bash

#SBATCH --job-name=gpu-jup-ntb
#SBATCH --account=st-singha53-1-gpu
#SBATCH --time=03:00:00
#SBATCH --cpus-per-task=8
#SBATCH --gpus-per-node=1
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=16G
#SBATCH --output=jup-%x-%j.log
#SBATCH --mail-user=chunqingliang@gmail.com
 
################################################################################
 
# Change directory into the job dir
cd $SLURM_SUBMIT_DIR
# Export num threads to be same as cpus_per_task
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

# Load software environment
module load gcc
module load apptainer
module load cuda


# Set RANDFILE location to writeable dir
export RANDFILE=$TMPDIR/.rnd

# Generate a unique token (password) for Jupyter Notebooks
export APPTAINERENV_JUPYTER_TOKEN=$(openssl rand -base64 15)
 
# Find a unique port for Jupyter Notebooks to listen on
readonly PORT=$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')
 
# Print connection details to file
cat > connection_${SLURM_JOB_ID}.txt <<END
 
1. Create an SSH tunnel to Jupyter Notebooks from your local workstation using the following command:
 
ssh -N -L 8890:${HOSTNAME}:${PORT} ${USER}@sockeye.arc.ubc.ca
 
2. Point your web browser to http://localhost:8890
 
3. Login to Jupyter Notebooks using the following token:
 
Password: ${APPTAINERENV_JUPYTER_TOKEN}
 
When done using Jupyter Notebooks, terminate the job by:
 
1. Quit or Logout of Jupyter Notebooks
2. Issue the following command on the login node (if you did Logout instead of Quit):
 
scancel ${SLURM_JOB_ID}
 
END
 
# Paramters goes here
IMAGE="${PROJECT_PATH}/multi-omics-pipeline/apptainer_images/mogonet.sif" # change this one if want to use another image
export SCRATCH=/scratch/st-singha53-1/tliang19/MESSI-doc
# Execute jupyter within the Apptainer container
apptainer exec --nv --home ${SCRATCH} \
              --env XDG_CACHE_HOME=${SCRATCH} \
              ${IMAGE} \
              jupyter lab --no-browser --port=${PORT} --ip=0.0.0.0 --notebook-dir=$SLURM_SUBMIT_DIR

  