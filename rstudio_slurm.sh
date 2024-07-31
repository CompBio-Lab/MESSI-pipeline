#!/bin/bash

#==============================================================================
#==============================================================================

#SBATCH --time=03:00:00
#SBATCH --job-name=rstudio
#SBATCH --account=st-singha53-1
#SBATCH --cpus-per-task=8
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=16G
#SBATCH --error=slurm-%j.err
#SBATCH --output=slurm-%j.out
#SBATCH --mail-user=chunqingliang@gmail.com

################################################################################

# Change directory into the job dir
cd $SLURM_SUBMIT_DIR

SCRATCH_PATH=$(eval pwd)

#uncomment the IMAGE without tliang19 in it after you write
# up the place right place to your image
# UNCOMMNET THIS below and edit: 

# Load software environment
module load gcc apptainer

# Set RANDFILE location to writeable dir
export RANDFILE=$TMPDIR/.rnd

# Generate a unique password for RStudio Server
export APPTAINERENV_PASSWORD=$(openssl rand -base64 15)

# Find a unique port for RStudio Server to listen on
readonly PORT=$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')

# Set per-job location for the rserver secure cookie
export SECURE_COOKIE=$TMPDIR/secure-cookie-key

# Print connection details to file
cat > connection_${PBS_JOBID}.txt <<END

1. Create an SSH tunnel to RStudio Server from your local workstation using the following command:

ssh -N -L 8787:${HOSTNAME}:${PORT} ${USER}@sockeye.arc.ubc.ca

2. Point your web browser to http://localhost:8787

3. Login to RStudio Server using the following credentials:

Username: ${USER}
Password: ${APPTAINERENV_PASSWORD}

When done using RStudio Server, terminate the job by:

1. Sign out of RStudio (Left of the "power" button in the top right corner of the RStudio window)
2. Issue the following command on the login node:

scancel ${PBS_JOBID}

END

# Optional: You can modify this container by installing custom R packages/libraries in your local PC with root access. In this case, you have to set LD_LIBRARY_PATH to make Rstudio use the system dependencies built in the container, which are located in "/usr/lib/x86_64-linux-gnu".
#export APPTAINERENV_LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH


#IMAGE="/arc/project/st-singha53-1/tliang19/multi-omics-pipeline/apptainer_images/save_simulate.sif"
#IMAGE=/arc/project/st-singha53-1/tliang19/MESSI-apptainer-images/mae_mudata.sif
#IMAGE=/arc/project/st-singha53-1/tliang19/MESSI-apptainer-images/codia.sif
#IMAGE=/arc/project/st-singha53-1/tliang19/MESSI-apptainer-images/rgcca.sif
#IMAGE=/arc/project/st-singha53-1/tliang19/MESSI-apptainer-images/intersim.sif
IMAGE=/arc/project/st-singha53-1/tliang19/MESSI-apptainer-images/mofa.sif
# Execute the rserver within the rocker/rstudio container
apptainer exec --bind $TMPDIR:/var/run/ \
				--bind $TMPDIR:/var/lib/rstudio-server \
				--home ${SCRATCH_PATH} \
				${IMAGE} rserver \
				--auth-none=0 \
				--auth-pam-helper-path=pam-helper \
				--secure-cookie-key-file ${SECURE_COOKIE} \
				--www-port ${PORT} --server-user ${USER}

