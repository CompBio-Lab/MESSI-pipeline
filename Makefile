# Makefile to run the pipeline

# use this one shell wisely
#.ONESHELL:
SHELL = /bin/bash
.PHONY: run_local run_remote clean help


# Help message variable
define HELP_MESSAGE
This is the default help message to display.

Usage: make [target]

Target:
  - help          Display this help message (default prints it if not target provided)
  - clean         Delete a lots of stuff
  - setup         Setup the environment by pulling nextflow and dowloanding containers (Note could take long time)
  - show          Check job status
  - interactive   Submit interactive node to test scripts
  - submit        Submit full pipeline with the top level main.nf (This is more like you're sure of everything)

endef
export HELP_MESSAGE

# By default should run this help target
help:
	@echo "$${HELP_MESSAGE}"

# Target to setup on a first time environment
# @source bin/helper.sh; \
# if [ ! -d $${ENV_DIR} ] || [ ! -d $${IMG_PATH} ] || [ ! -d $${PIPELINE_DIR} ]; then \
# 	echo "Setting up environment"; \
# 	bash bin/install.sh; \
# 	echo "Done, now submitting the pipeline"; \
# fi

PROJECT_ROOT_DIR=$$(eval pwd)
setup:
	@bash bin/setup_environment.sh ${PROJECT_ROOT_DIR}

# Config checks ##################################
NXF_CONFIG_F=MESSI.config


inspect_local:
	${NXF} config ${NXF_CONFIG_F} -profile local

# This is to use with interactive job 
inspect_arc_local:
	${NXF} -c ${NXF_CONFIG_F} config  -profile arc_local

inspect_arc_pbs:
	${NXF} -c ${NXF_CONFIG_F} config -profile arc_pbs

inspect_arc_slurm:
	${NXF} -c ${NXF_CONFIG_F} config -profile arc_slurm

##################################################
# Deleting eveything except README for now
# If want to delete less stuff, uncomment below and
# move back into clean target
# ! -name past_logs ! -path "results/past_logs/*" \
# 	! -name pbs_output ! -path "results/pbs_output/*" \
# 	! -name reports ! -path "results/reports/*" -delete
clean:
	@rm -f .nextflow.log*
	@rm -rf  .nextflow
	rm -rf tmp
	rm -rf work
	@rm -rf plugins
	@rm -rf .config
	@rm -f .bash_history
	rm -rf secrets
	@rm -f rstudio_server*
	@find results -mindepth 1 ! -name README.md -delete
	@find . -type d -name __pycache__ -exec rm -r {} \+
	@find . -type d -name .ipynb_checkpoints -exec rm -r {} \+
	@rm -rf .ipython
	@rm -rf .jupyter

###########################################################

# Report and Log ###############################################################################################
# This report target could be written better
# Finds latest report in report dir and open it in browser
# Note needs to add extra ; and \ to keep in same shell instance
# LATEST_HTML=$(shell find results/reports/ -mindepth 1 -print0 | xargs -r -0 ls -1 -t | head -1)
#if [ ! -d "results/reports/" ] || [ -z $$LATEST_REPORT ]; then \
	#	echo "echo No HTML files found (Dir not created likely)"; \
	#else \
	#	open $$LATEST_REPORT;\
	#fi 
report:
	$(eval LATEST_REPORT=$(shell find results/reports/ -mindepth 1 -print0 | xargs -r -0 ls -1 -t | head -1))
	open ${LATEST_REPORT}
# Logging related

# Deprecated show or backup latest log (FIX LATER)
#backup_log:
#	$(eval LATEST_LOG=$(shell find results/full_bin_log.txt))
#	DEST_DIR=results/past_logs; \
#	DEST_FILE=$${DEST_DIR}/log_$$(date "+%Y-%m-%d_%H-%M-%S").txt; \
#	cp "${LATEST_LOG}" "$${DEST_FILE}"
#
#show_log:
#	$(eval LATEST_LOG=$(shell find results/full_bin_log.txt))
#	@cat ${LATEST_LOG}
###############################################################################################################
# Deprecated show or backup latest log (FIX LATER)
###############################################################################################################

# Containers related ##########################################################################################
# sets default image to run docker
# You could override it as cli arg in runtime with 
# make docker IMAGE_NAME=<YOUR_IMAGE>
#IMAGE_NAME	?= tonyliang19/cooperative_learning
IMAGE_NAME ?= tonyliang19/mixdiablo
docker:
	docker run --rm -it -p 8787:8787 -e PASSWORD=a -v /$(shell pwd):/home/rstudio ${IMAGE_NAME}:latest

###############################################################################################################

# PBS related ------------------------------------------------------------------------------------------------
#show_pbs:
#	qstat -u ${USER}

# default run pbs script
#PBS_SRC ?= pbs_job_nxf.sh
#interactive_pbs:
#	qsub -I -q interactive_cpu ${PBS_SRC}
# temporary solution for mkdir 
# since comment out pbs_output delete in clean target

upload_data:
	scp -r data/ \
	arc:/arc/project/st-singha53-1/tliang19/multi-omics-pipeline/data

test_r:
	Rscript -e "testthat::test_file('tests/testthat.R')"

#submit_pbs:
# @echo Submitting job now
# @echo Result can be found at ${OUTPUT_NAME}
# @mkdir -p ${OUTPUT_DIR} 
# @qsub -o ${OUTPUT_NAME} ${PBS_SRC}
# @echo Submmited

# SLURM related --------------------------------------------------------------------------------------------
SLURM_SRC ?= slurm_nxf.sh
show:
	squeue -u ${USER}

interactive:
	@echo "Submmitting interactive job"
	@echo "Remeber to 'module purge', then 'module load CVMFS_CC to load CC stuff"
	@echo "Then just simply run 'sh run_remote.sh' after you loaded new modules"
	@echo ""
	@salloc --time=4:0:0 --mem=8G --nodes=1 --ntasks=8 --account=${ALLOC}

OUTPUT_DIR ?= results/slurm_output
OUTPUT_NAME="${OUTPUT_DIR}/MESSI-main_$(shell date +%Y-%m-%d_%H-%M-%S).log"

submit:
	@echo Submitting job now
	@echo Result can be found at ${OUTPUT_NAME}
	@mkdir -p ${OUTPUT_DIR} 
	@sbatch --output=${OUTPUT_NAME} ${SLURM_SRC}
	@echo Submmited

JOB_ID ?= null
summary:
	@if [ "$(JOB_ID)" = null ]; then \
        	echo "JOB_ID is empty. Please set JOB_ID before running make (cancel | summary)"; \
        	exit 0; \
	else \
		seff ${JOB_ID}; \
		fi

cancel:
	@if [ "$(JOB_ID)" = null ]; then \
        	echo "JOB_ID is empty. Please set JOB_ID before running make (cancel | summary)"; \
        	exit 0; \
	else \
		scancel ${JOB_ID}; \
	fi

# Use somehwere ../resources/usr/bin to make 
DIR_TO_EXT=modules/simulate_data/resources/usr/bin
execute:
	find ${DIR_TO_EXT} -type f -iname "*.sh" -exec chmod +x {} \;